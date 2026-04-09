#!/usr/bin/env bash
# Installs NVIDIA Isaac Sim workstation build on Linux.
# This follows the official workstation installation flow:
# https://docs.isaacsim.omniverse.nvidia.com/6.0.0/installation/install_workstation.html

set -euo pipefail

export DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"
export NEEDRESTART_MODE="${NEEDRESTART_MODE:-a}"

ISAAC_SIM_INSTALL_DIR="/isaacsim"
ISAAC_SIM_PACKAGE_URL="${ISAAC_SIM_PACKAGE_URL:-https://downloads.isaacsim.nvidia.com/isaac-sim-standalone-5.10-linux-x86_64.zip}"
ISAAC_SIM_PACKAGE_FILE="$(basename "${ISAAC_SIM_PACKAGE_URL}")"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

echo "[install-isaac-sim] Installing prerequisites..."
sudo apt-get update -y
sudo apt-get install -y curl unzip

echo "[install-isaac-sim] Downloading package from ${ISAAC_SIM_PACKAGE_URL}..."
curl -fL --retry 5 --retry-delay 5 --retry-all-errors "${ISAAC_SIM_PACKAGE_URL}" -o "${TMP_DIR}/${ISAAC_SIM_PACKAGE_FILE}"

echo "[install-isaac-sim] Preparing install directory ${ISAAC_SIM_INSTALL_DIR}..."
sudo mkdir -p "${ISAAC_SIM_INSTALL_DIR}"
# Keep installs deterministic across image rebuilds.
sudo rm -rf "${ISAAC_SIM_INSTALL_DIR:?}/"*

echo "[install-isaac-sim] Extracting archive..."
sudo unzip -q "${TMP_DIR}/${ISAAC_SIM_PACKAGE_FILE}" -d "${ISAAC_SIM_INSTALL_DIR}"

echo "[install-isaac-sim] Running post-install script..."
sudo chown -R ubuntu:ubuntu "${ISAAC_SIM_INSTALL_DIR}"
sudo -u ubuntu bash -lc "cd \"${ISAAC_SIM_INSTALL_DIR}\" && ./post_install.sh"

echo "[install-isaac-sim] Isaac Sim installation complete."
