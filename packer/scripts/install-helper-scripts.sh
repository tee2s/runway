#!/usr/bin/env bash
set -euxo pipefail

sudo mkdir -p /opt/robotics/bin

sudo tee /opt/robotics/bin/mount-isaac-volume.sh >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

device="${1:-/dev/sdf}"
mount_point="${2:-/mnt/isaac}"

mkdir -p "$mount_point"
if [ ! -b "$device" ] && [ -b /dev/nvme1n1 ]; then
  device="/dev/nvme1n1"
fi
if [ ! -b "$device" ]; then
  echo "Device $device not found yet"
  exit 1
fi
if ! blkid "$device" >/dev/null 2>&1; then
  mkfs -t ext4 "$device"
fi
grep -q "$mount_point" /etc/fstab || echo "$device $mount_point ext4 defaults,nofail 0 2" >> /etc/fstab
mountpoint -q "$mount_point" || mount "$mount_point"
EOF

sudo tee /opt/robotics/bin/s3-sync-project-down.sh >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

bucket="${1:?bucket required}"
prefix="${2:-project/}"
workspace="${3:-/workspace/project}"

mkdir -p "$workspace"
aws s3 sync "s3://${bucket}/${prefix}" "$workspace" --delete
EOF

sudo tee /opt/robotics/bin/s3-sync-project-up.sh >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

bucket="${1:?bucket required}"
prefix="${2:-project/}"
workspace="${3:-/workspace/project}"

mkdir -p "$workspace"
aws s3 sync "$workspace" "s3://${bucket}/${prefix}" --delete
EOF

sudo tee /opt/robotics/bin/start-gazebo.sh >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
source /opt/ros/humble/setup.bash || true
logger -t robotics "Gazebo start hook executed"
EOF

sudo tee /opt/robotics/bin/start-isaac.sh >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ -x /mnt/isaac/isaac-sim.sh ]; then
  nohup /mnt/isaac/isaac-sim.sh --no-window > /var/log/isaac-sim.log 2>&1 &
  logger -t robotics "Isaac start hook launched /mnt/isaac/isaac-sim.sh"
else
  logger -t robotics "Isaac start hook skipped (missing /mnt/isaac/isaac-sim.sh)"
fi
EOF

sudo chmod +x /opt/robotics/bin/*.sh
