from dataclasses import dataclass

from aws_cdk import App


def _as_bool(value) -> bool:
    if isinstance(value, bool):
        return value
    if value is None:
        return False
    return str(value).strip().lower() in {"1", "true", "yes", "on"}


@dataclass(frozen=True)
class InfraConfig:
    project_name: str
    parameter_prefix: str
    bucket_name: str
    allowed_ssh_cidr: str
    gazebo_instance_types: str
    isaac_instance_types: str
    isaac_webrtc_tcp_ports: str
    isaac_webrtc_udp_ports: str
    enable_elastic_ip: bool

    @staticmethod
    def from_app(app: App) -> "InfraConfig":
        return InfraConfig(
            project_name=app.node.try_get_context("project_name") or "robotics-aws",
            parameter_prefix=app.node.try_get_context("parameter_prefix") or "/robotics-aws",
            bucket_name=app.node.try_get_context("bucket_name") or "",
            allowed_ssh_cidr=app.node.try_get_context("allowed_ssh_cidr") or "0.0.0.0/0",
            gazebo_instance_types=app.node.try_get_context("gazebo_instance_types") or "g4dn.xlarge,g5.xlarge",
            isaac_instance_types=app.node.try_get_context("isaac_instance_types") or "g6e.xlarge,g7e.xlarge",
            isaac_webrtc_tcp_ports=app.node.try_get_context("isaac_webrtc_tcp_ports") or "8211-8211",
            isaac_webrtc_udp_ports=app.node.try_get_context("isaac_webrtc_udp_ports") or "47995-48012",
            enable_elastic_ip=_as_bool(app.node.try_get_context("enable_elastic_ip")),
        )
