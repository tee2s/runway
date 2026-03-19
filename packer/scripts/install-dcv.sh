#!/usr/bin/env bash 
#maybe install xorg xfce4 xfce4-goodies

set -euxo pipefail

DCV_VERSION="2024.0.18131"
DCV_PKG="nice-dcv-server_${DCV_VERSION}_ubuntu2204_amd64.deb"
DCV_URL="https://d1uj6qtbmh3dt5.cloudfront.net/${DCV_PKG}"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

cd "$tmpdir"
wget -q "$DCV_URL"
sudo apt-get update
sudo apt-get install -y ./${DCV_PKG}

sudo systemctl enable dcvserver
sudo mkdir -p /etc/dcv
sudo tee /etc/dcv/dcv.conf >/dev/null <<'EOF'
[session-management]
automatic-console-session=true

[connectivity]
web-port=8443

[display]
gl-displays=[':0']
EOF
