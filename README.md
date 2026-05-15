# Robotics Development Cloud Infrastructure

Terraform + Packer setup for running GPU workstation setup for robotics simulation environments on AWS.

Supports two runtime modes:

- `gazebo` (ROS/Gazebo workflows)
- `isaac` (Isaac Sim workflows)

The repo is split into:

- `packer/`: builds staged AMIs (GPU foundation, DCV/desktop, containers, simulation tooling, package overlay)
- `terraform/`: provisions core infrastructure and controls runtime sessions
- `terraform/templates/bootstrap.sh.tftpl`: instance bootstrap script rendered into launch template user data
- `scripts/`: helper scripts (run on the instance or locally)

## Architecture

High-level flow:

1. Build a reusable AMI with Packer.
2. Provision core infra with Terraform (VPC, public subnets in every region AZ, SGs, IAM, S3, launch templates, SSM params).
3. Start/stop a single runtime instance through EC2 Fleet by flipping Terraform variables.

Runtime control:

- `runtime_enabled = true|false`
- `simulation_mode = "gazebo"|"isaac"`
- `gazebo_launch_template_instance_types` and `isaac_launch_template_instance_types` provide EC2 Fleet candidate GPU shapes.

In `isaac` mode, an EBS data volume can be created from snapshot and attached/mounted at boot.

A separate **dev-state volume** (optional, works in both modes) keeps mutable data off the AMI root: Docker images, tool caches, and workspace files. It persists across sessions via snapshots.

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
- `dev_state_snapshot_id` (optional; leave empty on first run)

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

When `runtime_enabled=true`, Terraform launches the runtime through EC2 Fleet using Spot `price-capacity-optimized` placement across every public subnet and configured candidate instance type for the selected mode. Terraform also writes a DCV connection file in `~/.config/dcv/<project_name>.dcv` (for example `~/.config/dcv/robotics-dev.dcv`) that you can open with `dcvviewer`.

## Dev-state volume

The dev-state volume is an optional EBS volume (works in both Gazebo and Isaac modes) that keeps mutable state off the AMI root so the root volume stays a clean, reusable image.

What lives on it:

- `/work/ws` — project workspace files (symlinked to `/home/ubuntu/ws`)
- `/work/docker` — Docker data-root (images, layers, build cache)
- `/work/.cache/uv`, `/work/.cache/rattler` — uv and Pixi/rattler caches
- `/work/.local/share` — XDG data home

Boot sets the following environment variables via `/etc/profile.d/dev-state.sh`:

```
XDG_CACHE_HOME=/work/.cache
XDG_DATA_HOME=/work/.local/share
UV_CACHE_DIR=/work/.cache/uv
PIXI_CACHE_DIR=/work/.cache/rattler
RATTLER_CACHE_DIR=/work/.cache/rattler
```

Docker is reconfigured at boot to use `/work/docker` as its `data-root`. On first boot with a fresh volume the existing Docker data from the AMI is migrated there automatically.

### Enabling

```hcl
# terraform.tfvars
dev_state_volume_enabled  = true
dev_state_volume_size_gib = 200   # ignored when restoring from snapshot
dev_state_snapshot_id     = ""    # empty = fresh volume
```

```bash
terraform apply -var runtime_enabled=true -var dev_state_volume_enabled=true
```

### Persisting state across sessions

The volume is created fresh (or from snapshot) each session and destroyed when the runtime stops, so you must snapshot before stopping if you want to keep state.

Run on the instance before stopping:

```bash
sudo snapshot-dev-state
# → snap-0abc123...
```

`snapshot-dev-state` stops Docker, syncs the filesystem, creates the snapshot, waits for it to complete, restarts Docker, and prints the snapshot ID. Set that ID for the next session:

```hcl
dev_state_snapshot_id = "snap-0abc123..."
```

The script is written to `/usr/local/bin/snapshot-dev-state` on the instance by bootstrap — it is not copied from the repo at runtime. `scripts/snapshot-dev-state.sh` in the repo is an identical reference copy.

## Workspace sync

