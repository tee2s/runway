#!/usr/bin/env bash
# Validates Amazon DCV post-installation checks for console sessions on Linux by
# confirming the DCV server is running and that the target user can access the X server.
# This follows the Amazon DCV post-installation guideline:
# https://docs.aws.amazon.com/dcv/latest/adminguide/setting-up-installing-linux-checks.html

set -euo pipefail

TARGET_USER="${TARGET_USER:-dcv}"

echo "[validate-dcv] Verifying DCV server is active..."
sudo systemctl is-active --quiet dcvserver || {
  echo "[validate-dcv] ERROR: dcvserver is not active."
  exit 1
}

get_xauth() {
  local pid
  pid="$(pgrep -xn Xorg || true)"
  [[ -n "${pid}" ]] || return 1

  ps -p "${pid}" -o args= \
    | sed -n 's/.*-auth \([^ ]\+\).*/\1/p'
}

wait_for_x_and_access() {
  local user="$1"

  for _ in {1..30}; do
    if pgrep -x Xorg >/dev/null 2>&1 && [[ -S /tmp/.X11-unix/X0 ]]; then
      local xauth
      xauth="$(get_xauth || true)"

      if [[ -n "${xauth}" ]] && sudo test -f "${xauth}"; then
        if sudo DISPLAY=:0 XAUTHORITY="${xauth}" xhost 2>/dev/null \
          | grep -q "SI:localuser:${user}\$"; then
          return 0
        fi
      fi
    fi
    sleep 2
  done

  return 1
}

echo "[validate-dcv] Waiting for X server access for ${TARGET_USER}..."
if ! wait_for_x_and_access "${TARGET_USER}"; then
  echo "[validate-dcv] ${TARGET_USER} cannot access X server yet. Restarting X..."
  sudo systemctl isolate multi-user.target
  sudo systemctl isolate graphical.target

  if ! wait_for_x_and_access "${TARGET_USER}"; then
    echo "[validate-dcv] ERROR: ${TARGET_USER} still cannot access the X server after restart."
    exit 1
  fi
fi

echo "[validate-dcv] DCV validation complete."