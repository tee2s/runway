#!/usr/bin/env bash
# Installs final-stage package tooling. Add future package installs here.

set -euo pipefail

export DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"
export NEEDRESTART_MODE="${NEEDRESTART_MODE:-a}"

PIXI_HOME="/opt/pixi"
PIXI_BIN_DIR="/usr/local/bin"

echo "[install-packages] Installing Pixi prerequisites..."
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl

echo "[install-packages] Installing Pixi to ${PIXI_BIN_DIR}/pixi with PIXI_HOME=${PIXI_HOME}..."
sudo install -d -m 0755 "${PIXI_HOME}" "${PIXI_BIN_DIR}"
curl -fsSL https://pixi.sh/install.sh \
  | sudo env PIXI_HOME="${PIXI_HOME}" PIXI_BIN_DIR="${PIXI_BIN_DIR}" PIXI_NO_PATH_UPDATE=1 bash

echo "[install-packages] Pixi version:"
pixi --version

echo "[install-packages] Final package tooling complete."
