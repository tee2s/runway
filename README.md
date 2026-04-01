# robotics-aws

Terraform-first AWS Spot workflow for robotics simulation with **Gazebo** and **Isaac Sim**.

The repository is organized as:

1. **Terraform** for infrastructure and runtime session control
2. **Packer** for custom AMI creation
3. **User-data + helper scripts** for boot-time sync and simulator startup

## What This System Does

- Builds and manages VPC, subnets, security groups, S3, IAM role/profile, launch templates, and SSM config parameters.
- Runs one active simulation session declaratively through Terraform:
  - `simulation_mode = "gazebo"` or `simulation_mode = "isaac"`
  - `runtime_enabled = true|false`
- Supports an optional Elastic IP.
- Uses an Isaac EBS volume from snapshot when Isaac mode is active.

## Prerequisites

- Terraform 1.6+
- AWS CLI configured with credentials and region access
- Packer 1.10+
- IAM permissions for EC2, VPC, IAM, S3, SSM, and EBS snapshots

## Repo Layout

```text
robotics-aws/
  README.md
  .env.example
  docs/
    architecture.md
  terraform/
    README.md
    providers.tf
    variables.tf
    locals.tf
    core-network.tf
    core-storage.tf
    core-compute-definitions.tf
    runtime.tf
    outputs.tf
    terraform.tfvars.example
  packer/
    ...
  userdata/
    bootstrap.sh
```

## Terraform Workflow

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# set base_ami_id and isaac_snapshot_id in terraform.tfvars
terraform init
terraform plan
terraform apply
```

### Runtime Operations

Launch Gazebo runtime:

```bash
terraform apply -var runtime_enabled=true -var simulation_mode=gazebo
```

Launch Isaac runtime:

```bash
terraform apply -var runtime_enabled=true -var simulation_mode=isaac
```

Terminate runtime:

```bash
terraform apply -var runtime_enabled=false
```

Get connection details:

```bash
terraform output runtime_public_dns
terraform output runtime_dcv_url
```

## Build Base AMI (Packer)

```bash
cd packer
packer init .
packer build \
  -var "region=us-west-2" \
  -var "source_ami_filter_name=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
  -var "instance_type=g5.xlarge" \
  robotics-base.pkr.hcl
```

Use the built AMI ID as `base_ami_id` in Terraform inputs.

## Architecture

See `docs/architecture.md` for a compact system-level view.