The instance boots with two aliases for syncing your workspace to/from S3:

```bash
s3-pull   # S3 → local (runs automatically at boot)
s3-push   # local → S3
```

Both aliases respect a `.s3ignore` file in the workspace root. Create it to exclude large or ephemeral directories:

```
# .s3ignore
.pixi/*
.venv/*
__pycache__/*
*.pyc
build/*
```

Lines starting with `#` and blank lines are ignored. If `.s3ignore` is absent the sync runs without any exclusions.

## Security notes

- `trusted_client_cidr` is required; `0.0.0.0/0` is intentionally rejected.
- SSH and DCV are restricted to the trusted CIDR.
- Isaac streaming ports are also CIDR-restricted, but the stream itself is not authenticated/encrypted. Keep access private or put TLS/auth in front of it.

## AMI build

Packer builds are staged so package-only changes do not require rebuilding GPU drivers, DCV, Docker, ROS/Gazebo, and Isaac Sim from scratch.

Shared Packer settings live in `packer/versions.pkr.hcl` and `packer/variables.pkr.hcl`, so build commands target the `packer/` directory and select one stage with `-only`.

Initialize Packer plugins once:

```bash
packer init packer/
```

Standard NVIDIA chain:

```bash
# 1. Foundation: Ubuntu + AWS CLI + NVIDIA driver
packer build -only=robotics-base-foundation.amazon-ebs.robotics_base -var-file=packer/robotics-base.pkrvars.hcl packer/

# 2. Desktop/DCV
packer build -only=robotics-dcv.amazon-ebs.robotics_dcv -var-file=packer/robotics-base.pkrvars.hcl packer/

# 3. Containers
packer build -only=robotics-containers.amazon-ebs.robotics_containers -var-file=packer/robotics-base.pkrvars.hcl packer/

# 4. Simulation tooling
packer build -only=robotics-simulation.amazon-ebs.robotics_simulation -var-file=packer/robotics-base.pkrvars.hcl packer/

# 5. Final packages + login policy
packer build -only=robotics-packages.amazon-ebs.robotics_packages -var-file=packer/robotics-base.pkrvars.hcl packer/
```

GRID chain:

```bash
# 1. Foundation: Ubuntu + AWS CLI + NVIDIA GRID driver
packer build -only=robotics-base-grid-foundation.amazon-ebs.robotics_base_grid -var-file=packer/robotics-base-grid.pkrvars.hcl packer/

# 2. Desktop/DCV
packer build -only=robotics-dcv.amazon-ebs.robotics_dcv -var-file=packer/robotics-base-grid.pkrvars.hcl packer/

# 3. Containers
packer build -only=robotics-containers.amazon-ebs.robotics_containers -var-file=packer/robotics-base-grid.pkrvars.hcl packer/

# 4. Simulation tooling
packer build -only=robotics-simulation.amazon-ebs.robotics_simulation -var-file=packer/robotics-base-grid.pkrvars.hcl packer/

# 5. Final packages 
packer build -only=robotics-packages.amazon-ebs.robotics_packages -var-file=packer/robotics-base-grid.pkrvars.hcl packer/
```

Each downstream stage selects the latest successful parent AMI by generated name plus `RoboticsStage` and `RoboticsVariant` tags. The final package stage runs `packer/scripts/install-packages.sh`, which currently installs Pixi, and applies the SSH password-authentication policy. To add more final-stage package tooling, edit that script and rebuild only the package stage. The Ubuntu password hash is applied at runtime by Terraform bootstrap from the SSM parameter configured as `ubuntu_password_hash_parameter_name`.

### `install_system_ros` variable

Both pkrvars files expose `install_system_ros` (default `true`). Set it to `false` when ROS and Gazebo are managed per-project via Pixi environments — the system-wide install is then unnecessary and skipped entirely during the simulation stage. No other stages depend on a system ROS install.

For package-only changes after the simulation AMI already exists, rerun only the final package command for the selected pipeline.

After building the final package overlay AMI, use that AMI ID as `base_ami_id` in `terraform.tfvars`.