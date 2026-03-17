#!/usr/bin/env bash
set -euo pipefail

restart_audio_stack() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[DRY RUN] Would restart: pipewire, pipewire-pulse, wireplumber"
    return
  fi

  log_info "Restarting PipeWire audio stack..."
  
  # Clear stale lock files before restart to prevent "already running" errors
  rm -f /run/user/1000/pipewire-*.lock /run/user/1000/pipewire-*.state /run/user/1000/pipewire-0-manager 2>/dev/null || true
  
  systemctl --user restart pipewire pipewire-pulse wireplumber
  log_verbose "Audio stack restarted"
}

wait_for_pipewire() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[DRY RUN] Would wait for PipeWire to become available"
    return
  fi

  log_info "Waiting for PipeWire to become available..."
  local i
  for i in {1..20}; do
    if wpctl status >/dev/null 2>&1; then
      log_verbose "PipeWire is ready (attempt $i/20)"
      sleep 1
      return 0
    fi
    sleep 0.5
  done
  log_error "PipeWire did not come up in time after 10 seconds."
  log_error "Check status with: systemctl --user status pipewire"
  log_error "View logs with: journalctl --user -u pipewire -n 20"
  exit 1
}

find_dts_sink_id() {
  local i
  local sink_id
  
  # Give the adapter time to fully initialize (it can take a few retries)
  for i in {1..15}; do
    sink_id="$(wpctl status 2>/dev/null | awk '
      /Sinks:/ { in_sinks = 1; next }
      /Sources:/ { in_sinks = 0 }
      in_sinks && /DTS Live Sink/ {
        # Extract ID number from line like "├─ 34. DTS Live Sink"
        # Use first number found rather than anchor to start (handles UTF-8 box chars)
        if (match($0, /[0-9]+/)) {
          print substr($0, RSTART, RLENGTH)
          exit
        }
      }
    ')" || sink_id=""

    if [[ -n "$sink_id" ]]; then
      log_verbose "Found DTS Live Sink with ID: $sink_id (attempt $i/15)"
      printf '%s\n' "$sink_id"
      return 0
    fi
    
    # Wait a bit before retrying
    sleep 0.3
  done

  log_verbose "DTS Live Sink not found after 4.5 seconds of retries"
  return 1
}

set_default_sink() {
  local sink_id="$1"

  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[DRY RUN] Would set sink $sink_id as default"
    return
  fi

  if [[ -z "$sink_id" ]]; then
    log_error "Cannot set default sink: sink_id is empty"
    exit 1
  fi

  log_info "Setting DTS Live Sink (ID: $sink_id) as default..."
  wpctl set-default "$sink_id"
  log_verbose "Default sink set to $sink_id"
}

verify_sink_config() {
  local sink_id="$1"

  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[DRY RUN] Would verify sink configuration"
    return
  fi

  log_info "Verifying DTS sink configuration..."

  # Check with wpctl
  local wpctl_info
  wpctl_info="$(wpctl inspect "$sink_id" 2>/dev/null || echo "")"
  
  if [[ -z "$wpctl_info" ]]; then
    log_error "Could not inspect sink $sink_id"
    return 1
  fi

  # Check with pactl for sink format
  local pactl_info
  pactl_info="$(pactl list sinks short 2>/dev/null | grep "dts_live_sink" || echo "")"

  if [[ -n "$pactl_info" ]]; then
    log_verbose "Sink info: $pactl_info"
    log_info "DTS sink is configured and available"
    return 0
  else
    log_verbose "Could not verify sink with pactl (may still be working)"
    return 0
  fi
}