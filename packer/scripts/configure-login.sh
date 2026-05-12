#!/usr/bin/env bash
# Applies final SSH login policy for the runtime AMI.

set -euo pipefail

echo "[configure-login] Disabling SSH password authentication"
sudo install -d -m 0755 /etc/ssh/sshd_config.d
printf '%s\n' \
  'PasswordAuthentication no' \
  'KbdInteractiveAuthentication no' \
  'ChallengeResponseAuthentication no' \
  | sudo tee /etc/ssh/sshd_config.d/99-password-auth-disabled.conf >/dev/null

sudo systemctl reload ssh || true

echo "[configure-login] Login policy complete."
