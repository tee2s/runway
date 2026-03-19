region                 = "us-east-1"
instance_type          = "g4dn.xlarge"
root_volume_size       = 120
source_ami_filter_name = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
ami_name_prefix        = "robotics-base"
ssh_username           = "ubuntu"
ros_distro             = "kilted"