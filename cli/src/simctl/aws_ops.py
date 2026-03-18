from __future__ import annotations

import json
import time
from dataclasses import dataclass

import boto3
from botocore.exceptions import ClientError

from .config import SimConfig


@dataclass
class InstanceInfo:
    instance_id: str
    state: str
    mode: str
    az: str
    public_ip: str
    public_dns: str


class AwsOps:
    def __init__(self, cfg: SimConfig) -> None:
        self.cfg = cfg
        self.session = boto3.Session(region_name=cfg.region)
        self.ec2 = self.session.client("ec2")
        self.ssm = self.session.client("ssm")

    def get_param(self, suffix: str) -> str:
        name = f"{self.cfg.prefix}/{suffix.lstrip('/')}"
        return self.ssm.get_parameter(Name=name)["Parameter"]["Value"]

    def put_param(self, suffix: str, value: str) -> None:
        name = f"{self.cfg.prefix}/{suffix.lstrip('/')}"
        self.ssm.put_parameter(Name=name, Value=value, Type="String", Overwrite=True)

    def maybe_get_param(self, suffix: str) -> str:
        try:
            return self.get_param(suffix)
        except ClientError as exc:
            if exc.response["Error"]["Code"] == "ParameterNotFound":
                return ""
            raise

    @staticmethod
    def _is_noneish(value: str) -> bool:
        return value.strip().lower() in {"", "none", "null", "-"}

    def launch_mode(self, mode: str) -> str:
        lt_name = self.cfg.launch_templates[mode]
        allowed_types = self.cfg.allowed_instance_types[mode]
        overrides = [{"InstanceType": it} for it in allowed_types]

        resp = self.ec2.create_fleet(
            Type="instant",
            TargetCapacitySpecification={"TotalTargetCapacity": 1, "DefaultTargetCapacityType": "spot"},
            SpotOptions={"AllocationStrategy": "price-capacity-optimized"},
            LaunchTemplateConfigs=[
                {
                    "LaunchTemplateSpecification": {"LaunchTemplateName": lt_name, "Version": "$Latest"},
                    "Overrides": overrides,
                }
            ],
            TagSpecifications=[
                {
                    "ResourceType": "instance",
                    "Tags": [
                        {"Key": "Project", "Value": self.cfg.project_name},
                        {"Key": "Mode", "Value": mode},
                        {"Key": "ManagedBy", "Value": "simctl"},
                    ],
                }
            ],
        )

        instances = resp.get("Instances", [])
        if not instances:
            errors = resp.get("Errors", [])
            raise RuntimeError(f"No instance launched. Fleet errors: {json.dumps(errors)}")

        return instances[0]["InstanceIds"][0]

    def wait_instance_running(self, instance_id: str) -> None:
        self.ec2.get_waiter("instance_running").wait(InstanceIds=[instance_id])

    def describe_instance(self, instance_id: str, mode: str | None = None) -> InstanceInfo:
        resp = self.ec2.describe_instances(InstanceIds=[instance_id])
        item = resp["Reservations"][0]["Instances"][0]
        return InstanceInfo(
            instance_id=instance_id,
            state=item["State"]["Name"],
            mode=mode or self._extract_mode(item),
            az=item["Placement"]["AvailabilityZone"],
            public_ip=item.get("PublicIpAddress", ""),
            public_dns=item.get("PublicDnsName", ""),
        )

    def _extract_mode(self, item: dict) -> str:
        for tag in item.get("Tags", []):
            if tag["Key"] == "Mode":
                return tag["Value"]
        return "unknown"

    def record_current_instance(self, instance_id: str, mode: str) -> None:
        self.put_param("current/instance-id", instance_id)
        self.put_param("current/mode", mode)

    def get_current_instance(self) -> tuple[str, str]:
        try:
            iid = self.get_param("current/instance-id").strip()
            mode = self.get_param("current/mode").strip()
            if self._is_noneish(iid):
                return "", ""
            if self._is_noneish(mode):
                mode = "unknown"
            return iid, mode
        except ClientError:
            return "", ""

    def maybe_associate_eip(self, instance_id: str) -> str:
        allocation_id = self.maybe_get_param("config/elastic-ip-allocation-id").strip()
        if self._is_noneish(allocation_id):
            return ""
        self.ec2.associate_address(InstanceId=instance_id, AllocationId=allocation_id, AllowReassociation=True)
        return allocation_id

    def create_and_attach_isaac_volume(self, instance_id: str, az: str) -> str:
        snapshot_id = self.get_param("isaac-snapshot-id").strip()
        if not snapshot_id or snapshot_id.startswith("snap-REPLACE"):
            raise RuntimeError("SSM parameter for Isaac snapshot is not initialized")

        resp = self.ec2.create_volume(
            SnapshotId=snapshot_id,
            AvailabilityZone=az,
            VolumeType="gp3",
            Encrypted=True,
            TagSpecifications=[
                {
                    "ResourceType": "volume",
                    "Tags": [
                        {"Key": "Project", "Value": self.cfg.project_name},
                        {"Key": "Role", "Value": "isaac-runtime"},
                        {"Key": "ManagedBy", "Value": "simctl"},
                    ],
                }
            ],
        )
        volume_id = resp["VolumeId"]

        self.ec2.get_waiter("volume_available").wait(VolumeIds=[volume_id])
        self.ec2.attach_volume(InstanceId=instance_id, VolumeId=volume_id, Device="/dev/sdf")
        self.put_param("current/isaac-volume-id", volume_id)
        return volume_id

    def wait_ssm_online(self, instance_id: str, timeout_s: int = 300) -> None:
        start = time.time()
        while time.time() - start < timeout_s:
            resp = self.ssm.describe_instance_information(Filters=[{"Key": "InstanceIds", "Values": [instance_id]}])
            info = resp.get("InstanceInformationList", [])
            if info and info[0].get("PingStatus") == "Online":
                return
            time.sleep(5)
        raise TimeoutError("Instance did not become SSM online in time")

    def run_remote_script(self, instance_id: str, script: str, timeout_s: int = 600) -> str:
        cmd = self.ssm.send_command(
            InstanceIds=[instance_id],
            DocumentName="AWS-RunShellScript",
            TimeoutSeconds=timeout_s,
            Parameters={"commands": [script]},
        )
        command_id = cmd["Command"]["CommandId"]

        while True:
            inv = self.ssm.get_command_invocation(CommandId=command_id, InstanceId=instance_id)
            status = inv["Status"]
            if status in {"Pending", "InProgress", "Delayed"}:
                time.sleep(3)
                continue
            if status != "Success":
                raise RuntimeError(f"SSM command failed ({status}): {inv.get('StandardErrorContent', '')}")
            return inv.get("StandardOutputContent", "")

    def terminate_current(self, sync_first: bool = True, keep_isaac_volume: bool = False) -> None:
        instance_id, mode = self.get_current_instance()
        if not instance_id:
            raise RuntimeError("No active instance recorded in SSM")

        if sync_first:
            bucket = self.get_param("bucket-name")
            project_prefix = self.get_param("config/project-prefix")
            workspace_path = self.get_param("config/workspace-path")
            self.wait_ssm_online(instance_id, timeout_s=180)
            self.run_remote_script(instance_id, f"/opt/robotics/bin/s3-sync-project-up.sh {bucket} {project_prefix} {workspace_path}", timeout_s=1200)

        self.ec2.terminate_instances(InstanceIds=[instance_id])

        if mode == "isaac" and not keep_isaac_volume:
            volume_id = self.get_param("current/isaac-volume-id").strip()
            if not self._is_noneish(volume_id):
                self._detach_and_delete_volume(volume_id)

        self.put_param("current/instance-id", "none")
        self.put_param("current/mode", "none")
        self.put_param("current/isaac-volume-id", "none")

    def _detach_and_delete_volume(self, volume_id: str) -> None:
        try:
            volume = self.ec2.describe_volumes(VolumeIds=[volume_id])["Volumes"][0]
            for att in volume.get("Attachments", []):
                self.ec2.detach_volume(VolumeId=volume_id, InstanceId=att["InstanceId"], Force=True)
            self.ec2.get_waiter("volume_available").wait(VolumeIds=[volume_id])
            self.ec2.delete_volume(VolumeId=volume_id)
        except ClientError as exc:
            if exc.response["Error"]["Code"] in {"InvalidVolume.NotFound", "IncorrectState"}:
                return
            raise

    def sync_down(self) -> None:
        instance_id, _ = self.get_current_instance()
        if not instance_id:
            raise RuntimeError("No active instance")
        bucket = self.get_param("bucket-name")
        project_prefix = self.get_param("config/project-prefix")
        workspace_path = self.get_param("config/workspace-path")
        self.wait_ssm_online(instance_id)
        self.run_remote_script(instance_id, f"/opt/robotics/bin/s3-sync-project-down.sh {bucket} {project_prefix} {workspace_path}", timeout_s=1200)

    def sync_up(self) -> None:
        instance_id, _ = self.get_current_instance()
        if not instance_id:
            raise RuntimeError("No active instance")
        bucket = self.get_param("bucket-name")
        project_prefix = self.get_param("config/project-prefix")
        workspace_path = self.get_param("config/workspace-path")
        self.wait_ssm_online(instance_id)
        self.run_remote_script(instance_id, f"/opt/robotics/bin/s3-sync-project-up.sh {bucket} {project_prefix} {workspace_path}", timeout_s=1200)

    def create_isaac_snapshot(self) -> str:
        volume_id = self.get_param("current/isaac-volume-id").strip()
        if self._is_noneish(volume_id):
            raise RuntimeError("No current Isaac volume tracked in SSM")

        snap = self.ec2.create_snapshot(
            VolumeId=volume_id,
            Description="Isaac runtime snapshot created by simctl",
            TagSpecifications=[
                {
                    "ResourceType": "snapshot",
                    "Tags": [
                        {"Key": "Project", "Value": self.cfg.project_name},
                        {"Key": "Role", "Value": "isaac-runtime"},
                        {"Key": "ManagedBy", "Value": "simctl"},
                    ],
                }
            ],
        )
        snapshot_id = snap["SnapshotId"]
        self.ec2.get_waiter("snapshot_completed").wait(SnapshotIds=[snapshot_id])
        self.put_param("isaac-snapshot-id", snapshot_id)
        return snapshot_id
