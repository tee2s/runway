# Terraform Workflow

This directory is the source of truth for robotics AWS infrastructure and runtime sessions.

## Concepts

- **Core infrastructure** is always managed by Terraform resources in this root.
- **Runtime session** is controlled by:
  - `runtime_enabled` (`true` to run one instance, `false` to stop it)
  - `simulation_mode` (`gazebo` or `isaac`)

## Security (Isaac Sim livestreaming)

Isaac Sim livestreaming (desktop client and web viewer) is intended for **private or trusted networks**. Streaming endpoints are **not authenticated or encrypted**. This module:

- Requires **`trusted_client_cidr`** (your IP `/32` or a tight office CIDR). It **must not** be `0.0.0.0/0`.
- Opens only these inbound ports on the **Isaac** security group for that CIDR: **49100/tcp**, **8210/tcp**, **4799/udp**, plus SSH and NICE DCV to the same CIDR.

If you must reach streaming over the public Internet, add your own safeguards: for example a **reverse proxy** with **HTTPS/TLS** and **authentication** (e.g. nginx with certificates and HTTP basic auth), or use **VPN / private connectivity** and keep the security group tight.

## Quick Start

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Set trusted_client_cidr to your public IP/32 (see Security above).
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

- Set `trusted_client_cidr`, `base_ami_id`, and `isaac_snapshot_id` before launching runtime sessions.
- Tune launch template sizing with `gazebo_launch_template_instance_type`, `isaac_launch_template_instance_type`, and `root_volume_size_gib` as needed.
- Use `terraform output` to retrieve runtime endpoints and IDs.
