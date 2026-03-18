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
  default = "g5.xlarge"
}

variable "source_ami_filter_name" {
  type    = string
  default = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
}

variable "ssh_username" {
  type    = string
  default = "ubuntu"
}

source "amazon-ebs" "robotics_base" {
  region        = var.region
  instance_type = var.instance_type
  ssh_username  = var.ssh_username

  ami_name        = "robotics-base-{{timestamp}}"
  ami_description = "Base AMI for robotics simulation (Gazebo + core GPU stack)"

  source_ami_filter {
    filters = {
      name                = var.source_ami_filter_name
      root-device-type    = "ebs"
      virtualization-type = "hvm"
      architecture        = "x86_64"
    }
    owners      = ["099720109477"]
    most_recent = true
  }

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 120
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Project   = "robotics-aws"
    ManagedBy = "packer"
    Role      = "base-ami"
  }
}

build {
  name    = "robotics-base"
  sources = ["source.amazon-ebs.robotics_base"]

  provisioner "shell" { script = "scripts/setup-base.sh" }
  provisioner "shell" { script = "scripts/install-driver.sh" }
  provisioner "shell" { script = "scripts/install-dcv.sh" }
  provisioner "shell" { script = "scripts/install-docker.sh" }
  provisioner "shell" { script = "scripts/install-awscli.sh" }
  provisioner "shell" { script = "scripts/install-ros-gazebo.sh" }
  provisioner "shell" { script = "scripts/install-helper-scripts.sh" }
  provisioner "shell" { script = "scripts/cleanup.sh" }
}
