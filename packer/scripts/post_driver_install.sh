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
  nvidia-smi
else
  echo "[post-driver] ERROR: nvidia-smi not found."
  exit 1
fi

echo "[post-driver] NVIDIA post-installation actions completed successfully."