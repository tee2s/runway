#!/usr/bin/env bash
# Installs Distrobox on Ubuntu using the official package-manager method.
# Distrobox is a fancy wrapper around Docker to easily create containers that are highly integrated with the host.
# This follows the official Distrobox installation and compatibility guidance:
# https://distrobox.it/

set -euo pipefail

export DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"
export NEEDRESTART_MODE="${NEEDRESTART_MODE:-a}"

echo "[install-distrobox] Installing Distrobox..."
sudo apt-get update 
sudo apt-get install -y distrobox

echo "[install-distrobox] Verifying installation..."
distrobox --version

echo "[install-distrobox] Distrobox installation complete."