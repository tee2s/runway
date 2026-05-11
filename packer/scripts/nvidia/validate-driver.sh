#!/usr/bin/env bash
# Based on NVIDIA's official post-installation actions guide:
# - Restart/check NVIDIA persistence daemon if present
# - Verify loaded NVIDIA driver version after reboot
# https://docs.nvidia.com/datacenter/tesla/driver-installation-guide/post-installation-actions.html#post-installation-actions

set -euo pipefail

echo "[post-driver] Running NVIDIA post-installation actions..."

echo "[post-driver] Restarting NVIDIA persistence daemon if available..."
if systemctl list-unit-files | grep -q '^nvidia-persistenced.service'; then
  sudo systemctl restart nvidia-persistenced
  sudo systemctl --no-pager --full status nvidia-persistenced || true
else
  echo "[post-driver] nvidia-persistenced service not present; skipping."
fi

echo "[post-driver] Checking for NVIDIA PCI device..."
if ! lspci | grep -qi nvidia; then
  echo "[post-driver] ERROR: No NVIDIA PCI device found on this builder instance."
  echo "[post-driver] Driver may be installed, but nvidia-smi cannot validate runtime without a GPU."
  lspci || true
  exit 1
fi
lspci | grep -i nvidia

echo "[post-driver] Verifying that the NVIDIA driver version is loaded..."
if [[ -r /proc/driver/nvidia/version ]]; then
  cat /proc/driver/nvidia/version
else
  echo "[post-driver] ERROR: /proc/driver/nvidia/version not found."
  echo "[post-driver] The NVIDIA kernel driver may not be loaded."
  exit 1
fi

echo "[post-driver] Running nvidia-smi for runtime validation..."
if command -v nvidia-smi >/dev/null 2>&1; then
  if ! nvidia-smi; then
    echo "[post-driver] ERROR: nvidia-smi failed to detect a usable GPU."
    echo "[post-driver] NVIDIA module state:"
    lsmod | grep -i nvidia || true
    echo "[post-driver] NVIDIA procfs state:"
    ls -la /proc/driver/nvidia || true
    ls -la /proc/driver/nvidia/gpus || true
    echo "[post-driver] Recent NVIDIA kernel messages:"
    sudo dmesg | grep -iE 'nvidia|nvrm' | tail -100 || true
    exit 1
  fi
else
  echo "[post-driver] ERROR: nvidia-smi not found."
  exit 1
fi

echo "[post-driver] NVIDIA post-installation actions completed successfully."