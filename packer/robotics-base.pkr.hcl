locals {
  base_timestamp = regex_replace(timestamp(), "[- TZ:]", "")
  base_stage     = "foundation"
  base_variant   = var.robotics_variant
  base_ami_name  = format("%s-%s-%s", var.ami_name_prefix, local.base_stage, local.base_timestamp)
}

source "amazon-ebs" "robotics_base" {
  region        = var.region
  instance_type = var.instance_type
  ssh_username  = var.ssh_username

  source_ami_filter {
    filters = {
      name                = var.source_ami_filter_name
      architecture        = "x86_64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"] # Canonical
  }

  ami_name        = local.base_ami_name
  ami_description = "Robotics foundation AMI with Ubuntu, AWS CLI, and NVIDIA driver"

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
  }

  tags = {
    Name            = local.base_ami_name
    Role            = var.ami_name_prefix
    BuiltBy         = "packer"
    RoboticsStage   = local.base_stage
    RoboticsVariant = local.base_variant
  }

  run_tags = {
    Name = "packer-build-robotics-base-foundation"
  }
}

build {
  name    = "robotics-base-foundation"
  sources = ["source.amazon-ebs.robotics_base"]

  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
    script = "packer/scripts/setup-base.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
    script = "packer/scripts/install-awscli.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive",
      "UBUNTU_DISTRO_TAG=${var.ubuntu_distro_tag}",
      "NVIDIA_DRIVER_BRANCH=${var.nvidia_driver_branch}",
      "NVIDIA_DRIVER_VERSION=${var.nvidia_driver_version}"
    ]
    script = "packer/scripts/nvidia/install-driver.sh"
  }

  provisioner "shell" {
    inline              = ["sudo reboot"]
    expect_disconnect   = true
    start_retry_timeout = "10m"
  }

  provisioner "shell" {
    pause_before = "30s"
    inline       = ["echo Desktop reboot complete"]
  }

  provisioner "shell" {
    script = "packer/scripts/nvidia/validate-driver.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
    script = "packer/scripts/cleanup.sh"
  }
}