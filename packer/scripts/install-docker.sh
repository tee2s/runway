#!/usr/bin/env bash
# Installs Docker Engine and the NVIDIA Container Toolkit on Ubuntu for GPU-enabled containers.
# This follows the official Docker Engine on Ubuntu installation guide and the official
# NVIDIA Container Toolkit installation/configuration guide for Docker:
# https://docs.docker.com/engine/install/ubuntu/
# https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html

set -euo pipefail

export DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"
export NEEDRESTART_MODE="${NEEDRESTART_MODE:-a}"

echo "[install-docker] Removing old Docker-related packages if present..."
sudo apt-get remove -y \
  docker.io \
  docker-compose \
  docker-compose-v2 \
  docker-doc \
  podman-docker \
  containerd \
  runc || true

echo "[install-docker] Installing prerequisites..."
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg

echo "[install-docker] Adding Docker apt repository..."
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

echo "[install-docker] Installing Docker Engine..."
sudo apt-get update -y
sudo apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

echo "[install-docker] Enabling Docker..."
sudo systemctl enable docker
sudo systemctl start docker

if ! getent group docker >/dev/null; then
  echo "[install-docker] Creating docker group..."
  sudo groupadd docker
fi

if id ubuntu >/dev/null 2>&1; then
  echo "[install-docker] Adding ubuntu user to docker group..."
  sudo usermod -aG docker ubuntu
fi

echo "[install-docker] Verifying Docker installation with hello-world..."
sudo docker run --rm hello-world
sudo docker image rm hello-world || true

echo "[install-docker] Installing NVIDIA Container Toolkit..."
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null

echo "[install-docker] Installing NVIDIA Container Toolkit..."
sudo apt-get update -y

if [[ -n "${NVIDIA_CONTAINER_TOOLKIT_VERSION:-}" ]]; then
  echo "[install-docker] Using pinned NVIDIA Container Toolkit version: ${NVIDIA_CONTAINER_TOOLKIT_VERSION}"
  sudo apt-get install -y \
    nvidia-container-toolkit="${NVIDIA_CONTAINER_TOOLKIT_VERSION}" \
    nvidia-container-toolkit-base="${NVIDIA_CONTAINER_TOOLKIT_VERSION}" \
    libnvidia-container-tools="${NVIDIA_CONTAINER_TOOLKIT_VERSION}" \
    libnvidia-container1="${NVIDIA_CONTAINER_TOOLKIT_VERSION}"
else
  echo "[install-docker] Using latest available NVIDIA Container Toolkit version from the repo..."
  sudo apt-get install -y nvidia-container-toolkit
fi

echo "[install-docker] Configuring Docker runtime for NVIDIA..."
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

echo "[install-docker] Docker + NVIDIA Container Toolkit install complete."