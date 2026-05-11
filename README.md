# Robotics Development Cloud Infrastructure

Terraform + Packer setup for running GPU workstation setup for robotics simulation environments on AWS.

Supports two runtime modes:
- `gazebo` (ROS/Gazebo workflows)
- `isaac` (Isaac Sim workflows)

The repo is split into:
- `packer/`: builds staged AMIs (GPU foundation, DCV/desktop, containers, simulation tooling, package overlay)
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

# 5. Final packages + login policy
packer build -only=robotics-packages.amazon-ebs.robotics_packages -var-file=packer/robotics-base-grid.pkrvars.hcl packer/
```

Each downstream stage selects the latest successful parent AMI by generated name plus `RoboticsStage` and `RoboticsVariant` tags. The final package stage runs `packer/scripts/install-packages.sh`, which currently installs Pixi. To add more final-stage package tooling, edit that script and rebuild only the package stage. To refresh the configured login password hash, edit the matching pipeline vars file and rebuild only the package stage.

For package-only changes after the simulation AMI already exists, rerun only the final package command for the selected pipeline.

After building the final package overlay AMI, use that AMI ID as `base_ami_id` in `terraform.tfvars`.