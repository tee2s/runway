region                 = "us-east-1"
instance_type          = "g6f.large"
root_volume_size       = 120
source_ami_filter_name = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
ubuntu_distro_tag      = "ubuntu2404"
ami_name_prefix        = "robotics-base-grid"
ssh_username           = "ubuntu"

# Leave empty to install the latest Nvidia Grid Driver or set a specific value (for example "19.4") 
# Use this command to see available versions aws s3 ls --recursive s3://ec2-linux-nvidia-drivers/
grid_driver_version = ""

# Leave empty to install the default/latest DCV version defined by the install script.
dcv_version = ""

# Leave empty to install the latest version of the nvidia container toolkit
nvidia_container_toolkit_version = ""

ros_distro = "kilted"
