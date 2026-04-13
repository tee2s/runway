#!/usr/bin/env bash
set -euo pipefail

SSH_DIR="${HOME}/.ssh"
SSH_CONFIG="${SSH_DIR}/config"
SSH_CONFIG_D="${SSH_DIR}/config.d"
INCLUDE_LINE='Include ~/.ssh/config.d/*'

mkdir -p "${SSH_DIR}" "${SSH_CONFIG_D}"
touch "${SSH_CONFIG}"

tmp_file="$(mktemp)"
awk -v include_line="${INCLUDE_LINE}" '
  BEGIN { print include_line }
  $0 != include_line { print }
' "${SSH_CONFIG}" > "${tmp_file}"
mv "${tmp_file}" "${SSH_CONFIG}"
echo "Updated ${SSH_CONFIG} to use ~/.ssh/config.d drop-in files."

chmod 700 "${SSH_DIR}"
chmod 600 "${SSH_CONFIG}"