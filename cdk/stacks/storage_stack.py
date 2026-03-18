from aws_cdk import (
    RemovalPolicy,
    Stack,
    aws_s3 as s3,
    aws_ssm as ssm,
)
from constructs import Construct

from .config import InfraConfig


class StorageStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, *, config: InfraConfig, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        bucket_name = config.bucket_name if config.bucket_name else None
        self.bucket = s3.Bucket(
            self,
            "ProjectBucket",
            bucket_name=bucket_name,
            versioned=True,
            block_public_access=s3.BlockPublicAccess.BLOCK_ALL,
            encryption=s3.BucketEncryption.S3_MANAGED,
            enforce_ssl=True,
            removal_policy=RemovalPolicy.RETAIN,
            auto_delete_objects=False,
        )

        prefix = config.parameter_prefix.rstrip("/")
        ssm.StringParameter(self, "BucketNameParam", parameter_name=f"{prefix}/bucket-name", string_value=self.bucket.bucket_name, description="Bucket storing project data and simulation assets")
        ssm.StringParameter(self, "BaseAmiParam", parameter_name=f"{prefix}/base-ami-id", string_value="ami-REPLACE-ME", description="Current base AMI ID used by simulation launch templates")
        ssm.StringParameter(self, "IsaacSnapshotParam", parameter_name=f"{prefix}/isaac-snapshot-id", string_value="snap-REPLACE-ME", description="Current Isaac EBS snapshot ID")
        ssm.StringParameter(self, "DefaultProjectPrefixParam", parameter_name=f"{prefix}/config/project-prefix", string_value="project/", description="Default S3 prefix for project data")
        ssm.StringParameter(self, "DefaultWorkspacePathParam", parameter_name=f"{prefix}/config/workspace-path", string_value="/workspace/project", description="Default local workspace path")
        ssm.StringParameter(self, "GazeboInstanceTypesParam", parameter_name=f"{prefix}/config/gazebo-instance-types", string_value=config.gazebo_instance_types, description="Allowed Gazebo Spot instance types")
        ssm.StringParameter(self, "IsaacInstanceTypesParam", parameter_name=f"{prefix}/config/isaac-instance-types", string_value=config.isaac_instance_types, description="Allowed Isaac Spot instance types")
        ssm.StringParameter(self, "IsaacWebrtcTcpPortsParam", parameter_name=f"{prefix}/config/isaac-webrtc-tcp-ports", string_value=config.isaac_webrtc_tcp_ports, description="Allowed inbound Isaac WebRTC TCP ports")
        ssm.StringParameter(self, "IsaacWebrtcUdpPortsParam", parameter_name=f"{prefix}/config/isaac-webrtc-udp-ports", string_value=config.isaac_webrtc_udp_ports, description="Allowed inbound Isaac WebRTC UDP ports")
        ssm.StringParameter(self, "CurrentInstanceIdParam", parameter_name=f"{prefix}/current/instance-id", string_value="none", description="Current active simulation instance id")
        ssm.StringParameter(self, "CurrentModeParam", parameter_name=f"{prefix}/current/mode", string_value="none", description="Current active simulation mode")
        ssm.StringParameter(self, "CurrentIsaacVolumeIdParam", parameter_name=f"{prefix}/current/isaac-volume-id", string_value="none", description="Current Isaac runtime volume id")
