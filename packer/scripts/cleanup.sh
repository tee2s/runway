#!/usr/bin/env bash
set -euxo pipefail

export DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"
export NEEDRESTART_MODE="${NEEDRESTART_MODE:-a}"

echo "[cleanup] Removing apt caches and package indexes..."
sudo apt-get autoremove -y
sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/*

echo "[cleanup] Cleaning temporary directories..."
sudo rm -rf /tmp/* /var/tmp/*

echo "[cleanup] Removing stale crash reports..."
sudo rm -rf /var/crash/*

echo "[cleanup] Clearing common user/system caches..."
sudo rm -rf /root/.cache/*
if id ubuntu >/dev/null 2>&1; then
  sudo rm -rf /home/ubuntu/.cache/*
fi

echo "[cleanup] Truncating logs and removing cloud-init instance state..."
sudo find /var/log -type f -exec truncate -s 0 {} \;
if command -v journalctl >/dev/null 2>&1; then
  sudo journalctl --rotate || true
  sudo journalctl --vacuum-time=1s || true
fi
if command -v cloud-init >/dev/null 2>&1; then
  sudo cloud-init clean --logs --seed || true
fi

echo "[cleanup] Removing machine-specific identifiers/history..."
sudo rm -f /etc/ssh/ssh_host_*
sudo truncate -s 0 /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id
if id ubuntu >/dev/null 2>&1; then
  sudo rm -f /home/ubuntu/.bash_history
fi
sudo rm -f /root/.bash_history

echo "[cleanup] Cleanup complete."
