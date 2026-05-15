#!/usr/bin/env bash
# Run on the instance to safely snapshot the dev-state volume.
# Stops Docker, creates a snapshot, updates the SSM parameter with the new
# snapshot ID, deletes the previous snapshot, then restarts Docker.
# Prints the new snapshot ID on success.
set -euo pipefail

. /etc/robotics/dev-state.conf

MOUNT_PATH="${1:-$DEV_STATE_MOUNT_PATH}"
SNAPSHOT_PARAM="$DEV_STATE_SNAPSHOT_ID_PARAM"

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

OLD_SNAPSHOT_ID="$(aws ssm get-parameter --name "$SNAPSHOT_PARAM" --query 'Parameter.Value' --output text 2>/dev/null || true)"

echo "Stopping Docker..."
systemctl stop docker.socket docker

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

echo "Updating $SNAPSHOT_PARAM -> $SNAPSHOT_ID..."
aws ssm put-parameter --name "$SNAPSHOT_PARAM" --value "$SNAPSHOT_ID" --type String --overwrite

if [ -n "$OLD_SNAPSHOT_ID" ] && [ "$OLD_SNAPSHOT_ID" != "$SNAPSHOT_ID" ]; then
  echo "Deleting old snapshot $OLD_SNAPSHOT_ID..."
  aws ec2 delete-snapshot --snapshot-id "$OLD_SNAPSHOT_ID" \
    || echo "Warning: could not delete $OLD_SNAPSHOT_ID"
fi

echo "Starting Docker..."
systemctl start docker

echo "$SNAPSHOT_ID"
