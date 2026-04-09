#!/usr/bin/env bash
# Installs ROS 2, rosdep/dev tools, and the default Gazebo pairing for the selected ROS distro on Ubuntu.
# This follows the official ROS 2 Ubuntu installation guide and the official Gazebo + ROS installation guide:
# https://docs.ros.org/en/kilted/Installation/Ubuntu-Install-Debs.html
# https://gazebosim.org/docs/latest/ros_installation/

set -euxo pipefail

echo "[install-ros] Starting ROS and Gazebo installation..."
export DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"
export NEEDRESTART_MODE="${NEEDRESTART_MODE:-a}"
export ROS_DISTRO="${ROS_DISTRO:?ROS_DISTRO must be set}"

UBUNTU_CODENAME="$(
  . /etc/os-release
  echo "${UBUNTU_CODENAME:-${VERSION_CODENAME}}"
)"

echo "[install-ros] Configuring locale and Ubuntu repositories..."
sudo apt-get update
sudo apt-get install -y locales
sudo locale-gen en_US en_US.UTF-8
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
export LANG=en_US.UTF-8

sudo apt-get install -y software-properties-common
sudo add-apt-repository -y universe

echo "[install-ros] Installing curl and setting up the ROS apt source..."
sudo apt-get update
sudo apt-get install -y curl

ROS_APT_SOURCE_VERSION="$(
  curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest \
    | grep -F '"tag_name"' \
    | awk -F'"' '{print $4}'
)"

curl -L \
  -o /tmp/ros2-apt-source.deb \
  "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.${UBUNTU_CODENAME}_all.deb"

sudo dpkg -i /tmp/ros2-apt-source.deb
rm -f /tmp/ros2-apt-source.deb

echo "[install-ros] Updating system packages and installing ROS ${ROS_DISTRO}..."
sudo apt-get update
sudo apt-get upgrade -y

sudo apt-get install -y \
  "ros-${ROS_DISTRO}-desktop" \
  ros-dev-tools

echo "[install-ros] Initializing rosdep..."
# Initialize and refresh rosdep metadata
if [ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]; then
  sudo rosdep init
fi
rosdep update || true

echo "[install-ros] Configuring ROS environment setup for future shells..."
# Auto-source ROS for new shell sessions
sudo tee /etc/profile.d/ros2.sh >/dev/null <<EOF
source /opt/ros/${ROS_DISTRO}/setup.bash
EOF
sudo chmod 644 /etc/profile.d/ros2.sh

echo "[install-gazebo] Installing ros_gz and the default Gazebo pairing for ROS ${ROS_DISTRO}..."
sudo apt-get update -y
sudo apt-get install -y ros-${ROS_DISTRO}-ros-gz

echo "[install-ros] ROS and Gazebo installation completed successfully."