#!/usr/bin/env bash
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get install -y   build-essential curl wget unzip gnupg lsb-release ca-certificates   software-properties-common jq git xorg xfce4 xfce4-goodies net-tools   python3 python3-pip awscli

if ! dpkg -s amazon-ssm-agent >/dev/null 2>&1; then
  sudo snap install amazon-ssm-agent --classic
fi
sudo systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent.service || true

sudo mkdir -p /workspace/project /mnt/assets /mnt/isaac /opt/robotics/bin
sudo chown -R ubuntu:ubuntu /workspace/project /mnt/assets /mnt/isaac
