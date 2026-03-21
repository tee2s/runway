#!/usr/bin/env bash
set -euo pipefail

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

echo "[install-awscli] Installing prerequisites..."
sudo apt-get update -y
sudo apt-get install -y unzip curl

echo "[install-awscli] Downloading AWS CLI..."
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "${TMP_DIR}/awscliv2.zip"

echo "[install-awscli] Installing AWS CLI..."
unzip -q "${TMP_DIR}/awscliv2.zip" -d "${TMP_DIR}"
sudo "${TMP_DIR}/aws/install" --update

echo "[install-awscli] Verifying installation..."
aws --version

echo "[install-awscli] AWS CLI installation complete."
