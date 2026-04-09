#!/usr/bin/env bash
# Ensures the ubuntu password hash SecureString exists in SSM Parameter Store.
# If missing, prompt interactively for a password, hash with SHA-512, and store it.

set -euo pipefail

PARAM_NAME="${PARAM_NAME:?PARAM_NAME must be set}"
REGION="${REGION:?REGION must be set}"

if aws ssm get-parameter --name "$PARAM_NAME" --with-decryption --region "$REGION" >/dev/null 2>&1; then
  echo "[ssm-check] Found SecureString parameter: $PARAM_NAME"
  exit 0
fi

echo "[ssm-check] Missing SecureString parameter: $PARAM_NAME"
echo "[ssm-check] Prompting for ubuntu local password and creating the parameter..."
read -rsp "Ubuntu local password: " UBUNTU_PASS
echo

if [ -z "$UBUNTU_PASS" ]; then
  echo "[ssm-check] ERROR: Password cannot be empty."
  exit 1
fi

aws ssm put-parameter \
  --region "$REGION" \
  --name "$PARAM_NAME" \
  --type "SecureString" \
  --key-id "alias/aws/ssm" \
  --overwrite \
  --value "$(openssl passwd -6 "$UBUNTU_PASS")"

unset UBUNTU_PASS
echo "[ssm-check] Parameter created: $PARAM_NAME"
