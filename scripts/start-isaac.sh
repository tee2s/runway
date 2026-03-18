#!/usr/bin/env bash
set -euo pipefail

if [ -x /mnt/isaac/isaac-sim.sh ]; then
  nohup /mnt/isaac/isaac-sim.sh --no-window > /var/log/isaac-sim.log 2>&1 &
  logger -t robotics "Isaac start hook launched /mnt/isaac/isaac-sim.sh"
else
  logger -t robotics "Isaac start hook skipped (missing /mnt/isaac/isaac-sim.sh)"
fi
