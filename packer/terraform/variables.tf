variable "region" {
  description = "AWS region where IAM resources are created (global names; region still required for provider)."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Used for resource tags."
  type        = string
  default     = "robotics-aws"
}
