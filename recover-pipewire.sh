#!/usr/bin/env bash
set -euo pipefail

####################################################################################
# Steam Deck DTS Live - PipeWire Recovery & Diagnostics
#
# This script recovers from PipeWire errors, particularly:
# 1. Stale lock files preventing PipeWire from starting
# 2. Configuration syntax errors in the DTS adapter
# 3. Audio service restart conflicts
#
# Run this if you see:
# - "Could not connect to PipeWire"
# - "unable to lock lockfile"
# - PipeWire failing with exit code 234
####################################################################################

log_info() { echo "[INFO] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }
log_success() { echo "[✓] $*" >&2; }

main() {
  echo "========================================"
  echo "Steam Deck DTS Live - PipeWire Recovery"
  echo "========================================"
  echo

  # Stage 1: Kill all audio processes
  log_info "Stage 1: Stopping audio services..."
  systemctl --user stop pipewire pipewire-pulse wireplumber 2>/dev/null || true
  pkill -9 pipewire pipewire-pulse wireplumber 2>/dev/null || true
  sleep 2
  log_success "Audio services stopped"
  echo

  # Stage 2: Remove stale lock files
  log_info "Stage 2: Clearing stale PipeWire lock files..."
  rm -f /run/user/1000/pipewire-*.lock
  rm -f /run/user/1000/pipewire-*.state
  rm -f /run/user/1000/pipewire-0-manager
  log_success "Lock files cleared"
  echo

  # Stage 3: Reset systemd state
  log_info "Stage 3: Resetting systemd state..."
  systemctl --user reset-failed
  log_success "Systemd state reset"
  echo

  # Stage 4: Start PipeWire socket
  log_info "Stage 4: Starting PipeWire socket..."
  systemctl --user start pipewire.socket
  sleep 2
  log_success "PipeWire socket started"
  echo

  # Stage 5: Start PipeWire service
  log_info "Stage 5: Starting PipeWire service..."
  if systemctl --user start pipewire 2>/dev/null; then
    sleep 3
    if systemctl --user is-active pipewire >/dev/null 2>&1; then
      log_success "PipeWire service started"
    else
      log_error "PipeWire service started but is not active"
      systemctl --user status pipewire -n 10
      return 1
    fi
  else
    log_error "Failed to start PipeWire service"
    return 1
  fi
  echo

  # Stage 6: Start PipeWire Pulse
  log_info "Stage 6: Starting PipeWire Pulse..."
  systemctl --user start pipewire-pulse 2>/dev/null || log_error "Could not start pipewire-pulse"
  sleep 1
  log_success "PipeWire Pulse started"
  echo

  # Stage 7: Start WirePlumber
  log_info "Stage 7: Starting WirePlumber..."
  systemctl --user start wireplumber 2>/dev/null || log_error "Could not start wireplumber"
  sleep 2
  log_success "WirePlumber started"
  echo

  # Stage 8: Test connectivity
  log_info "Stage 8: Testing PipeWire connectivity..."
  if timeout 5 wpctl status >/dev/null 2>&1; then
    log_success "PipeWire is responsive"
  else
    log_error "wpctl cannot connect to PipeWire"
    log_error "Try manual restart: systemctl --user restart pipewire"
    return 1
  fi
  echo

  # Stage 9: Check DTS sink
  log_info "Stage 9: Checking for DTS Live Sink..."
  if timeout 5 wpctl status 2>/dev/null | grep -q "DTS Live Sink"; then
    log_success "DTS Live Sink found!"
  elif [[ -f ~/.config/pipewire/pipewire.conf.d/60-dts-live.conf ]]; then
    log_error "DTS config file exists but sink not found"
    log_error "Configuration may have syntax error"
    return 1
  else
    log_info "DTS config not yet loaded (can run: ./install.sh --reconfigure)"
  fi
  echo

  echo "========================================"
  echo "Recovery Summary"
  echo "========================================"
  systemctl --user status pipewire pipewire-pulse wireplumber --no-pager | grep "Active:"
  echo
  echo "Next steps:"
  echo "  1. Verify with: wpctl status"
  echo "  2. Test audio: speaker-test -D default -c 2 -r 48000"
  echo "  3. If DTS needed: ./install.sh --reconfigure"
  echo
}

main "$@"
