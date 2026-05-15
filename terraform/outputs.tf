output "vpc_id" {
  description = "VPC ID for robotics environment."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs used for runtime sessions across all available AZs."
  value       = [for subnet in aws_subnet.public : subnet.id]
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
  value       = local.runtime_instance_id
}

output "runtime_instance_type" {
  description = "EC2 instance type of the runtime instance when enabled."
  value       = local.runtime_instance_type
}

output "runtime_public_ip" {
  description = "Runtime public IP when enabled."
  value       = local.runtime_public_ip
}

output "runtime_dcv_console_address" {
  description = "Runtime NICE DCV console address (public_ip:8443#console) when enabled."
  value       = var.runtime_enabled ? format("%s:8443#console", local.runtime_public_ip) : null
}

output "runtime_dcv_connection_file_path" {
  description = "Local path to generated NICE DCV connection file (.dcv) when runtime is enabled."
  value       = var.runtime_enabled ? local_file.runtime_dcv_connection_file[0].filename : null
}

output "isaac_runtime_volume_id" {
  description = "Isaac runtime volume ID when isaac mode is enabled."
  value       = var.runtime_enabled && var.simulation_mode == "isaac" ? aws_ebs_volume.isaac_runtime[0].id : null
}

output "runtime_spot_price" {
  description = "Current spot price (USD/hr) for the runtime instance type and AZ when enabled."
  value       = var.runtime_enabled ? data.aws_ec2_spot_price.runtime[0].spot_price : null
}

output "dev_state_volume_id" {
  description = "Dev-state EBS volume ID when enabled and runtime is active."
  value       = var.dev_state_volume_enabled && var.runtime_enabled ? aws_ebs_volume.dev_state[0].id : null
}

output "dev_state_device_name" {
  description = "Device name for the dev-state volume attachment."
  value       = var.dev_state_volume_enabled && var.runtime_enabled ? "/dev/sdg" : null
}

output "dev_state_mount_path" {
  description = "Mount path for the dev-state volume on the instance."
  value       = var.dev_state_volume_enabled ? var.dev_state_mount_path : null
}

output "dev_state_snapshot_source" {
  description = "Snapshot ID used to create the dev-state volume, if any."
  value       = var.dev_state_volume_enabled && trimspace(var.dev_state_snapshot_id) != "" ? var.dev_state_snapshot_id : null
}