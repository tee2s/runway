# Robotics Development Cloud Infrastructure

Terraform + Packer setup for running GPU workstation setup for robotics simulation environments on AWS.

Supports two runtime modes:
- `gazebo` (ROS/Gazebo workflows)
- `isaac` (Isaac Sim workflows)

The repo is split into:
- `packer/`: builds the base AMI (Ubuntu + NVIDIA + DCV + Docker + ROS/Gazebo + Isaac tooling)
- `terraform/`: provisions core infrastructure and controls runtime sessions
- `userdata/`: instance bootstrap script
- `docs/`: architecture notes and diagrams

## Architecture

High-level flow:
1. Build a reusable AMI with Packer.
2. Provision core infra with Terraform (VPC, subnet, SGs, IAM, S3, launch templates, SSM params).
3. Start/stop a single runtime instance by flipping Terraform variables.

Runtime control:
- `runtime_enabled = true|false`
- `simulation_mode = "gazebo"|"isaac"`

In `isaac` mode, an EBS volume can be created from snapshot and attached/mounted at boot.

More detail: `docs/architecture.md` and `docs/diagrams/network.mmd`.

## Prerequisites

- AWS account and credentials configured locally
- Terraform (recent 1.x)
- Packer (>= 1.14)

## Quick start

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Set at least:
- `trusted_client_cidr` (your IP/32 or office CIDR)
- `base_ami_id`
- `isaac_snapshot_id` (optional for `isaac` mode; leave empty for a fresh volume)

Then:

```bash
terraform init
terraform apply
```

## Runtime operations

Start Gazebo:

```bash
terraform apply -var runtime_enabled=true -var simulation_mode=gazebo
```

Start Isaac:

```bash
terraform apply -var runtime_enabled=true -var simulation_mode=isaac
```

Stop runtime:

```bash
terraform apply -var runtime_enabled=false
```

Get endpoints:

```bash
terraform output
```

When `runtime_enabled=true`, Terraform also writes a DCV connection file in `terraform/<project_name>.dcv` (for example `terraform/robotics-dev.dcv`) that you can open with `dcvviewer`.

## Security notes

- `trusted_client_cidr` is required; `0.0.0.0/0` is intentionally rejected.
- SSH and DCV are restricted to the trusted CIDR.
- Isaac streaming ports are also CIDR-restricted, but the stream itself is not authenticated/encrypted. Keep access private or put TLS/auth in front of it.

## AMI build

Base AMI build files live in `packer/` (`robotics-base.pkr.hcl` and vars files).  
After building, use the resulting AMI ID as `base_ami_id` in `terraform.tfvars`.