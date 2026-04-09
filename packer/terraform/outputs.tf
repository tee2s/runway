output "packer_grid_builder_instance_profile_name" {
  description = "Instance profile name for packer robotics-base-grid template (iam_instance_profile)."
  value       = aws_iam_instance_profile.packer_build_instance.name
}

output "packer_grid_builder_instance_profile_arn" {
  description = "Instance profile ARN."
  value       = aws_iam_instance_profile.packer_build_instance.arn
}

output "packer_grid_builder_role_arn" {
  description = "IAM role ARN behind packer-grid-builder-profile."
  value       = aws_iam_role.packer_build_instance.arn
}
