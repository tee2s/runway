#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"

echo "[setup-base] Updating apt metadata..."
sudo apt-get update 

echo "[setup-base] Upgrading base packages..."
sudo apt-get upgrade -y

echo "[setup-base] Installing common utilities..."
sudo apt-get install -y \
  build-essential \
  ca-certificates \
  curl \
  git \
  gnupg \
  htop \
  jq \
  linux-aws \
  lsb-release \
  net-tools \
  software-properties-common \
  tmux \
  unzip \
  vim \
  wget \
  xz-utils \
  python3 \
  python3-pip \
  python3-venv

echo "[setup-base] Creating standard directories..."
sudo mkdir -p \
  /opt/robotics/bin \
  /workspace/project \
  /mnt/assets \
  /mnt/isaac

echo "[setup-base] Setting ownership and permissions..."
sudo chown -R root:root /opt/robotics /mnt/isaac
sudo chmod 755 /opt/robotics /opt/robotics/bin /mnt/isaac

sudo chown -R ubuntu:ubuntu /workspace/project /mnt/assets
sudo chmod 755 /workspace/project /mnt/assets


echo "[setup-base] Enabling useful kernel modules..."
cat <<'EOF' | sudo tee /etc/modules-load.d/robotics.conf >/dev/null
overlay
br_netfilter
EOF

echo "[setup-base] Base setup complete."