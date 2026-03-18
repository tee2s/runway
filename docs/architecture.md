# Architecture

## Overview

The system uses a three-layer design:

1. **Infrastructure layer (CDK/Python)**
   - VPC, security groups, S3 bucket, IAM instance role/profile
   - Spot-ready launch templates for Gazebo and Isaac modes
   - Parameter Store keys for active AMI/snapshot/config and runtime state

2. **Image layer (Packer)**
   - Custom Ubuntu 22.04 base AMI
   - NVIDIA driver + NICE DCV + Docker + NVIDIA toolkit + AWS CLI
   - ROS 2 and Gazebo tooling
   - helper scripts under `/opt/robotics/bin`

3. **Operations layer (simctl CLI)**
   - Spot launch/terminate lifecycle
   - mode-aware startup and S3 sync operations
   - Isaac volume snapshot lifecycle management

## Compute Paths

### Gazebo path

- Launch Spot instance via Gazebo launch template
- Allowed families by CLI policy: `g4dn`, `g5`
- User data bootstrap syncs S3 project/assets and starts Gazebo runtime script

### Isaac path

- Launch Spot instance via Isaac launch template
- Allowed families by CLI policy: `g6e`, `g7e`
- CLI reads current Isaac snapshot from SSM
- CLI creates EBS volume from snapshot **in instance AZ**
- CLI attaches volume, then invokes mount/start scripts through SSM

## Storage Model

- **Base AMI root**: OS + core tools + ROS/Gazebo (no Isaac install)
- **Isaac EBS from snapshot**: Isaac binary/cache/log/config state
- **S3**: project and frequently changing assets/results

## Network/Security

- Security groups are separated by mode:
  - Gazebo SG: SSH (22), DCV (8443)
  - Isaac SG: SSH (22), DCV (8443), configurable WebRTC range
- Optional Elastic IP can be attached manually or by extending CLI flow

## Parameter Store Keys

- `/robotics-aws/base-ami-id`
- `/robotics-aws/isaac-snapshot-id`
- `/robotics-aws/bucket-name`
- `/robotics-aws/config/*` for defaults
- `/robotics-aws/current/*` for runtime instance/mode/volume tracking

## Bootstrap Strategy

User data executes `/userdata/bootstrap.sh` logic:

- creates local directories
- syncs S3 project/assets down
- mode-dependent startup:
  - Gazebo: starts gazebo helper
  - Isaac: attempts Isaac volume mount then starts Isaac helper

Mount and startup scripts are idempotent and can be re-run via SSM.
