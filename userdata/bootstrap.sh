#!/usr/bin/env bash
set -euo pipefail

MODE="__MODE__"
PROJECT_PREFIX_PARAM="__PROJECT_PREFIX_PARAM__"
WORKSPACE_PARAM="__WORKSPACE_PATH_PARAM__"
BUCKET_PARAM="__BUCKET_PARAM__"

LOG_FILE="/var/log/robotics-bootstrap.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "[$(date -Is)] bootstrap start mode=${MODE}"

retry() {
  local cmd="$1"
  local n=0
  local max="${2:-20}"
  local sleep_sec="${3:-10}"
  until eval "$cmd"; do
    n=$((n+1))
    if [ "$n" -ge "$max" ]; then
      echo "Command failed after ${max} retries: $cmd"
      return 1
    fi
    sleep "$sleep_sec"
  done
}

get_param() {
  local name="$1"
  aws ssm get-parameter --name "$name" --query 'Parameter.Value' --output text
}

mkdir -p /workspace/project /mnt/assets /mnt/isaac

BUCKET="$(get_param "$BUCKET_PARAM")"
PROJECT_PREFIX="$(get_param "$PROJECT_PREFIX_PARAM")"
WORKSPACE_PATH="$(get_param "$WORKSPACE_PARAM")"

if [ -x /opt/robotics/bin/s3-sync-project-down.sh ]; then
  retry "bash -lc '/opt/robotics/bin/s3-sync-project-down.sh ${BUCKET} ${PROJECT_PREFIX} ${WORKSPACE_PATH}'" 12 10
fi

if [ "$MODE" = "isaac" ]; then
  if [ -x /opt/robotics/bin/mount-isaac-volume.sh ]; then
    retry "bash -lc '/opt/robotics/bin/mount-isaac-volume.sh /dev/sdf /mnt/isaac'" 30 10 || true
  fi
  if [ -x /opt/robotics/bin/start-isaac.sh ]; then
    bash -lc '/opt/robotics/bin/start-isaac.sh' || true
  fi
else
  if [ -x /opt/robotics/bin/start-gazebo.sh ]; then
    bash -lc '/opt/robotics/bin/start-gazebo.sh' || true
  fi
fi

echo "[$(date -Is)] bootstrap done"
