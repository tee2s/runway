variable "region" {
  description = "AWS region for infrastructure."
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Project name used in resource naming."
  type        = string
  default     = "robotics-aws"
}

variable "parameter_prefix" {
  description = "SSM parameter prefix path."
  type        = string
  default     = "/robotics-aws"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.42.0.0/16"
}

variable "allowed_ssh_cidr" {
  description = "CIDR that can reach SSH/DCV/WebRTC ports."
  type        = string
  default     = "0.0.0.0/0"
}

variable "bucket_name" {
  description = "Optional fixed bucket name; empty lets AWS assign one."
  type        = string
  default     = ""
}

variable "gazebo_instance_types" {
  description = "Allowed Gazebo spot instance types."
  type        = list(string)
  default     = ["g4dn.xlarge", "g5.xlarge"]
}

variable "isaac_instance_types" {
  description = "Allowed Isaac spot instance types."
  type        = list(string)
  default     = ["g6e.xlarge", "g7e.xlarge"]
}

variable "isaac_webrtc_tcp_ports" {
  description = "Isaac inbound TCP port specs (single ports or ranges)."
  type        = list(string)
  default     = ["8211-8211"]
}

variable "isaac_webrtc_udp_ports" {
  description = "Isaac inbound UDP port specs (single ports or ranges)."
  type        = list(string)
  default     = ["47995-48012"]
}

variable "enable_elastic_ip" {
  description = "Whether to reserve and use an elastic IP for runtime instance."
  type        = bool
  default     = false
}

variable "base_ami_id" {
  description = "Base AMI for simulation launch templates."
  type        = string
  default     = "ami-REPLACE-ME"
}

variable "isaac_snapshot_id" {
  description = "Snapshot used to create Isaac runtime volume."
  type        = string
  default     = "snap-REPLACE-ME"
}

variable "s3_project_prefix" {
  description = "Default S3 prefix for project data."
  type        = string
  default     = "project/"
}

variable "workspace_path" {
  description = "Default local workspace path on simulation instances."
  type        = string
  default     = "/workspace/project"
}

variable "runtime_enabled" {
  description = "Whether a simulation instance should be active."
  type        = bool
  default     = false
}

variable "simulation_mode" {
  description = "Runtime simulation mode."
  type        = string
  default     = "gazebo"

  validation {
    condition     = contains(["gazebo", "isaac"], var.simulation_mode)
    error_message = "simulation_mode must be gazebo or isaac."
  }
}
