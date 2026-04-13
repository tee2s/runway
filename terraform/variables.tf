variable "region" {
  description = "AWS region for infrastructure."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used in resource naming."
  type        = string
  default     = "robotics-dev"
}

variable "parameter_prefix" {
  description = "SSM parameter prefix path."
  type        = string
  default     = "/robotics-dev"
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

variable "gazebo_launch_template_instance_type" {
  description = "EC2 instance type used by the Gazebo launch template."
  type        = string
  default     = "g5.xlarge"
}

variable "isaac_launch_template_instance_type" {
  description = "EC2 instance type used by the Isaac launch template."
  type        = string
  default     = "g6e.xlarge"
}

variable "root_volume_size_gib" {
  description = "Root EBS volume size in GiB for simulation launch templates."
  type        = number
  default     = 120
}

variable "isaac_data_volume_size_gib" {
  description = "Size in GiB for the Isaac runtime data EBS volume when isaac_snapshot_id is empty."
  type        = number
  default     = 80
}

variable "base_ami_id" {
  description = "Base AMI for simulation launch templates."
  type        = string
  nullable    = false
}

variable "isaac_snapshot_id" {
  description = "Optional snapshot used to create Isaac runtime volume. Empty creates a new empty volume."
  type        = string
  default     = ""
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

variable "runtime_key_pair_name" {
  description = "Optional existing EC2 key pair name for SSH access. Leave null to use SSM Session Manager only."
  type        = string
  default     = null
}

variable "runtime_private_key_path" {
  description = "Path to the private SSH key file written in the local SSH drop-in config."
  type        = string
  default     = "~/.ssh/id_ed25519"
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
