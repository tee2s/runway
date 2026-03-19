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

variable "ami_name_prefix" {
  type    = string
  default = "robotics-base"
}

variable "ssh_username" {
  type    = string
  default = "ubuntu"
}

variable "ros_distro" {
  type    = string
  default = "kilted"
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "amazon-ebs" "robotics_base" {
  region        = var.region
  instance_type = var.instance_type
  ssh_username  = var.ssh_username

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
      architecture        = "x86_64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"] # Canonical
  }

  ami_name        = "${var.ami_name_prefix}-${local.timestamp}"
  ami_description = "Base AMI with NVIDIA driver, DCV, Docker, AWS CLI, ROS 2, Gazebo"

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
  }

  tags = {
    Name    = "${var.ami_name_prefix}-${local.timestamp}"
    Role    = "${var.ami_name_prefix}"
    BuiltBy = "packer"
  }

  run_tags = {
    Name = "packer-build-robotics-base"
  }
}

build {
  name    = "robotics-base"
  sources = ["source.amazon-ebs.robotics_base"]

  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
    script = "scripts/setup-base.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
    script = "scripts/install-driver.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
    script = "scripts/install-dcv.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
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
    script = "scripts/install-helper-scripts.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
    script = "scripts/cleanup.sh"
  }
}
