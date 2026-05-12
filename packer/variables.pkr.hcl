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
  default = "robotics-base"
}

variable "robotics_variant" {
  type    = string
  default = "standard"
}

variable "ssh_username" {
  type    = string
  default = "ubuntu"
}

variable "iam_instance_profile" {
  type    = string
  default = ""
}

variable "nvidia_driver_branch" {
  type    = string
  default = "580"
}

variable "nvidia_driver_version" {
  type    = string
  default = ""
}

variable "grid_driver_version" {
  type    = string
  default = ""
}

variable "dcv_version" {
  type    = string
  default = ""
}

variable "parent_ami_owners" {
  type    = list(string)
  default = ["self"]
}

variable "nvidia_container_toolkit_version" {
  type    = string
  default = ""
}

variable "ros_distro" {
  type    = string
  default = "kilted"
}

variable "isaac_sim_package_url" {
  type    = string
  default = "https://downloads.isaacsim.nvidia.com/isaac-sim-standalone-5.1.0-linux-x86_64.zip"
}
