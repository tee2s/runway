locals {
  packages_timestamp    = regex_replace(timestamp(), "[- TZ:]", "")
  packages_stage        = "packages"
  packages_parent_stage = "simulation"
  packages_variant      = var.robotics_variant
  packages_ami_name     = format("%s-%s-%s", var.ami_name_prefix, local.packages_stage, local.packages_timestamp)
}

source "amazon-ebs" "robotics_packages" {
  region               = var.region
  instance_type        = var.instance_type
  ssh_username         = var.ssh_username
  iam_instance_profile = var.iam_instance_profile

  source_ami_filter {
    filters = {
      name                  = format("%s-%s-*", var.ami_name_prefix, local.packages_parent_stage)
      architecture          = "x86_64"
      root-device-type      = "ebs"
      virtualization-type   = "hvm"
      "tag:RoboticsStage"   = local.packages_parent_stage
      "tag:RoboticsVariant" = local.packages_variant
      "tag:BuiltBy"         = "packer"
    }
    most_recent = true
    owners      = var.parent_ami_owners
  }

  ami_name        = local.packages_ami_name
  ami_description = "Robotics package overlay AMI"

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
  }

  tags = {
    Name                = local.packages_ami_name
    Role                = var.ami_name_prefix
    BuiltBy             = "packer"
    RoboticsStage       = local.packages_stage
    RoboticsVariant     = local.packages_variant
    ParentRoboticsStage = local.packages_parent_stage
    ParentAmiFilter     = format("%s-%s-*", var.ami_name_prefix, local.packages_parent_stage)
  }

  run_tags = {
    Name = format("packer-build-%s-%s", var.ami_name_prefix, local.packages_stage)
  }
}

build {
  name    = "robotics-packages"
  sources = ["source.amazon-ebs.robotics_packages"]

  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
    script = "packer/scripts/install-packages.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
    script = "packer/scripts/cleanup.sh"
  }
}
