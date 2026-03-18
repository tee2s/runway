#!/usr/bin/env bash
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo ubuntu-drivers autoinstall
which nvidia-smi || true
