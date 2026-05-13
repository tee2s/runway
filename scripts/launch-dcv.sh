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

HOST="$(awk -F= '/^host=/{gsub(/[[:space:]]/, "", $2); print $2}' "$BASE_DCV_FILE")"
PORT="$(awk -F= '/^port=/{gsub(/[[:space:]]/, "", $2); print $2}' "$BASE_DCV_FILE")"
PORT="${PORT:-8443}"

MAX_WAIT="${DCV_WAIT_TIMEOUT:-300}"

_poll_port() {
  while ! nc -z -w2 "$HOST" "$PORT" 2>/dev/null; do
    sleep 3
  done
}

FRAMES=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
NFRAMES=${#FRAMES[@]}

_poll_port &
POLL_PID=$!
trap 'kill "$POLL_PID" 2>/dev/null' EXIT

i=0
start=$SECONDS
while kill -0 "$POLL_PID" 2>/dev/null; do
  printf "\r  ${FRAMES[$((i % NFRAMES))]} Waiting for instance boot up..."
  sleep 0.08
  i=$((i + 1))
  if [[ $((SECONDS - start)) -ge $MAX_WAIT ]]; then
    kill "$POLL_PID" 2>/dev/null
    wait "$POLL_PID" 2>/dev/null
    printf "\r  \033[31m✗\033[0m Timed out after ${MAX_WAIT}s waiting for instance.\n" >&2
    exit 1
  fi
done
wait "$POLL_PID"
trap - EXIT
printf "\r  \033[32m✓\033[0m Instance ready.                          \n"

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
