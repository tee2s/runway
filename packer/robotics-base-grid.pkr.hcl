locals {
  grid_timestamp = regex_replace(timestamp(), "[- TZ:]", "")
  grid_stage     = "foundation"
  grid_variant   = var.robotics_variant
  grid_ami_name  = format("%s-%s-%s", var.ami_name_prefix, local.grid_stage, local.grid_timestamp)
}

source "amazon-ebs" "robotics_base_grid" {
  region               = var.region
  instance_type        = var.instance_type
  ssh_username         = var.ssh_username
  iam_instance_profile = var.iam_instance_profile

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

  ami_name        = local.grid_ami_name
  ami_description = "Robotics GRID foundation AMI with Ubuntu, AWS CLI, and NVIDIA GRID driver"

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
  }

  tags = {
    Name            = local.grid_ami_name
    Role            = var.ami_name_prefix
    BuiltBy         = "packer"
    RoboticsStage   = local.grid_stage
    RoboticsVariant = local.grid_variant
  }

  run_tags = {
    Name = "packer-build-robotics-base-grid-foundation"
  }
}

build {
  name    = "robotics-base-grid-foundation"
  sources = ["source.amazon-ebs.robotics_base_grid"]

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

  # AWS GRID driver guide reboots after package upgrades before installation.
  provisioner "shell" {
    inline              = ["sudo reboot"]
    expect_disconnect   = true
    start_retry_timeout = "10m"
  }

  provisioner "shell" {
    pause_before = "30s"
    inline       = ["echo Base reboot complete"]
  }

  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive",
      "GRID_DRIVER_VERSION=${var.grid_driver_version}"
    ]
    script = "packer/scripts/nvidia/install-grid-driver.sh"
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
