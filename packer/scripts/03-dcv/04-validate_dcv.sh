#!/usr/bin/env bash
# Validates Amazon DCV post-installation checks for console sessions on Linux by
# confirming the DCV server is running and that the `dcv` user can access the X server.
# This follows the Amazon DCV post-installation guideline:
# https://docs.aws.amazon.com/dcv/latest/adminguide/setting-up-installing-linux-checks.html

set -euo pipefail

echo "[validate-dcv] Verifying DCV server is active..."
sudo systemctl is-active --quiet dcvserver || {
  echo "[validate-dcv] ERROR: dcvserver is not active."
  exit 1
}

echo "[validate-dcv] Detecting X authority file..."
XAUTH_FILE="$(ps aux | grep 'X.*-auth' | grep -v Xdcv | grep -v grep | sed -n 's/.*-auth \([^ ]\+\).*/\1/p' | head -n1)"

if [[ -z "${XAUTH_FILE}" ]]; then
  echo "[validate-dcv] ERROR: Could not determine XAUTHORITY file."
  exit 1
fi

echo "[validate-dcv] Verifying dcv user can access the X server..."
if sudo DISPLAY=:0 XAUTHORITY="${XAUTH_FILE}" xhost | grep -q 'SI:localuser:dcv$'; then
  echo "[validate-dcv] dcv user can access the X server."
else
  echo "[validate-dcv] ERROR: dcv user cannot access the X server."
  exit 1
fi

echo "[validate-dcv] DCV validation complete."