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

variable "trusted_client_cidr" {
  description = <<-EOT
    IPv4 CIDR allowed to reach SSH (22), NICE DCV (8443), and Isaac Sim livestream ports on the Isaac security group.
    Use your own public IP with host bits set, e.g. 198.51.100.75/32. Do not use 0.0.0.0/0 for Isaac streaming-facing ports.
    Isaac livestreaming is unauthenticated and not encrypted; for anything beyond a private/trusted path, terminate TLS and
    authenticate in front (e.g. reverse proxy), or keep these ports restricted and use VPN/private network only.
  EOT
  type        = string

  validation {
    condition = (
      length(trimspace(var.trusted_client_cidr)) > 0 &&
      var.trusted_client_cidr != "0.0.0.0/0"
    )
    error_message = "trusted_client_cidr must be non-empty and must not be 0.0.0.0/0. Set your client IP or office CIDR, e.g. 203.0.113.50/32."
  }
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
