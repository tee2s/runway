# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo does

Terraform + Packer infrastructure for GPU robotics workstations on AWS. Supports two simulation modes:
- `gazebo` — ROS/Gazebo workflows (g5.xlarge default)
- `isaac` — Isaac Sim workflows (g6e.xlarge default, optional EBS data volume)

## Terraform commands

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # first time only

terraform init
terraform apply                                 # apply core infra

# Start runtime
terraform apply -var runtime_enabled=true -var simulation_mode=gazebo
terraform apply -var runtime_enabled=true -var simulation_mode=isaac

# Stop runtime
terraform apply -var runtime_enabled=false

terraform output                                # get endpoints, instance ID, public IP
```

Required `terraform.tfvars` values: `trusted_client_cidr`, `base_ami_id`. `0.0.0.0/0` is rejected by validation.

## Packer commands

Initialize once:
```bash
packer init packer/
```

Stage builds target the `packer/` directory with `-only`. Select the vars file for standard NVIDIA (`robotics-base.pkrvars.hcl`) or GRID (`robotics-base-grid.pkrvars.hcl`):

```bash
# Standard NVIDIA chain (run in order):
packer build -only=robotics-base-foundation.amazon-ebs.robotics_base       -var-file=packer/robotics-base.pkrvars.hcl packer/
packer build -only=robotics-dcv.amazon-ebs.robotics_dcv                    -var-file=packer/robotics-base.pkrvars.hcl packer/
packer build -only=robotics-containers.amazon-ebs.robotics_containers      -var-file=packer/robotics-base.pkrvars.hcl packer/
packer build -only=robotics-simulation.amazon-ebs.robotics_simulation      -var-file=packer/robotics-base.pkrvars.hcl packer/
packer build -only=robotics-packages.amazon-ebs.robotics_packages          -var-file=packer/robotics-base.pkrvars.hcl packer/
```

For package-only changes (adding apt packages, Pixi, etc.), only rebuild the packages stage — it finds the latest simulation AMI automatically via `RoboticsStage`/`RoboticsVariant` tags. After building, set the new AMI ID as `base_ami_id` in `terraform.tfvars`.

## Architecture

### Two Terraform layers

**Core layer** (`core-*.tf`): VPC, public subnets (one per AZ), security groups, IAM role + instance profile, S3 bucket, launch templates for Gazebo and Isaac, SSM parameters. Applied once and rarely changed.

**Runtime layer** (`runtime.tf`): A single `aws_ec2_fleet` (type `instant`, Spot `price-capacity-optimized`) created when `runtime_enabled=true`. Fleet overrides cross every public subnet × every configured instance type, giving maximum Spot availability. For Isaac mode, an EBS volume (`/dev/sdf`) is created and attached; bootstrap handles NVMe device remapping automatically.

### Bootstrap (`terraform/templates/bootstrap.sh.tftpl`)

Rendered into user data per launch template. At boot it:
1. Reads config (bucket, prefix, workspace path) from SSM
2. Reads the Ubuntu password hash from a SecureString SSM parameter and applies it with `usermod`
3. Syncs S3 → local workspace
4. For Isaac: mounts the EBS data volume (handles NVMe device enumeration), creates an ext4 filesystem if blank, adds fstab entry, then bind-mounts Isaac cache dirs from `/mnt/isaac/persist/` to `~ubuntu/`

Bootstrap log: `/var/log/robotics-bootstrap.log`

### Packer AMI chain

```
Ubuntu 24.04 → foundation (NVIDIA or GRID driver) → dcv (desktop + Amazon DCV)
             → containers (Docker + nvidia-container-toolkit + Distrobox)
             → simulation (ROS/Gazebo + Isaac Sim)
             → packages (Pixi + apt overlay)  ← this is base_ami_id
```

Each non-foundation stage selects its parent by AMI name pattern + `RoboticsStage` + `RoboticsVariant` tags (`most_recent = true`). The variant (`standard` or `grid`) flows through from the pkrvars file.

### SSM parameters

All runtime config is stored under `var.parameter_prefix` (default `/robotics-dev`). The ubuntu password hash lives at a separate path (`/ubuntu-default-password-hash` by default, must be a `SecureString`). The instance IAM role has `kms:Decrypt` permission scoped to SSM via condition keys.

### Local SSH config

`terraform/local-connection.tf` writes a drop-in SSH config to `~/.ssh/conf.d/<project_name>` and a DCV connection file to `~/.config/dcv/<project_name>.dcv` (openable with `dcvviewer`) when the runtime is active.
