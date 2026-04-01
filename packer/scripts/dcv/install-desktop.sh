#!/usr/bin/env bash
# Installs the Ubuntu desktop environment, GDM3 display manager, Xorg, and glxinfo
# utilities required for Amazon DCV Linux console sessions, and ensures GDM3 is the
# default display manager before rebooting.
# This follows the Amazon DCV Linux prerequisites guide for installing a desktop
# environment, setting GDM3 as the default display manager, and installing mesa-utils:
# https://docs.aws.amazon.com/dcv/latest/adminguide/setting-up-installing-linux-prereq.html

set -euo pipefail

export DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"

echo "[install-desktop] Installing desktop environment and display utilities..."
sudo apt-get update 
sudo apt-get install -y \
  ubuntu-desktop \
  gdm3 \
  xorg \
  mesa-utils

echo "[install-desktop] Ensuring nvidia-xconfig is available..."
if command -v nvidia-xconfig >/dev/null 2>&1; then
  echo "[install-desktop] Found nvidia-xconfig at $(command -v nvidia-xconfig)"
elif apt-cache show nvidia-xconfig >/dev/null 2>&1; then
  echo "[install-desktop] Installing nvidia-xconfig from apt..."
  sudo apt-get install -y nvidia-xconfig
else
  echo "[install-desktop] ERROR: nvidia-xconfig command is required but not available."
  echo "[install-desktop]        It was not installed by the NVIDIA driver installer and apt has no nvidia-xconfig package."
  exit 1
fi

echo "[install-desktop] Ensuring GDM3 is the default display manager..."
if [[ ! -f /etc/X11/default-display-manager ]] || ! grep -qx '/usr/sbin/gdm3' /etc/X11/default-display-manager; then
  echo "/usr/sbin/gdm3" | sudo tee /etc/X11/default-display-manager >/dev/null
fi

echo "[install-desktop] Upgrading packages as part of desktop setup..."
sudo apt-get upgrade -y

echo "[install-desktop] Desktop installation complete."
echo "[install-desktop] Reboot required before continuing."