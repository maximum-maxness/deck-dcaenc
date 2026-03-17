#!/usr/bin/env bash
set -euo pipefail

# Global state
VERBOSE="${VERBOSE:-0}"
DRY_RUN="${DRY_RUN:-0}"

log_info() {
  echo "[INFO] $*" >&2
}

log_error() {
  echo "[ERROR] $*" >&2
}

log_verbose() {
  # Always write to log file, only write to terminal if VERBOSE=1
  if [[ -n "${LOG_FILE:-}" ]]; then
    echo "[VERBOSE] $*" >> "$LOG_FILE"
  fi
  if [[ "$VERBOSE" == "1" ]]; then
    echo "[VERBOSE] $*" >&2
  fi
}

banner() {
  echo "========================================"
  echo "$1"
  echo "========================================"
  echo
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    log_error "Missing required command: $1"
    exit 1
  }
  log_verbose "Found command: $1"
}

ensure_sudo() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[DRY RUN] Would prompt for sudo"
    return
  fi
  sudo -v
  log_verbose "Sudo validated"
}

disable_readonly_root() {
  if command -v steamos-readonly >/dev/null 2>&1; then
    if [[ "$DRY_RUN" == "1" ]]; then
      log_info "[DRY RUN] Would disable readonly root"
      return
    fi
    log_info "Disabling SteamOS read-only root..."
    sudo steamos-readonly disable || {
      log_verbose "steamos-readonly disable returned non-zero (may already be disabled)"
    }
  else
    log_verbose "steamos-readonly not found (not on SteamOS?)"
  fi
}

install_build_deps() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[DRY RUN] Would install: git base-devel autoconf automake libtool alsa-lib pkgconf linux-api-headers"
    return
  fi
  log_info "Installing build dependencies..."
  sudo pacman -S --needed git base-devel autoconf automake libtool alsa-lib pkgconf linux-api-headers
  log_verbose "Build dependencies installed"
}

repair_core_packages() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[DRY RUN] Would repair core packages: alsa-lib linux-api-headers"
    return
  fi
  log_info "Repairing core packages..."
  sudo pacman -S --needed --overwrite='*' alsa-lib linux-api-headers
  sudo ldconfig
  log_verbose "Core packages repaired"
}