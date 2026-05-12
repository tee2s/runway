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

"$DCV_VIEWER" "$TMP_DCV_FILE" &
sleep 2
rm -f "$TMP_DCV_FILE"
