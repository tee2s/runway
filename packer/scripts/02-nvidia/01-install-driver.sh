#!/usr/bin/env bash
# Based on NVIDIA's official Ubuntu driver installation guide:
# - Network Repository Enablement (amd64)
# - Optional version/branch pinning
# - Open Kernel Modules via `nvidia-open`
# https://docs.nvidia.com/datacenter/tesla/driver-installation-guide/ubuntu.html


set -euo pipefail

export DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"

# Optional:
#   NVIDIA_DRIVER_BRANCH="580"
#   NVIDIA_DRIVER_VERSION="580.65.06"
#
# Leave both unset to install the latest available driver from the enabled repo.
# If both are set, VERSION wins.
NVIDIA_DRIVER_BRANCH="${NVIDIA_DRIVER_BRANCH:-}"
NVIDIA_DRIVER_VERSION="${NVIDIA_DRIVER_VERSION:-}"

UBUNTU_DISTRO_TAG="${UBUNTU_DISTRO_TAG:?UBUNTU_DISTRO_TAG must be set}"
ARCH="$(dpkg --print-architecture)"

if [[ "${ARCH}" != "amd64" && "${ARCH}" != "x86_64" ]]; then
  echo "[install-driver] This script currently supports Ubuntu amd64 only."
  exit 1
fi

CUDA_KEYRING_DEB="cuda-keyring_1.1-1_all.deb"
CUDA_KEYRING_URL="https://developer.download.nvidia.com/compute/cuda/repos/${DISTRO}/x86_64/${CUDA_KEYRING_DEB}"

echo "[install-driver] Installing prerequisites..."
sudo apt-get update
sudo apt-get install -y \
  ca-certificates \
  pciutils \
  wget \
  "linux-headers-$(uname -r)"

echo "[install-driver] GPU devices present:"
lspci | grep -i nvidia || true

echo "[install-driver] Enabling NVIDIA network repository..."
wget -q "${CUDA_KEYRING_URL}"
sudo dpkg -i "${CUDA_KEYRING_DEB}"
rm -f "${CUDA_KEYRING_DEB}"
sudo apt-get update

echo "[install-driver] Applying optional NVIDIA driver pinning..."
if [[ -n "${NVIDIA_DRIVER_VERSION}" ]]; then
  PIN_PKG="nvidia-driver-pinning-${NVIDIA_DRIVER_VERSION}"
  echo "[install-driver] Installing version pinning package: ${PIN_PKG}"
  sudo apt-get install -y "${PIN_PKG}"
elif [[ -n "${NVIDIA_DRIVER_BRANCH}" ]]; then
  PIN_PKG="nvidia-driver-pinning-${NVIDIA_DRIVER_BRANCH}"
  echo "[install-driver] Installing branch pinning package: ${PIN_PKG}"
  sudo apt-get install -y "${PIN_PKG}"
else
  echo "[install-driver] No driver pinning requested."
fi

echo "[install-driver] Refreshing apt metadata after pinning..."
sudo apt-get update

echo "[install-driver] Installing NVIDIA driver via nvidia-open..."
sudo apt-get install -y nvidia-open

echo "[install-driver] Driver installation complete."
echo "[install-driver] Reboot required before continuing."