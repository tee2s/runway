from pathlib import Path

from aws_cdk import Stack, aws_ec2 as ec2, aws_iam as iam, aws_ssm as ssm
from constructs import Construct

from .config import InfraConfig


class ComputeStack(Stack):
    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        *,
        config: InfraConfig,
        vpc: ec2.IVpc,
        gazebo_sg: ec2.ISecurityGroup,
        isaac_sg: ec2.ISecurityGroup,
        bucket,
        **kwargs,
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)

        prefix = config.parameter_prefix.rstrip("/")

        role = iam.Role(
            self,
            "SimInstanceRole",
            role_name=f"{config.project_name}-sim-instance-role",
            assumed_by=iam.ServicePrincipal("ec2.amazonaws.com"),
            managed_policies=[iam.ManagedPolicy.from_aws_managed_policy_name("AmazonSSMManagedInstanceCore")],
            description="Role for robotics simulation instances",
        )

        role.add_to_policy(iam.PolicyStatement(actions=["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"], resources=[bucket.bucket_arn, f"{bucket.bucket_arn}/*"]))
        role.add_to_policy(iam.PolicyStatement(actions=["ssm:GetParameter", "ssm:GetParameters", "ssm:PutParameter"], resources=[f"arn:aws:ssm:{self.region}:{self.account}:parameter{prefix}/*"]))

        instance_profile = iam.CfnInstanceProfile(
            self,
            "SimInstanceProfile",
            instance_profile_name=f"{config.project_name}-sim-instance-profile",
            roles=[role.role_name],
        )

        bootstrap_path = Path(__file__).resolve().parents[2] / "userdata" / "bootstrap.sh"
        bootstrap = bootstrap_path.resolve().read_text(encoding="utf-8")

        gazebo_user_data = ec2.UserData.custom(self._render_userdata(bootstrap, mode="gazebo", project_prefix_param=f"{prefix}/config/project-prefix", workspace_param=f"{prefix}/config/workspace-path", bucket_param=f"{prefix}/bucket-name"))
        isaac_user_data = ec2.UserData.custom(self._render_userdata(bootstrap, mode="isaac", project_prefix_param=f"{prefix}/config/project-prefix", workspace_param=f"{prefix}/config/workspace-path", bucket_param=f"{prefix}/bucket-name"))

        shared = {
            "iam_instance_profile": ec2.CfnLaunchTemplate.IamInstanceProfileProperty(name=instance_profile.instance_profile_name),
            "metadata_options": ec2.CfnLaunchTemplate.MetadataOptionsProperty(http_endpoint="enabled", http_tokens="required"),
            "instance_market_options": ec2.CfnLaunchTemplate.InstanceMarketOptionsProperty(
                market_type="spot",
                spot_options=ec2.CfnLaunchTemplate.SpotOptionsProperty(spot_instance_type="one-time", instance_interruption_behavior="terminate"),
            ),
            "block_device_mappings": [
                ec2.CfnLaunchTemplate.BlockDeviceMappingProperty(
                    device_name="/dev/sda1",
                    ebs=ec2.CfnLaunchTemplate.EbsProperty(volume_size=120, volume_type="gp3", delete_on_termination=True, encrypted=True),
                )
            ],
        }

        self.gazebo_lt = ec2.CfnLaunchTemplate(
            self,
            "GazeboLaunchTemplate",
            launch_template_name=f"{config.project_name}-gazebo-lt",
            launch_template_data=ec2.CfnLaunchTemplate.LaunchTemplateDataProperty(
                image_id=f"{{{{resolve:ssm:{prefix}/base-ami-id}}}}",
                instance_type="g5.xlarge",
                security_group_ids=[gazebo_sg.security_group_id],
                user_data=ec2.Fn.base64(gazebo_user_data.render()),
                tag_specifications=[_tag_spec("instance", config.project_name, "gazebo"), _tag_spec("volume", config.project_name, "gazebo")],
                **shared,
            ),
        )

        self.isaac_lt = ec2.CfnLaunchTemplate(
            self,
            "IsaacLaunchTemplate",
            launch_template_name=f"{config.project_name}-isaac-lt",
            launch_template_data=ec2.CfnLaunchTemplate.LaunchTemplateDataProperty(
                image_id=f"{{{{resolve:ssm:{prefix}/base-ami-id}}}}",
                instance_type="g6e.xlarge",
                security_group_ids=[isaac_sg.security_group_id],
                user_data=ec2.Fn.base64(isaac_user_data.render()),
                tag_specifications=[_tag_spec("instance", config.project_name, "isaac"), _tag_spec("volume", config.project_name, "isaac")],
                **shared,
            ),
        )

        if config.enable_elastic_ip:
            eip = ec2.CfnEIP(
                self,
                "SimulationEip",
                domain="vpc",
                tags=[
                    ec2.CfnTag(key="Project", value=config.project_name),
                    ec2.CfnTag(key="ManagedBy", value="cdk"),
                    ec2.CfnTag(key="Role", value="simulation-eip"),
                ],
            )
            ssm.StringParameter(
                self,
                "ElasticIpAllocationIdEnabledParam",
                parameter_name=f"{prefix}/config/elastic-ip-allocation-id",
                string_value=eip.attr_allocation_id,
                description="Optional EIP allocation ID reserved for simulation instances",
            )
        else:
            ssm.StringParameter(
                self,
                "ElasticIpAllocationIdParam",
                parameter_name=f"{prefix}/config/elastic-ip-allocation-id",
                string_value="none",
                description="Optional EIP allocation ID reserved for simulation instances",
            )

    def _render_userdata(self, bootstrap: str, *, mode: str, project_prefix_param: str, workspace_param: str, bucket_param: str) -> str:
        return (
            bootstrap.replace("__MODE__", mode)
            .replace("__PROJECT_PREFIX_PARAM__", project_prefix_param)
            .replace("__WORKSPACE_PATH_PARAM__", workspace_param)
            .replace("__BUCKET_PARAM__", bucket_param)
        )


def _tag_spec(resource_type: str, project_name: str, mode: str) -> ec2.CfnLaunchTemplate.TagSpecificationProperty:
    return ec2.CfnLaunchTemplate.TagSpecificationProperty(
        resource_type=resource_type,
        tags=[
            ec2.CfnTag(key="Project", value=project_name),
            ec2.CfnTag(key="Mode", value=mode),
            ec2.CfnTag(key="ManagedBy", value="cdk"),
        ],
    )
