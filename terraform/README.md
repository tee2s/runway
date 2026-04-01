# Terraform Workflow

This directory is the source of truth for robotics AWS infrastructure and runtime sessions.

## Concepts

- **Core infrastructure** is always managed by Terraform resources in this root.
- **Runtime session** is controlled by:
  - `runtime_enabled` (`true` to run one instance, `false` to stop it)
  - `simulation_mode` (`gazebo` or `isaac`)

## Quick Start

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

## Runtime Operations

Launch Gazebo:

```bash
terraform apply -var runtime_enabled=true -var simulation_mode=gazebo
```

Launch Isaac:

```bash
terraform apply -var runtime_enabled=true -var simulation_mode=isaac
```

Stop runtime instance:

```bash
terraform apply -var runtime_enabled=false
```

## Notes

- Set `base_ami_id` and `isaac_snapshot_id` before launching runtime sessions.
- If `enable_elastic_ip=true`, Terraform reserves an EIP and associates it to runtime while enabled.
- Use `terraform output` to retrieve runtime endpoints and IDs.
