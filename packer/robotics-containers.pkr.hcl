locals {
  containers_timestamp    = regex_replace(timestamp(), "[- TZ:]", "")
  containers_stage        = "containers"
  containers_parent_stage = "dcv"
  containers_variant      = var.robotics_variant
  containers_ami_name     = format("%s-%s-%s", var.ami_name_prefix, local.containers_stage, local.containers_timestamp)
}

source "amazon-ebs" "robotics_containers" {
  region        = var.region
  instance_type = var.instance_type
  ssh_username  = var.ssh_username

  source_ami_filter {
    filters = {
      name                  = format("%s-%s-*", var.ami_name_prefix, local.containers_parent_stage)
      architecture          = "x86_64"
      root-device-type      = "ebs"
      virtualization-type   = "hvm"
      "tag:RoboticsStage"   = local.containers_parent_stage
      "tag:RoboticsVariant" = local.containers_variant
      "tag:BuiltBy"         = "packer"
    }
    most_recent = true
    owners      = var.parent_ami_owners
  }

  ami_name        = local.containers_ami_name
  ami_description = "Robotics containers AMI with Docker, NVIDIA Container Toolkit, and Distrobox"

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
  }

  tags = {
    Name                = local.containers_ami_name
    Role                = var.ami_name_prefix
    BuiltBy             = "packer"
    RoboticsStage       = local.containers_stage
    RoboticsVariant     = local.containers_variant
    ParentRoboticsStage = local.containers_parent_stage
    ParentAmiFilter     = format("%s-%s-*", var.ami_name_prefix, local.containers_parent_stage)
  }

  run_tags = {
    Name = format("packer-build-%s-%s", var.ami_name_prefix, local.containers_stage)
  }
}

build {
  name    = "robotics-containers"
  sources = ["source.amazon-ebs.robotics_containers"]

  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive",
      "NVIDIA_CONTAINER_TOOLKIT_VERSION=${var.nvidia_container_toolkit_version}"
    ]
    script = "packer/scripts/install-docker.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
    script = "packer/scripts/install-distrobox.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
    script = "packer/scripts/cleanup.sh"
  }
}
