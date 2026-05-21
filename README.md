<p align="center">
  <img src="./images/logo_runway.png" alt="Runway logo" width="128">
</p>

<h1 align="center">Runway</h1>

<p align="center">
  <strong>Cloud robotics dev, ready for takeoff.</strong>
</p>

<p align="center">
  Terraform + Packer for GPU robotics simulation workstations on AWS.
</p>

<br>

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
- `/work/docker` — Docker data-root (images, layers, build cache, volumes)
- `/work/.cache/uv` — uv download cache
- `/work/.cache/rattler` — Pixi/rattler package cache
- `/work/.local/share/uv/tools` — `uv tool install` environments
- `/work/.local/share/uv/python` — `uv python install` runtimes
- `/work/.local/bin` — executables from uv-installed tools and Python
- `/work/.config` — XDG config home for any XDG-aware tools
- `/work/.local/share` — XDG data home (catch-all)

Boot sets the following environment variables via `/etc/profile.d/dev-state.sh`:

```
XDG_CACHE_HOME=/work/.cache
XDG_DATA_HOME=/work/.local/share
XDG_CONFIG_HOME=/work/.config
XDG_BIN_HOME=/work/.local/bin
PATH=/work/.local/bin:$PATH

UV_CACHE_DIR=/work/.cache/uv
UV_TOOL_DIR=/work/.local/share/uv/tools
UV_TOOL_BIN_DIR=/work/.local/bin
UV_PYTHON_INSTALL_DIR=/work/.local/share/uv/python
UV_PYTHON_BIN_DIR=/work/.local/bin

PIXI_CACHE_DIR=/work/.cache/rattler
RATTLER_CACHE_DIR=/work/.cache/rattler
```

`uv` itself is baked into the AMI and stays on the root volume. Docker is reconfigured at boot to use `/work/docker` as its `data-root`; on first boot with a fresh volume, existing Docker data from the AMI is migrated there automatically.

### Enabling

```hcl
# terraform.tfvars
dev_state_volume_enabled  = true
dev_state_volume_size_gib = 120   # ignored when restoring from snapshot
persist_dev_state_volume  = true  # recommended — see below
```

```bash
terraform apply -var runtime_enabled=true
```

### Persist mode vs ephemeral mode

**Persist mode** (`persist_dev_state_volume = true`, recommended): the volume is kept alive between sessions. Stopping the runtime detaches the volume; starting again reattaches it. Spot termination is harmless — rerun `terraform apply` to get a new instance with the same volume. No snapshots needed for normal stop/start. The fleet is constrained to the volume's AZ (alphabetically first AZ in the region by default), which reduces spot AZ diversity but is the right tradeoff for a dev workstation.

```bash
terraform apply -var runtime_enabled=false   # detaches volume, keeps it
terraform apply -var runtime_enabled=true    # reattaches existing volume
```

**Ephemeral mode** (`persist_dev_state_volume = false`): the volume is created each session (from the latest snapshot) and destroyed on stop. The fleet picks the best AZ freely. Use `dev_state_auto_save` to snapshot automatically before destroy.

```hcl
persist_dev_state_volume = false
dev_state_auto_save      = true   # snapshot before destroy
```

```bash
terraform apply -var runtime_enabled=false   # snapshots first, then destroys volume
terraform apply -var runtime_enabled=true    # creates fresh volume from latest snapshot
```

If the instance was spot-terminated before stopping, auto-save is skipped (`on_failure = continue`) and the volume is destroyed — data since the last snapshot is lost.

### Manual snapshot

In either mode you can snapshot at any time:

```bash
sudo snapshot-dev-state
# → snap-0abc123...
```

`snapshot-dev-state` stops Docker, syncs the filesystem, creates a snapshot, waits for completion, writes the new snapshot ID to SSM, deletes the previous snapshot, then restarts Docker. The SSM-managed snapshot ID is also useful as a backup in persist mode (catastrophic volume loss, region move, etc.).

The current snapshot ID is always visible:

```bash
terraform output dev_state_snapshot_id
```

The script is written to `/usr/local/bin/snapshot-dev-state` on the instance by bootstrap (sourcing `/etc/robotics/dev-state.conf` for the SSM paths baked in at boot). `scripts/snapshot-dev-state.sh` in the repo is an identical reference copy.

> **IAM note:** auto-save uses `aws ssm send-command` from the machine executing Terraform. That identity needs `ssm:SendCommand` and `ssm:GetCommandInvocation`.

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