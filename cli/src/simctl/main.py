from __future__ import annotations

import argparse
import sys

from .aws_ops import AwsOps
from .config import load_config


def cmd_up(args: argparse.Namespace) -> int:
    cfg = load_config(args.config)
    ops = AwsOps(cfg)

    mode = args.mode
    instance_id = ops.launch_mode(mode)
    ops.wait_instance_running(instance_id)
    allocation_id = ops.maybe_associate_eip(instance_id)
    info = ops.describe_instance(instance_id, mode)

    if mode == "isaac":
        volume_id = ops.create_and_attach_isaac_volume(instance_id, info.az)
        ops.wait_ssm_online(instance_id)
        ops.run_remote_script(instance_id, "/opt/robotics/bin/mount-isaac-volume.sh /dev/sdf /mnt/isaac && /opt/robotics/bin/start-isaac.sh", timeout_s=900)
        print(f"Attached Isaac volume: {volume_id}")

    ops.record_current_instance(instance_id, mode)

    print(f"Launched {mode} instance: {instance_id}")
    print(f"State: {info.state}")
    print(f"AZ: {info.az}")
    print(f"Public DNS: {info.public_dns}")
    print(f"Public IP: {info.public_ip}")
    if allocation_id:
        print(f"Elastic IP allocation associated: {allocation_id}")
    if info.public_dns:
        print(f"DCV URL: https://{info.public_dns}:8443")
    if mode == "isaac" and info.public_dns:
        print(f"Isaac WebRTC hint: ws://{info.public_dns}:{cfg.webrtc_public_port}")
    return 0


def cmd_down(args: argparse.Namespace) -> int:
    cfg = load_config(args.config)
    ops = AwsOps(cfg)
    ops.terminate_current(sync_first=not args.no_sync, keep_isaac_volume=args.keep_isaac_volume)
    print("Active simulation instance terminated and state cleared")
    return 0


def cmd_status(args: argparse.Namespace) -> int:
    cfg = load_config(args.config)
    ops = AwsOps(cfg)
    instance_id, mode = ops.get_current_instance()
    if not instance_id:
        print("No active simulation instance")
        return 0

    info = ops.describe_instance(instance_id, mode)
    print(f"Instance: {info.instance_id}")
    print(f"Mode: {info.mode}")
    print(f"State: {info.state}")
    print(f"AZ: {info.az}")
    print(f"Public DNS: {info.public_dns}")
    print(f"Public IP: {info.public_ip}")
    if info.public_dns:
        print(f"DCV: https://{info.public_dns}:8443")
        if mode == "isaac":
            print(f"Isaac WebRTC hint: ws://{info.public_dns}:{cfg.webrtc_public_port}")
    return 0


def cmd_sync_down(args: argparse.Namespace) -> int:
    cfg = load_config(args.config)
    AwsOps(cfg).sync_down()
    print("Sync-down complete")
    return 0


def cmd_sync_up(args: argparse.Namespace) -> int:
    cfg = load_config(args.config)
    AwsOps(cfg).sync_up()
    print("Sync-up complete")
    return 0


def cmd_snapshot(args: argparse.Namespace) -> int:
    cfg = load_config(args.config)
    snapshot_id = AwsOps(cfg).create_isaac_snapshot()
    print(f"Created snapshot: {snapshot_id}")
    print("Updated SSM parameter current Isaac snapshot ID")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="AWS robotics simulation controller")
    parser.add_argument("--config", help="Path to simctl YAML config")

    sub = parser.add_subparsers(dest="command", required=True)

    up = sub.add_parser("up", help="Launch simulation instance")
    up.add_argument("mode", choices=["gazebo", "isaac"])
    up.set_defaults(func=cmd_up)

    down = sub.add_parser("down", help="Terminate active simulation instance")
    down.add_argument("--no-sync", action="store_true", help="Skip sync-up before shutdown")
    down.add_argument("--keep-isaac-volume", action="store_true", help="Do not delete current Isaac runtime EBS volume")
    down.set_defaults(func=cmd_down)

    status = sub.add_parser("status", help="Show active simulation status")
    status.set_defaults(func=cmd_status)

    sync_down = sub.add_parser("sync-down", help="Sync project from S3 to active instance")
    sync_down.set_defaults(func=cmd_sync_down)

    sync_up = sub.add_parser("sync-up", help="Sync project from active instance to S3")
    sync_up.set_defaults(func=cmd_sync_up)

    snap = sub.add_parser("create-isaac-snapshot", help="Snapshot current Isaac volume and update SSM")
    snap.set_defaults(func=cmd_snapshot)

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    try:
        rc = args.func(args)
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
    sys.exit(rc)


if __name__ == "__main__":
    main()
