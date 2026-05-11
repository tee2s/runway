#!/usr/bin/env bash
# Applies final login policy for the runtime AMI.

set -euo pipefail

PARAM_NAME="${PARAM_NAME:?PARAM_NAME must be set}"
REGION="${REGION:?REGION must be set}"
SSH_USERNAME="${SSH_USERNAME:-ubuntu}"

echo "[configure-login] Fetching password hash from SSM parameter: ${PARAM_NAME}"
UBUNTU_PASSWORD_HASH="$(
  aws ssm get-parameter \
    --name "${PARAM_NAME}" \
    --with-decryption \
    --region "${REGION}" \
    --query 'Parameter.Value' \
    --output text
)"

echo "[configure-login] Setting password hash for ${SSH_USERNAME}"
sudo usermod --password "${UBUNTU_PASSWORD_HASH}" "${SSH_USERNAME}"

echo "[configure-login] Disabling SSH password authentication"
sudo install -d -m 0755 /etc/ssh/sshd_config.d
printf '%s\n' \
  'PasswordAuthentication no' \
  'KbdInteractiveAuthentication no' \
  'ChallengeResponseAuthentication no' \
  | sudo tee /etc/ssh/sshd_config.d/99-password-auth-disabled.conf >/dev/null

sudo systemctl reload ssh || true

echo "[configure-login] Login policy complete."
