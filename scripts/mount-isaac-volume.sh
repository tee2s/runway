#!/usr/bin/env bash
set -euo pipefail

device="${1:-/dev/sdf}"
mount_point="${2:-/mnt/isaac}"

mkdir -p "$mount_point"
if [ ! -b "$device" ] && [ -b /dev/nvme1n1 ]; then
  device="/dev/nvme1n1"
fi
if [ ! -b "$device" ]; then
  echo "Device not found: $device"
  exit 1
fi
if ! blkid "$device" >/dev/null 2>&1; then
  mkfs -t ext4 "$device"
fi
grep -q "$mount_point" /etc/fstab || echo "$device $mount_point ext4 defaults,nofail 0 2" >> /etc/fstab
mountpoint -q "$mount_point" || mount "$mount_point"
