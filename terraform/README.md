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

When runtime is enabled, Terraform also generates a NICE DCV connection file at:

- `terraform/<project_name>.dcv` (for example, `terraform/robotics-dev.dcv`)

The file follows the AWS DCV connection file format (`[version]` + `[connect]`) and is populated with the runtime public IP.
Run it with:

```bash
dcvviewer ./robotics-dev.dcv
```

## Access Model (SSM first, SSH optional)

- Default access uses AWS Systems Manager Session Manager (no SSH key required).
- Optional SSH access is supported by setting `runtime_key_pair_name` to an existing EC2 key pair name.
- Do not generate private keys inside Terraform (`tls_private_key`) unless you explicitly accept private key material being stored in Terraform state.

Recommended SSH key workflow (outside Terraform state):

```bash
# 1) Generate key pair locally (private key stays on your machine)
ssh-keygen -t ed25519 -f ~/.ssh/robotics-dev -C "robotics-dev"

# 2) Register only the public key in AWS as an EC2 key pair
aws ec2 import-key-pair \
  --key-name robotics-dev \
  --public-key-material fileb://~/.ssh/robotics-dev.pub
```

Then set `runtime_key_pair_name = "robotics-dev"` in `terraform.tfvars`.

When `runtime_enabled = true`, Terraform also writes an SSH drop-in file at `~/.ssh/config.d/<project_name>` using:

- `Host <project_name>`
- `HostName` from the runtime public IP output value
- `IdentityFile` from `runtime_private_key_path`

Example:

```bash
ssh robotics-dev
```

## Notes

- Set `trusted_client_cidr` and `base_ami_id` before launching runtime sessions.
- S3 bucket naming is automatic: `<project_name>-<account_id>-<region>` (no `bucket_name` variable to set).
- `isaac_snapshot_id` is optional: set `snap-...` to restore Isaac data, or leave it empty to create a fresh mounted volume.
- Tune launch template sizing with `gazebo_launch_template_instance_type`, `isaac_launch_template_instance_type`, and `root_volume_size_gib` as needed.
- Set `runtime_private_key_path` to the private key file matching `runtime_key_pair_name` if you use SSH.
- Use `terraform output` to retrieve runtime endpoints and IDs.
