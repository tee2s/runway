output "vpc_id" {
  description = "VPC ID for robotics environment."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet ID(s) used for runtime sessions (single-AZ workstation layout)."
  value       = [aws_subnet.public.id]
}

output "bucket_name" {
  description = "S3 bucket storing project data."
  value       = aws_s3_bucket.project.bucket
}

output "gazebo_security_group_id" {
  description = "Security group for Gazebo mode."
  value       = aws_security_group.gazebo.id
}

output "isaac_security_group_id" {
  description = "Security group for Isaac mode."
  value       = aws_security_group.isaac.id
}

output "gazebo_launch_template_name" {
  description = "Gazebo launch template name."
  value       = aws_launch_template.gazebo.name
}

output "isaac_launch_template_name" {
  description = "Isaac launch template name."
  value       = aws_launch_template.isaac.name
}

output "runtime_instance_id" {
  description = "Current runtime instance ID when enabled."
  value       = var.runtime_enabled ? aws_instance.runtime[0].id : null
}

output "runtime_public_ip" {
  description = "Runtime public IP when enabled."
  value       = var.runtime_enabled ? aws_instance.runtime[0].public_ip : null
}

output "runtime_public_dns" {
  description = "Runtime public DNS when enabled."
  value       = var.runtime_enabled ? aws_instance.runtime[0].public_dns : null
}

output "runtime_dcv_url" {
  description = "Runtime DCV URL when enabled."
  value       = var.runtime_enabled ? "https://${aws_instance.runtime[0].public_dns}:8443" : null
}

output "isaac_runtime_volume_id" {
  description = "Isaac runtime volume ID when isaac mode is enabled."
  value       = var.runtime_enabled && var.simulation_mode == "isaac" ? aws_ebs_volume.isaac_runtime[0].id : null
}