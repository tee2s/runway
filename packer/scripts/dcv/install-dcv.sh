#!/usr/bin/env bash
# Installs the Amazon DCV server and web client components on Ubuntu from the official
# NICE DCV Linux server packages, enables the DCV service, and writes a minimal
# connectivity configuration for TCP/QUIC access.
# This follows the Amazon DCV Linux server installation guide and DCV connectivity
# configuration documentation:
# https://docs.aws.amazon.com/dcv/latest/adminguide/setting-up-installing-linux-server.html
# https://docs.aws.amazon.com/dcv/latest/adminguide/config-param-ref.html

set -euo pipefail

export DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"
export NEEDRESTART_MODE="${NEEDRESTART_MODE:-a}"

UBUNTU_DISTRO_TAG="${UBUNTU_DISTRO_TAG:?UBUNTU_DISTRO_TAG must be set}"

# If DCV_VERSION is set, use the versioned CloudFront path.
# Otherwise use the unversioned "latest" URL.
if [[ -n "${DCV_VERSION:-}" ]]; then
  DCV_MAJOR_VERSION="${DCV_VERSION%%-*}"
  DCV_DEB_URL="${DCV_DEB_URL:-https://d1uj6qtbmh3dt5.cloudfront.net/${DCV_MAJOR_VERSION}/Servers/nice-dcv-${DCV_VERSION}-${UBUNTU_DISTRO_TAG}-x86_64.tgz}"
else
  DCV_DEB_URL="${DCV_DEB_URL:-https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-${UBUNTU_DISTRO_TAG}-x86_64.tgz}"
fi

TMP_DIR="$(mktemp -d)"
echo "TMP_DIR=$TMP_DIR"

echo "[install-dcv] Downloading NICE DCV from: ${DCV_DEB_URL}"
wget -O "${TMP_DIR}/nice-dcv.tgz" "${DCV_DEB_URL}"

echo "[install-dcv] Extracting package..."
tar -xzf "${TMP_DIR}/nice-dcv.tgz" -C "${TMP_DIR}"

DCV_DIR="$(echo "${TMP_DIR}"/nice-dcv-*)"

echo "[install-dcv] Installing NICE DCV server packages..."
sudo apt-get update
sudo apt-get install -y \
  "${DCV_DIR}"/nice-dcv-server_*.deb \
  "${DCV_DIR}"/nice-dcv-web-viewer_*.deb

echo "[install-dcv] Adding dcv user to video group..."
sudo usermod -aG video dcv

echo "[install-dcv] Enabling DCV server..."
sudo systemctl enable dcvserver

echo "[install-dcv] Writing minimal DCV config..."
sudo mkdir -p /etc/dcv
cat <<'EOF' | sudo tee /etc/dcv/dcv.conf >/dev/null
[connectivity]
enable-quic-frontend = true
web-port = 8443
quic-port = 8443

[security]
authentication = "system"

[session-management]
create-session = true

[session-management/automatic-console-session]
owner = "ubuntu"
EOF

echo "[install-dcv] Starting DCV server..."
sudo systemctl restart dcvserver

echo "[install-dcv] NICE DCV installation complete."
echo "[install-dcv] Create sessions later via bootstrap using dcv create-session."
