locals {
  simulation_timestamp    = regex_replace(timestamp(), "[- TZ:]", "")
  simulation_stage        = "simulation"
  simulation_parent_stage = "containers"
  simulation_variant      = var.robotics_variant
  simulation_ami_name     = format("%s-%s-%s", var.ami_name_prefix, local.simulation_stage, local.simulation_timestamp)
}

source "amazon-ebs" "robotics_simulation" {
  region        = var.region
  instance_type = var.instance_type
  ssh_username  = var.ssh_username

  source_ami_filter {
    filters = {
      name                  = format("%s-%s-*", var.ami_name_prefix, local.simulation_parent_stage)
      architecture          = "x86_64"
      root-device-type      = "ebs"
      virtualization-type   = "hvm"
      "tag:RoboticsStage"   = local.simulation_parent_stage
      "tag:RoboticsVariant" = local.simulation_variant
      "tag:BuiltBy"         = "packer"
    }
    most_recent = true
    owners      = var.parent_ami_owners
  }

  ami_name        = local.simulation_ami_name
  ami_description = "Robotics simulation AMI with ROS, Gazebo, and Isaac Sim"

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
  }

  tags = {
    Name                = local.simulation_ami_name
    Role                = var.ami_name_prefix
    BuiltBy             = "packer"
    RoboticsStage       = local.simulation_stage
    RoboticsVariant     = local.simulation_variant
    ParentRoboticsStage = local.simulation_parent_stage
    ParentAmiFilter     = format("%s-%s-*", var.ami_name_prefix, local.simulation_parent_stage)
  }

  run_tags = {
    Name = format("packer-build-%s-%s", var.ami_name_prefix, local.simulation_stage)
  }
}

build {
  name    = "robotics-simulation"
  sources = ["source.amazon-ebs.robotics_simulation"]

  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive",
      "ROS_DISTRO=${var.ros_distro}"
    ]
    script = "packer/scripts/install-ros-gazebo.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive",
      "ISAAC_SIM_PACKAGE_URL=${var.isaac_sim_package_url}"
    ]
    script = "packer/scripts/install-isaac-sim.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
    script = "packer/scripts/cleanup.sh"
  }
}
