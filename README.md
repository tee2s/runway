# robotics-aws

Reproducible AWS Spot workflow for robotics simulation with **Gazebo** and **Isaac Sim**, implemented as three layers:

1. **AWS CDK (Python)** for infrastructure
2. **Packer** for a custom base AMI
3. **simctl CLI (Python)** for day-to-day operations

This project is designed to avoid dependency on marketplace robotics AMIs while keeping startup practical and storage costs controlled.

## What This System Does

- Launches Spot instances for simulation with strict family constraints:
  - Gazebo: `g4dn` / `g5`
  - Isaac: `g6e` / `g7e`
- Uses a custom base AMI (Ubuntu + GPU/DCV/Docker/ROS/Gazebo toolchain)
- Uses an Isaac-specific EBS volume recreated from snapshot for each Isaac launch
- Syncs frequently changing project/assets data from S3 at boot and on demand
- Provides operational commands:
  - `sim up gazebo`
  - `sim up isaac`
  - `sim down`
  - `sim status`
  - `sim sync-down`
  - `sim sync-up`
  - `sim create-isaac-snapshot`

## Storage Split

- **Base AMI / root volume**
  - Ubuntu, NVIDIA driver, NICE DCV server
  - Docker + NVIDIA Container Toolkit
  - AWS CLI, SSM agent, ROS 2, Gazebo
  - helper scripts in `/opt/robotics/bin`
- **Isaac EBS volume (from snapshot)**
  - Isaac Sim program + cache + config + logs + writable Isaac state
  - mounted at `/mnt/isaac`
- **S3 bucket**
  - project code/data, scenes/assets, frequently updated files, outputs

## Architecture

See `docs/architecture.md` for a compact technical breakdown.

## Repo Layout

```text
robotics-aws/
  README.md
  .env.example
  docs/
    architecture.md
  cdk/
    app.py
    cdk.json
    requirements.txt
    stacks/
      config.py
      network_stack.py
      storage_stack.py
      compute_stack.py
  packer/
    base-ami.pkr.hcl
    scripts/
      setup-base.sh
      install-driver.sh
      install-dcv.sh
      install-docker.sh
      install-awscli.sh
      install-ros-gazebo.sh
      install-helper-scripts.sh
      cleanup.sh
  cli/
    pyproject.toml
    config.example.yaml
    src/simctl/
      __init__.py
      config.py
      aws_ops.py
      main.py
  userdata/
    bootstrap.sh
  scripts/
    mount-isaac-volume.sh
    s3-sync-project-down.sh
    s3-sync-project-up.sh
    start-gazebo.sh
    start-isaac.sh
```

## Prerequisites

- Python 3.11+
- AWS CLI configured with credentials and target region
- CDK bootstrap in the target account/region
- Packer 1.10+
- IAM permissions for EC2, S3, IAM pass role, SSM, snapshots, CDK deploy

## 1) Deploy Infrastructure (CDK)

```bash
cd cdk
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Optional: set region/account
export CDK_DEFAULT_REGION=us-west-2
export CDK_DEFAULT_ACCOUNT=<your-account-id>

cdk bootstrap
cdk deploy --all
```

Outputs/created resources include:
- VPC + subnets
- SGs for Gazebo and Isaac
- S3 bucket
- IAM role/instance profile
- Launch templates for Gazebo and Isaac
- SSM Parameter Store entries for AMI/snapshot/config/current-state

## 2) Build Base AMI (Packer)

```bash
cd packer
packer init .
packer build   -var "region=us-west-2"   -var "source_ami_filter_name=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"   -var "instance_type=g5.xlarge"   base-ami.pkr.hcl
```

After build completes, update SSM parameter `/robotics-aws/base-ami-id` with the produced AMI ID:

```bash
aws ssm put-parameter   --name /robotics-aws/base-ami-id   --type String   --value ami-xxxxxxxxxxxxxxxxx   --overwrite
```

## 3) Prepare First Isaac Volume + Snapshot

Because Isaac state is not in the base AMI:

1. Launch one temporary instance with base AMI (or `sim up isaac` once)
2. Create/attach an empty EBS volume
3. Install Isaac Sim and perform warmup/cache generation on that volume
4. Create snapshot from that volume
5. Store snapshot ID in SSM:

```bash
aws ssm put-parameter   --name /robotics-aws/isaac-snapshot-id   --type String   --value snap-xxxxxxxxxxxxxxxxx   --overwrite
```

From then on, `sim up isaac` recreates a fresh volume from that snapshot (AZ-aware) and mounts it at `/mnt/isaac`.

## 4) Install and Use CLI

```bash
cd cli
python3 -m venv .venv
source .venv/bin/activate
pip install -e .
cp config.example.yaml ~/.simctl.yaml
# edit ~/.simctl.yaml if needed
```

Basic workflow:

```bash
sim status
sim up gazebo
sim down
sim up isaac
sim create-isaac-snapshot
sim sync-up
sim down
```

## CLI Command Behavior

### `sim up gazebo`
- Launches Spot instance via Gazebo launch template
- Restricts overrides to allowed instance types (`g4dn*`, `g5*` defaults)
- Runs bootstrap to sync S3 project/assets and start Gazebo helper script
- Prints SSH/DCV connection info

### `sim up isaac`
- Launches Spot instance via Isaac launch template (`g6e*`, `g7e*` defaults)
- Detects instance AZ
- Creates EBS volume from configured Isaac snapshot in same AZ
- Attaches and mounts at `/mnt/isaac`
- Syncs project/assets and starts Isaac helper script
- Prints SSH/DCV/WebRTC info

### `sim down`
- Optionally `sync-up` first (default)
- Terminates active instance
- Deletes Isaac runtime volume by default (snapshot remains)

### `sim status`
- Shows active mode, instance state, AZ, DNS/IP, and endpoints

### `sim sync-down` / `sim sync-up`
- Invokes instance-side S3 sync scripts through SSM Run Command

### `sim create-isaac-snapshot`
- Snapshots current Isaac EBS volume
- Waits for completion
- Updates `/robotics-aws/isaac-snapshot-id`

## S3 Sync Model

Defaults:
- S3 prefix: `project/`
- instance workspace: `/workspace/project`

You can change bucket/prefix/path in `~/.simctl.yaml` and matching SSM parameters/userdata envs.

## Important Operational Note: AZ Restriction

EBS volumes can be attached only within the same Availability Zone as the instance.
`sim up isaac` explicitly creates the volume from snapshot **in the launched instance AZ** before attaching.

## Snapshot-Recreated Isaac EBS vs Persistent Hot EBS

Snapshot recreation (default):
- **Pros**: reproducible clean state, lower idle cost, easy rollback/versioning
- **Cons**: attach/create overhead and potential lazy-load penalties after snapshot restore

Persistent hot EBS (future option):
- **Pros**: fastest repeated startup for same dataset/cache state
- **Cons**: continuous EBS cost and manual lifecycle/state drift management

## Configuration

- `.env.example` provides environment variable examples.
- `cli/config.example.yaml` provides CLI defaults.
- CDK stores key values in Parameter Store under `/robotics-aws/*`.

## Notes

- This project intentionally does **not** install Isaac Sim in the base AMI.
- It does **not** rely on marketplace Isaac AMIs or Robotec AMIs.
- Top-level orchestration is CDK + Packer + CLI, not ROS launch files.
