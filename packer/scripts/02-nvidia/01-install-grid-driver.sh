#!/usr/bin/env bash
# Based on AWS EC2 guide for NVIDIA GRID drivers on Ubuntu:
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/nvidia-GRID-driver.html
#
# Notes:
# - This script intentionally does NOT disable GSP.
# - Expected to run on an EC2 instance profile with S3 read access.

set -euo pipefail

export DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"

if [[ ! -f /etc/os-release ]]; then
  echo "[install-grid] ERROR: /etc/os-release not found."
  exit 1
fi

# shellcheck disable=SC1091
source /etc/os-release
if [[ "${ID:-}" != "ubuntu" ]]; then
  echo "[install-grid] ERROR: This script currently supports Ubuntu only."
  exit 1
fi

echo "[install-grid] Installing prerequisites..."
sudo apt-get update -y
sudo apt-get install -y \
  awscli \
  gcc \
  make \
  linux-headers-$(uname -r) \
  linux-modules-extra-$(uname -r)

echo "[install-grid] Blacklisting nouveau as recommended by AWS guide..."
cat <<'EOF' | sudo tee --append /etc/modprobe.d/blacklist.conf >/dev/null
blacklist vga16fb
blacklist nouveau
blacklist rivafb
blacklist nvidiafb
blacklist rivatv
EOF

if grep -q '^GRUB_CMDLINE_LINUX=' /etc/default/grub; then
  if ! grep -q 'GRUB_CMDLINE_LINUX=.*rdblacklist=nouveau' /etc/default/grub; then
    sudo sed -i 's/^GRUB_CMDLINE_LINUX="\([^"]*\)"/GRUB_CMDLINE_LINUX="\1 rdblacklist=nouveau"/' /etc/default/grub
  fi
else
  echo 'GRUB_CMDLINE_LINUX="rdblacklist=nouveau"' | sudo tee --append /etc/default/grub >/dev/null
fi
sudo update-grub

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

echo "[install-grid] Downloading AWS-provided GRID drivers from S3..."
aws s3 cp --recursive s3://ec2-linux-nvidia-drivers/latest/ "${TMP_DIR}/"

shopt -s nullglob
GRID_RUN_FILES=("${TMP_DIR}"/NVIDIA-Linux-x86_64*.run)
shopt -u nullglob

if [[ "${#GRID_RUN_FILES[@]}" -eq 0 ]]; then
  echo "[install-grid] ERROR: No GRID installer (*.run) found in downloaded artifacts."
  exit 1
fi

IFS=$'\n' GRID_RUN_FILES_SORTED=($(printf '%s\n' "${GRID_RUN_FILES[@]}" | sort -V))
unset IFS
GRID_RUN_FILE="${GRID_RUN_FILES_SORTED[-1]}"

echo "[install-grid] Running installer: $(basename "${GRID_RUN_FILE}")"
chmod +x "${GRID_RUN_FILE}"
sudo /bin/sh "${GRID_RUN_FILE}" --silent

echo "[install-grid] Installation complete. Reboot required."
