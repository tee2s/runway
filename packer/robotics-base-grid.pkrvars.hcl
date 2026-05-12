region                 = "us-east-1"
instance_type          = "g6f.large"
root_volume_size       = 120
source_ami_filter_name = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
ubuntu_distro_tag      = "ubuntu2404"
ami_name_prefix        = "robotics-base-grid"
robotics_variant       = "grid"
ssh_username           = "ubuntu"

# Packer Build Instance needs access to s3 Bucket for Nvidia Grid/vGPU Driver Download
iam_instance_profile = "packer-build-instance-profile"

# Leave empty to install the latest Nvidia Grid Driver or set a specific value (for example "19.4") 
# Use this command to see available versions aws s3 ls --recursive s3://ec2-linux-nvidia-drivers/
grid_driver_version = "19.4"

# Leave empty to install the default/latest DCV version defined by the install script.
dcv_version = ""

# Downstream stages select parent AMIs built by this account.
parent_ami_owners = ["self"]

# Leave empty to install the latest version of the NVIDIA Container Toolkit.
nvidia_container_toolkit_version = ""

ros_distro            = "kilted"
isaac_sim_package_url = "https://downloads.isaacsim.nvidia.com/isaac-sim-standalone-5.1.0-linux-x86_64.zip"
