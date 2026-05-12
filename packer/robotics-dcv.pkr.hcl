locals {
  dcv_timestamp    = regex_replace(timestamp(), "[- TZ:]", "")
  dcv_stage        = "dcv"
  dcv_parent_stage = "foundation"
  dcv_variant      = var.robotics_variant
  dcv_ami_name     = format("%s-%s-%s", var.ami_name_prefix, local.dcv_stage, local.dcv_timestamp)
}

source "amazon-ebs" "robotics_dcv" {
  region        = var.region
  instance_type = var.instance_type
  ssh_username  = var.ssh_username

  source_ami_filter {
    filters = {
      name                  = format("%s-%s-*", var.ami_name_prefix, local.dcv_parent_stage)
      architecture          = "x86_64"
      root-device-type      = "ebs"
      virtualization-type   = "hvm"
      "tag:RoboticsStage"   = local.dcv_parent_stage
      "tag:RoboticsVariant" = local.dcv_variant
      "tag:BuiltBy"         = "packer"
    }
    most_recent = true
    owners      = var.parent_ami_owners
  }

  ami_name        = local.dcv_ami_name
  ami_description = "Robotics DCV AMI with desktop display and Amazon DCV"

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
  }

  tags = {
    Name                = local.dcv_ami_name
    Role                = var.ami_name_prefix
    BuiltBy             = "packer"
    RoboticsStage       = local.dcv_stage
    RoboticsVariant     = local.dcv_variant
    ParentRoboticsStage = local.dcv_parent_stage
    ParentAmiFilter     = format("%s-%s-*", var.ami_name_prefix, local.dcv_parent_stage)
  }

  run_tags = {
    Name = format("packer-build-%s-%s", var.ami_name_prefix, local.dcv_stage)
  }
}

build {
  name    = "robotics-dcv"
  sources = ["source.amazon-ebs.robotics_dcv"]

  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
    script = "packer/scripts/dcv/install-desktop.sh"
  }

  provisioner "shell" {
    expect_disconnect = true
    inline            = ["sudo reboot"]
  }

  provisioner "shell" {
    pause_before = "30s"
    inline       = ["echo Desktop reboot complete"]
  }

  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
    script = "packer/scripts/dcv/configure-display.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive",
      "UBUNTU_DISTRO_TAG=${var.ubuntu_distro_tag}",
      "DCV_VERSION=${var.dcv_version}"
    ]
    script = "packer/scripts/dcv/install-dcv.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
    script = "packer/scripts/dcv/validate-dcv.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
    script = "packer/scripts/dcv/install-runtime-xorg-regeneration.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
    script = "packer/scripts/cleanup.sh"
  }
}
