#!/usr/bin/env bash
# Configures the Ubuntu display stack for Amazon DCV console sessions by disabling
# Wayland for GDM3, ensuring the system boots to graphical mode, generating an
# NVIDIA Xorg configuration, and verifying that X/OpenGL rendering is available.
# This follows the Amazon DCV Linux prerequisites and OpenGL verification guidance:
# https://docs.aws.amazon.com/dcv/latest/adminguide/setting-up-installing-linux-prereq.html

set -euo pipefail

export DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"

echo "[configure-display] Disabling Wayland..."
sudo mkdir -p /etc/gdm3

if [[ ! -f /etc/gdm3/custom.conf ]]; then
  cat <<'EOF' | sudo tee /etc/gdm3/custom.conf >/dev/null
[daemon]
WaylandEnable=false
EOF
elif grep -q '^[#[:space:]]*WaylandEnable=' /etc/gdm3/custom.conf; then
  sudo sed -i 's/^[#[:space:]]*WaylandEnable=.*/WaylandEnable=false/' /etc/gdm3/custom.conf
else
  if grep -q '^\[daemon\]' /etc/gdm3/custom.conf; then
    sudo awk '
      BEGIN {done=0}
      /^\[daemon\]/ {print; print "WaylandEnable=false"; done=1; next}
      {print}
      END {if (!done) print "[daemon]\nWaylandEnable=false"}
    ' /etc/gdm3/custom.conf | sudo tee /etc/gdm3/custom.conf.tmp >/dev/null
    sudo mv /etc/gdm3/custom.conf.tmp /etc/gdm3/custom.conf
  else
    cat <<'EOF' | sudo tee /etc/gdm3/custom.conf >/dev/null
[daemon]
WaylandEnable=false
EOF
  fi
fi

echo "[configure-display] Setting graphical.target as default..."
sudo systemctl set-default graphical.target

echo "[configure-display] Removing legacy X11 config if present..."
sudo rm -f /etc/X11/XF86Config /etc/X11/XF86Config-*

echo "[configure-display] Generating NVIDIA xorg.conf..."
sudo nvidia-xconfig --preserve-busid --enable-all-gpus

echo "[configure-display] Restarting display manager..."
sudo systemctl restart gdm3

echo "[configure-display] Waiting for Xorg on :0..."
for _ in {1..15}; do
  if pgrep -x Xorg >/dev/null 2>&1 && [[ -S /tmp/.X11-unix/X0 ]]; then
    break
  fi
  sleep 2
done

if ! pgrep -x Xorg >/dev/null 2>&1; then
  echo "[configure-display] ERROR: Xorg is not running."
  ps -ef | grep -E 'Xorg|Xwayland|wayland' | grep -v grep || true
  exit 1
fi

if [[ ! -S /tmp/.X11-unix/X0 ]]; then
  echo "[configure-display] ERROR: X0 socket not found."
  ls -l /tmp/.X11-unix/ || true
  exit 1
fi

echo "[configure-display] Detecting X authority file..."
XAUTH_FILE=""

for _ in {1..15}; do
  X_PID="$(pgrep -xo Xorg || true)"
  if [[ -n "${X_PID}" ]]; then
    XAUTH_FILE="$(ps -p "${X_PID}" -o args= | sed -n 's/.*-auth \([^ ]\+\).*/\1/p' || true)"
    if [[ -n "${XAUTH_FILE}" ]] && sudo test -f "${XAUTH_FILE}"; then
      break
    fi
  fi
  sleep 2
done

if [[ -z "${XAUTH_FILE}" ]] || ! sudo test -f "${XAUTH_FILE}"; then
  echo "[configure-display] ERROR: Could not determine usable XAUTHORITY file."
  ps -ef | grep -E 'Xorg|Xwayland|wayland' | grep -v grep || true
  exit 1
fi

echo "[configure-display] Using XAUTHORITY=${XAUTH_FILE}"

echo "[configure-display] Verifying NVIDIA OpenGL hardware rendering..."
if sudo DISPLAY=:0 XAUTHORITY="${XAUTH_FILE}" glxinfo | grep -i 'opengl.*version'; then
  echo "[configure-display] OpenGL hardware rendering check passed."
else
  echo "[configure-display] ERROR: OpenGL hardware rendering check failed."
  exit 1
fi

echo "[configure-display] Display configuration complete."