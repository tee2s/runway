#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DCV_VIEWER="${DCV_VIEWER:-/Applications/DCV Viewer.app/Contents/MacOS/dcvviewer}"
PROJECT_NAME="${PROJECT_NAME:-robotics-dev}"
BASE_DCV_FILE="${BASE_DCV_FILE:-$HOME/.config/dcv/${PROJECT_NAME}.dcv}"

SERVICE_NAME="${KEYCHAIN_SERVICE:-dcv-robotics-dev}"
ACCOUNT_NAME="${KEYCHAIN_ACCOUNT:-ubuntu}"

PASSWORD="$(security find-generic-password \
  -a "$ACCOUNT_NAME" \
  -s "$SERVICE_NAME" \
  -w)"

if [[ ! -f "$BASE_DCV_FILE" ]]; then
  printf "  \033[31m✗\033[0m No instance running — launch one first.\n" >&2
  exit 1
fi

HOST="$(awk -F= '/^host=/{gsub(/[[:space:]]/, "", $2); print $2}' "$BASE_DCV_FILE")"
PORT="$(awk -F= '/^port=/{gsub(/[[:space:]]/, "", $2); print $2}' "$BASE_DCV_FILE")"
PORT="${PORT:-8443}"

MAX_WAIT="${DCV_WAIT_TIMEOUT:-300}"

_poll_dcv() {
  while ! curl -skf --connect-timeout 2 --max-time 3 "https://$HOST:$PORT/version" >/dev/null 2>&1; do
    sleep 3
  done
}

_poll_desktop() {
  while ! ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new \
      "$PROJECT_NAME" '
    systemctl is-active --quiet dcvserver &&
    test -S /tmp/.X11-unix/X0 &&
    pgrep -u ubuntu -x gnome-shell >/dev/null &&
    pgrep -u ubuntu -x dcvagent >/dev/null &&
    sudo test -f /var/log/dcv/agent.ubuntu.console.log &&
    sudo grep -q "Session '"'"'console'"'"' constructed" /var/log/dcv/agent.ubuntu.console.log
  ' 2>/dev/null; do
    sleep 2
  done
}

_spinner_until() {
  local pid=$1 label=$2
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${FRAMES[$((i % NFRAMES))]} %s" "$label"
    sleep 0.08
    i=$((i + 1))
    if [[ $((SECONDS - start)) -ge $MAX_WAIT ]]; then
      kill "$pid" 2>/dev/null
      wait "$pid" 2>/dev/null
      printf "\r  \033[31m✗\033[0m Timed out after ${MAX_WAIT}s.\n" >&2
      exit 1
    fi
  done
  wait "$pid"
}

FRAMES=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
NFRAMES=${#FRAMES[@]}
i=0
start=$SECONDS

_poll_dcv &
POLL_PID=$!
trap 'kill "$POLL_PID" 2>/dev/null' EXIT
_spinner_until "$POLL_PID" "Waiting for instance..."
trap - EXIT

_poll_desktop &
POLL_PID=$!
trap 'kill "$POLL_PID" 2>/dev/null' EXIT
_spinner_until "$POLL_PID" "Waiting for desktop..."
trap - EXIT

printf "\r  \033[32m✓\033[0m Desktop ready.                           \n"

TMP_DCV_FILE="$(mktemp /tmp/robotics-dev.XXXXXX.dcv)"
chmod 600 "$TMP_DCV_FILE"

awk -v password="$PASSWORD" '
  /^\[connect\]/ {
    print
    in_connect=1
    next
  }

  /^\[/ && in_connect {
    print "password=" password
    in_connect=0
  }

  { print }

  END {
    if (in_connect) {
      print "password=" password
    }
  }
' "$BASE_DCV_FILE" > "$TMP_DCV_FILE"

"$DCV_VIEWER" "$TMP_DCV_FILE" >/dev/null 2>&1 &
( sleep 2; rm -f "$TMP_DCV_FILE" ) &
