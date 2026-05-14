#!/usr/bin/env bash
# Installs final-stage package tooling. Add future package installs here.

set -euo pipefail

export DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"
export NEEDRESTART_MODE="${NEEDRESTART_MODE:-a}"

PIXI_HOME="/opt/pixi"
PIXI_BIN_DIR="/usr/local/bin"
UV_INSTALL_DIR="/usr/local/bin"
NEOVIM_INSTALL_DIR="/opt/nvim"
NEOVIM_BIN="/usr/local/bin/nvim"
GHOSTTY_BIN="/usr/bin/ghostty"

apt_get() {
  sudo apt-get -o DPkg::Lock::Timeout=-1 "$@"
}

install_neovim() {
  local arch
  local asset_arch
  local archive
  local download_url
  local tmp_dir

  arch="$(uname -m)"
  case "${arch}" in
    x86_64 | amd64)
      asset_arch="x86_64"
      ;;
    aarch64 | arm64)
      asset_arch="arm64"
      ;;
    *)
      echo "[install-packages] ERROR: Unsupported Neovim architecture: ${arch}"
      exit 1
      ;;
  esac

  archive="nvim-linux-${asset_arch}.tar.gz"
  download_url="https://github.com/neovim/neovim/releases/latest/download/${archive}"
  tmp_dir="$(mktemp -d)"

  echo "[install-packages] Installing Neovim from ${download_url}..."
  curl -fsSL "${download_url}" -o "${tmp_dir}/${archive}"
  tar -xzf "${tmp_dir}/${archive}" -C "${tmp_dir}"

  sudo rm -rf "${NEOVIM_INSTALL_DIR}"
  sudo install -d -m 0755 "${NEOVIM_INSTALL_DIR}"
  sudo cp -a "${tmp_dir}/nvim-linux-${asset_arch}/." "${NEOVIM_INSTALL_DIR}/"
  sudo ln -sf "${NEOVIM_INSTALL_DIR}/bin/nvim" "${NEOVIM_BIN}"
  rm -rf "${tmp_dir}"
}

configure_default_editor() {
  echo "[install-packages] Setting Neovim as the default editor..."
  sudo update-alternatives --install /usr/bin/editor editor "${NEOVIM_BIN}" 100
  sudo update-alternatives --set editor "${NEOVIM_BIN}"

  if [ -e /usr/bin/vi ]; then
    sudo update-alternatives --install /usr/bin/vi vi "${NEOVIM_BIN}" 100
    sudo update-alternatives --set vi "${NEOVIM_BIN}"
  fi

  if [ -e /usr/bin/vim ]; then
    sudo update-alternatives --install /usr/bin/vim vim "${NEOVIM_BIN}" 100
    sudo update-alternatives --set vim "${NEOVIM_BIN}"
  fi

  sudo tee /etc/profile.d/90-default-editor.sh >/dev/null <<'EOF'
export EDITOR=nvim
export VISUAL=nvim
EOF
  sudo chmod 0644 /etc/profile.d/90-default-editor.sh
}

configure_default_terminal() {
  echo "[install-packages] Setting Ghostty as the default terminal..."
  if [ ! -x "${GHOSTTY_BIN}" ]; then
    echo "[install-packages] ERROR: Ghostty was not installed at ${GHOSTTY_BIN}"
    exit 1
  fi

  sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator "${GHOSTTY_BIN}" 100
  sudo update-alternatives --set x-terminal-emulator "${GHOSTTY_BIN}"

  if command -v dconf >/dev/null 2>&1; then
    sudo install -d -m 0755 /etc/dconf/db/local.d
    sudo tee /etc/dconf/db/local.d/00-default-terminal >/dev/null <<'EOF'
[org/gnome/desktop/default-applications/terminal]
exec='ghostty'
exec-arg=''
EOF
    sudo dconf update
  fi

}

echo "[install-packages] Stopping background apt services..."
sudo systemctl stop apt-daily.service apt-daily-upgrade.service unattended-upgrades.service 2>/dev/null || true
sudo systemctl kill --kill-who=all apt-daily.service apt-daily-upgrade.service unattended-upgrades.service 2>/dev/null || true
sudo pkill -9 -f unattended-upgrade 2>/dev/null || true
sudo pkill -9 -f apt.systemd.daily 2>/dev/null || true

echo "[install-packages] Installing Pixi prerequisites..."
apt_get update -y
apt_get install -y ca-certificates curl software-properties-common

echo "[install-packages] Installing Pixi to ${PIXI_BIN_DIR}/pixi with PIXI_HOME=${PIXI_HOME}..."
sudo install -d -m 0755 "${PIXI_HOME}" "${PIXI_BIN_DIR}"
curl -fsSL https://pixi.sh/install.sh \
  | sudo env PIXI_HOME="${PIXI_HOME}" PIXI_BIN_DIR="${PIXI_BIN_DIR}" PIXI_NO_PATH_UPDATE=1 bash

echo "[install-packages] Pixi version:"
pixi --version

echo "[install-packages] Installing uv to ${UV_INSTALL_DIR}..."
curl -fsSL https://astral.sh/uv/install.sh \
  | sudo env UV_INSTALL_DIR="${UV_INSTALL_DIR}" UV_NO_MODIFY_PATH=1 sh

echo "[install-packages] uv version:"
uv --version

echo "[install-packages] Adding Ghostty Ubuntu PPA..."
sudo add-apt-repository -y ppa:mkasberg/ghostty-ubuntu

echo "[install-packages] Installing Ghostty..."
apt_get update -y
apt_get install -y ghostty

install_neovim
configure_default_editor
configure_default_terminal

echo "[install-packages] Neovim version:"
nvim --version

echo "[install-packages] Final package tooling complete."
