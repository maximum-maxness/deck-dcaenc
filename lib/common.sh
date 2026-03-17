#!/usr/bin/env bash
set -euo pipefail

banner() {
  echo "========================================"
  echo "$1"
  echo "========================================"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

ensure_sudo() {
  sudo -v
}

disable_readonly_root() {
  if command -v steamos-readonly >/dev/null 2>&1; then
    sudo steamos-readonly disable || true
  fi
}

install_build_deps() {
  sudo pacman -S --needed git base-devel autoconf automake libtool alsa-lib pkgconf
}

repair_core_packages() {
  sudo pacman -S --needed --overwrite='*' alsa-lib linux-api-headers
  sudo ldconfig
}