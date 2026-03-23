region                 = "us-east-1"
instance_type          = "g4dn.xlarge"
root_volume_size       = 120
source_ami_filter_name = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
ubuntu_distro_tag      = "ubuntu2404"
ami_name_prefix        = "robotics-base"
ssh_username           = "ubuntu"

# Optional NVIDIA driver selection.
# If both are left empty, the installer will use the latest driver available from the enabled NVIDIA repo,
# which may not always be the desired production branch and could resolve to a newer/pre-release package.
# If both are set, nvidia_driver_version takes precedence over nvidia_driver_branch.
# It is recommended to explicitly choose a tested production branch/version:
# https://www.nvidia.com/en-us/drivers/
nvidia_driver_branch  = "580"
nvidia_driver_version = "" 

# Leave empty to install the default/latest DCV version defined by the install script.
dcv_version = ""

# Leave empty to install the latest version of the nvidia container toolkit
nvidia_container_toolkit_version = ""

ros_distro = "kilted"
