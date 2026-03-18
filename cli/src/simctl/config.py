from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import yaml


@dataclass
class SimConfig:
    region: str
    parameter_prefix: str
    project_name: str
    launch_templates: dict[str, str]
    allowed_instance_types: dict[str, list[str]]
    s3_project_prefix: str
    workspace_path: str
    webrtc_public_port: int

    @property
    def prefix(self) -> str:
        return self.parameter_prefix.rstrip("/")


def load_config(path: str | None = None) -> SimConfig:
    cfg_path = path or os.getenv("SIMCTL_CONFIG") or str(Path.home() / ".simctl.yaml")

    data: dict[str, Any] = {}
    if Path(cfg_path).exists():
        data = yaml.safe_load(Path(cfg_path).read_text(encoding="utf-8")) or {}

    region = data.get("region") or os.getenv("AWS_REGION") or os.getenv("AWS_DEFAULT_REGION") or "us-west-2"
    parameter_prefix = data.get("parameter_prefix") or os.getenv("SIMCTL_PARAMETER_PREFIX") or "/robotics-aws"
    project_name = data.get("project_name") or "robotics-aws"

    launch_templates = data.get("launch_templates") or {
        "gazebo": f"{project_name}-gazebo-lt",
        "isaac": f"{project_name}-isaac-lt",
    }

    allowed = data.get("allowed_instance_types") or {
        "gazebo": ["g4dn.xlarge", "g5.xlarge"],
        "isaac": ["g6e.xlarge", "g7e.xlarge"],
    }

    s3_data = data.get("s3") or {}
    webrtc = data.get("webrtc") or {}

    return SimConfig(
        region=region,
        parameter_prefix=parameter_prefix,
        project_name=project_name,
        launch_templates=launch_templates,
        allowed_instance_types=allowed,
        s3_project_prefix=s3_data.get("project_prefix") or "project/",
        workspace_path=s3_data.get("workspace_path") or "/workspace/project",
        webrtc_public_port=int(webrtc.get("public_port") or 8211),
    )
