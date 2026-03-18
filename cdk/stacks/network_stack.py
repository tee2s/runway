from aws_cdk import Stack, aws_ec2 as ec2
from constructs import Construct

from .config import InfraConfig


class NetworkStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, *, config: InfraConfig, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        self.vpc = ec2.Vpc(
            self,
            "Vpc",
            vpc_name=f"{config.project_name}-vpc",
            max_azs=2,
            nat_gateways=0,
            subnet_configuration=[
                ec2.SubnetConfiguration(
                    name="public",
                    subnet_type=ec2.SubnetType.PUBLIC,
                    cidr_mask=24,
                )
            ],
        )

        self.gazebo_sg = ec2.SecurityGroup(
            self,
            "GazeboSg",
            vpc=self.vpc,
            security_group_name=f"{config.project_name}-gazebo-sg",
            description="SG for Gazebo simulation instances",
            allow_all_outbound=True,
        )

        self.isaac_sg = ec2.SecurityGroup(
            self,
            "IsaacSg",
            vpc=self.vpc,
            security_group_name=f"{config.project_name}-isaac-sg",
            description="SG for Isaac simulation instances",
            allow_all_outbound=True,
        )

        for sg in [self.gazebo_sg, self.isaac_sg]:
            sg.add_ingress_rule(ec2.Peer.ipv4(config.allowed_ssh_cidr), ec2.Port.tcp(22), "SSH")
            sg.add_ingress_rule(ec2.Peer.ipv4(config.allowed_ssh_cidr), ec2.Port.tcp(8443), "NICE DCV")

        for spec in config.isaac_webrtc_tcp_ports.split(","):
            spec = spec.strip()
            if not spec:
                continue
            start, end = _parse_port_range(spec)
            self.isaac_sg.add_ingress_rule(
                ec2.Peer.ipv4(config.allowed_ssh_cidr),
                ec2.Port.tcp_range(start, end),
                f"Isaac WebRTC TCP {start}-{end}",
            )

        for spec in config.isaac_webrtc_udp_ports.split(","):
            spec = spec.strip()
            if not spec:
                continue
            start, end = _parse_port_range(spec)
            self.isaac_sg.add_ingress_rule(
                ec2.Peer.ipv4(config.allowed_ssh_cidr),
                ec2.Port.udp_range(start, end),
                f"Isaac WebRTC UDP {start}-{end}",
            )


def _parse_port_range(text: str) -> tuple[int, int]:
    if "-" not in text:
        p = int(text)
        return (p, p)
    left, right = text.split("-", 1)
    return (int(left), int(right))
