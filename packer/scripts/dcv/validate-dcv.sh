#!/usr/bin/env bash
# Validates Amazon DCV post-installation checks for console sessions on Linux by
# confirming the DCV server is running and that the `dcv` user can access the X server.
# This follows the Amazon DCV post-installation guideline:
# https://docs.aws.amazon.com/dcv/latest/adminguide/setting-up-installing-linux-checks.html

#!/usr/bin/env bash
set -euo pipefail

echo "[validate-dcv] Verifying DCV server is active..."
sudo systemctl is-active --quiet dcvserver || {
  echo "[validate-dcv] ERROR: dcvserver is not active."
  exit 1
}

get_xauth() {
  ps -p "$(pgrep -xo Xorg || true)" -o args= \
    | sed -n 's/.*-auth \([^ ]\+\).*/\1/p'
}

wait_for_x() {
  for _ in {1..20}; do
    if pgrep -x Xorg >/dev/null 2>&1 && [[ -S /tmp/.X11-unix/X0 ]]; then
      return 0
    fi
    sleep 2
  done
  return 1
}

dcv_has_x_access() {
  local xauth="$1"
  sudo DISPLAY=:0 XAUTHORITY="${xauth}" xhost | grep -q 'SI:localuser:dcv$'
}

echo "[validate-dcv] Waiting for X server..."
wait_for_x || {
  echo "[validate-dcv] ERROR: X server is not available."
  exit 1
}

XAUTH_FILE="$(get_xauth)"
if [[ -z "${XAUTH_FILE}" ]] || ! sudo test -f "${XAUTH_FILE}"; then
  echo "[validate-dcv] ERROR: Could not determine usable XAUTHORITY file."
  exit 1
fi

echo "[validate-dcv] Checking X server access for dcv user..."
if ! dcv_has_x_access "${XAUTH_FILE}"; then
  echo "[validate-dcv] dcv user cannot access X server. Restarting X..."
  sudo systemctl isolate multi-user.target
  sudo systemctl isolate graphical.target

  wait_for_x || {
    echo "[validate-dcv] ERROR: X server did not come back after restart."
    exit 1
  }

  XAUTH_FILE="$(get_xauth)"
  if [[ -z "${XAUTH_FILE}" ]] || ! sudo test -f "${XAUTH_FILE}"; then
    echo "[validate-dcv] ERROR: Could not determine usable XAUTHORITY file after restart."
    exit 1
  fi

  dcv_has_x_access "${XAUTH_FILE}" || {
    echo "[validate-dcv] ERROR: dcv user still cannot access the X server after restart."
    exit 1
  }
fi

echo "[validate-dcv] DCV validation complete."