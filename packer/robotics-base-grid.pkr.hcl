packer {
  required_version = ">= 1.14.0"

  required_plugins {
    amazon = {
      version = "~> 1.8.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "instance_type" {
  type    = string
  default = "g4dn.xlarge"
}

variable "root_volume_size" {
  type    = number
  default = 120
}

variable "source_ami_filter_name" {
  type    = string
  default = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
}

variable "ubuntu_distro_tag" {
  type    = string
  default = "ubuntu2404"
}

variable "ami_name_prefix" {
  type    = string
  default = "robotics-base-grid"
}

variable "ssh_username" {
  type    = string
  default = "ubuntu"
}

variable "nvidia_driver_branch" {
  type    = string
  default = "580"
}

variable "nvidia_driver_version" {
  type    = string
  default = ""
}

variable "dcv_version" {
  type    = string
  default = ""
}

variable "nvidia_container_toolkit_version" {
  type    = string
  default = ""
}

variable "ros_distro" {
  type    = string
  default = "kilted"
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
  ami_name  = format("%s-%s", var.ami_name_prefix, local.timestamp)
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

  ami_name        = local.ami_name
  ami_description = "Base AMI with NVIDIA GRID driver, DCV, Docker, AWS CLI, ROS 2, Gazebo"

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
  }

  tags = {
    Name    = local.ami_name
    Role    = var.ami_name_prefix
    BuiltBy = "packer"
  }

  run_tags = {
    Name = "packer-build-robotics-base-grid"
  }
}

build {
  name    = "robotics-base-grid"
  sources = ["source.amazon-ebs.robotics_base"]

  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
    script = "scripts/setup-base.sh"
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
      "UBUNTU_DISTRO_TAG=${var.ubuntu_distro_tag}",
      "NVIDIA_DRIVER_BRANCH=${var.nvidia_driver_branch}",
      "NVIDIA_DRIVER_VERSION=${var.nvidia_driver_version}"
    ]
    script = "scripts/nvidia/install-grid-driver.sh"
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
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive",
      "NVIDIA_DRIVER_BRANCH=${var.nvidia_driver_branch}",
      "NVIDIA_DRIVER_VERSION=${var.nvidia_driver_version}"
    ]
    script = "scripts/nvidia/validate-driver.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
    script = "scripts/dcv/install-desktop.sh"
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
    script = "scripts/dcv/configure-display.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive",
      "UBUNTU_DISTRO_TAG=${var.ubuntu_distro_tag}",
      "DCV_VERSION=${var.dcv_version}"
    ]
    script = "scripts/dcv/install-dcv.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
    script = "scripts/dcv/validate-dcv.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive",
      "NVIDIA_CONTAINER_TOOLKIT_VERSION=${var.nvidia_container_toolkit_version}"
    ]
    script = "scripts/install-docker.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
    script = "scripts/install-awscli.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive",
      "ROS_DISTRO=${var.ros_distro}"
    ]
    script = "scripts/install-ros-gazebo.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
    script = "scripts/install-distrobox.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
    script = "scripts/cleanup.sh"
  }
}
