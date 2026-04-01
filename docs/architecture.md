# Architecture

## Overview

The system uses a Terraform-centric two-layer model plus image build:

1. **Core infrastructure layer (Terraform)**
   - VPC, IGW, public subnets, routing
   - Gazebo/Isaac security groups and ingress policies
   - S3 bucket with versioning, encryption, and TLS-only access policy
   - IAM role and instance profile for simulation EC2
   - Launch templates for Gazebo and Isaac
   - SSM parameters for infra config defaults

2. **Runtime layer (Terraform)**
   - Optional single active Spot runtime instance
   - Mode switch by variable (`gazebo` or `isaac`)
   - Optional Isaac runtime EBS volume from snapshot
   - Optional EIP association while runtime is active

3. **Image layer (Packer)**
   - Ubuntu-based AMI with GPU tooling, DCV, Docker, ROS/Gazebo, and helper scripts

## Runtime Control

Runtime lifecycle is driven directly by Terraform variables:

- `runtime_enabled = true` creates a session
- `runtime_enabled = false` removes runtime resources
- `simulation_mode = "gazebo" | "isaac"` selects launch template and mode-specific resources

Terraform outputs provide runtime identifiers and endpoints.

## Storage Model

- **Base AMI/root volume**: OS, tooling, helper scripts
- **Isaac EBS from snapshot**: Isaac-specific mutable runtime state
- **S3**: project artifacts, sync data, and outputs

## Bootstrap Strategy

User data template performs:

- local directory creation
- initial S3 sync-down
- mode-aware startup:
  - Gazebo starts Gazebo helper
  - Isaac attempts volume mount then starts Isaac helper

Bootstrap input parameters (bucket/prefix/workspace path) are resolved via SSM parameter names configured by Terraform.
