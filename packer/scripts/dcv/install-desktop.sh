#!/usr/bin/env bash
# Installs the Ubuntu desktop environment, GDM3 display manager, Xorg, and glxinfo
# utilities required for Amazon DCV Linux console sessions, and ensures GDM3 is the
# default display manager before rebooting.
# This follows the Amazon DCV Linux prerequisites guide for installing a desktop
# environment, setting GDM3 as the default display manager, and installing mesa-utils:
# https://docs.aws.amazon.com/dcv/latest/adminguide/setting-up-installing-linux-prereq.html

set -euo pipefail

export DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"
export NEEDRESTART_MODE="${NEEDRESTART_MODE:-a}"

echo "[install-desktop] Installing desktop environment and display utilities..."
sudo apt-get update 
sudo apt-get install -y \
  ubuntu-desktop \
  gdm3 \
  xorg \
  mesa-utils

echo "[install-desktop] Disabling Ubuntu/GNOME first-run setup..."

# Remove first-run / welcome packages if they are installed.
# - gnome-initial-setup: GNOME first-login wizard
# - ubuntu-desktop-bootstrap: Ubuntu welcome/bootstrap flow
# - ubuntu-report: Ubuntu telemetry/reporting prompt
# - fwupd: firmware update daemon, not useful on EC2 and can crash during desktop login
sudo apt-get remove -y \
  gnome-initial-setup \
  ubuntu-desktop-bootstrap \
  ubuntu-report \
  fwupd || true
sudo apt-get purge -y fwupd || true

# Remove system-wide GUI autostart entries that can launch welcome/setup apps
# when a GNOME/DCV desktop session starts.
sudo rm -f \
  /etc/xdg/autostart/gnome-initial-setup-first-login.desktop \
  /etc/xdg/autostart/gnome-initial-setup.desktop \
  /etc/xdg/autostart/ubuntu-welcome.desktop \
  /etc/xdg/autostart/ubuntu-desktop-bootstrap.desktop

# Mask the GNOME initial setup systemd service if it exists.
# Masking is stronger than disabling and prevents accidental startup.
sudo systemctl mask gnome-initial-setup.service 2>/dev/null || true

# Create GNOME config directories for the default ubuntu user
# and for future users created from /etc/skel.
sudo mkdir -p \
  /home/ubuntu/.config \
  /etc/skel/.config

# Mark GNOME initial setup as already completed for the ubuntu user.
sudo touch /home/ubuntu/.config/gnome-initial-setup-done

# Mark GNOME initial setup as completed for future users copied from /etc/skel.
sudo touch /etc/skel/.config/gnome-initial-setup-done

# Ensure the ubuntu user owns their config directory, since the files above
# were created with sudo and might otherwise be root-owned.
sudo chown -R ubuntu:ubuntu /home/ubuntu/.config

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
