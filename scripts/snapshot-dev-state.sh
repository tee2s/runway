#!/usr/bin/env bash
# Run on the instance to safely snapshot the dev-state volume.
# Docker is stopped before snapshotting (its data lives on /work/docker),
# then restarted after the snapshot completes.
# Prints the new snapshot ID on success.
set -euo pipefail

MOUNT_PATH="${1:-/work}"

if ! mountpoint -q "$MOUNT_PATH"; then
  echo "Error: $MOUNT_PATH is not mounted" >&2
  exit 1
fi

DEVICE="$(findmnt -no SOURCE "$MOUNT_PATH")"
VOLUME_ID=""
for link in /dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_vol*; do
  [ -L "$link" ] || continue
  if [ "$(readlink -f "$link")" = "$DEVICE" ]; then
    raw="${link##*_}"
    VOLUME_ID="${raw:0:3}-${raw:3}"
    break
  fi
done

if [ -z "$VOLUME_ID" ]; then
  echo "Error: could not determine volume ID from $DEVICE" >&2
  exit 1
fi

echo "Stopping Docker..."
systemctl stop docker

echo "Syncing filesystem..."
sync

echo "Creating snapshot of $VOLUME_ID..."
SNAPSHOT_ID="$(aws ec2 create-snapshot \
  --volume-id "$VOLUME_ID" \
  --description "dev-state $(date -Is)" \
  --tag-specifications "ResourceType=snapshot,Tags=[{Key=Name,Value=dev-state-snapshot},{Key=Source,Value=$VOLUME_ID}]" \
  --query 'SnapshotId' --output text)"

echo "Waiting for $SNAPSHOT_ID to complete..."
aws ec2 wait snapshot-completed --snapshot-ids "$SNAPSHOT_ID"

echo "Starting Docker..."
systemctl start docker

echo "$SNAPSHOT_ID"
