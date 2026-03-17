#!/usr/bin/env bash

# Log file location
LOG_FILE="${STEAMDECK_DTS_LOG:-$PWD/steamdeck-dts-live.log}"

# If not already logging, re-exec with tee
if [[ -z "${STEAMDECK_DTS_LOGGING:-}" ]]; then
  export STEAMDECK_DTS_LOGGING=1
  exec > >(tee -a "$LOG_FILE") 2>&1
fi

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$REPO_DIR/lib/common.sh"
source "$REPO_DIR/lib/build_dcaenc.sh"
source "$REPO_DIR/lib/detect_outputs.sh"
source "$REPO_DIR/lib/write_configs.sh"
source "$REPO_DIR/lib/pipewire.sh"

# Enable command tracing to log file for full verbosity (after library setup)
export PS4='[CMD] ${BASH_SOURCE}:${LINENO}: '
exec 4>>"$LOG_FILE"
export BASH_XTRACEFD=4
set -x

show_usage() {
  cat >&2 <<EOF
Usage: $0 [OPTIONS]

OPTIONS:
  --dry-run       Show what would be done without making changes
  --reconfigure   Skip build, just reconfigure sink and restart PipeWire
  -v, --verbose   Show verbose output
  -h, --help      Show this help message

EXAMPLES:
  $0                    # Full installation
  $0 --dry-run          # Preview without making changes
  $0 --reconfigure      # Update HDMI output for existing installation
  $0 -v                 # Verbose full installation
EOF
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        export DRY_RUN=1
        log_info "DRY RUN mode enabled - no changes will be made"
        shift
        ;;
      --reconfigure)
        export RECONFIGURE=1
        shift
        ;;
      --debug)
        export DEBUG=1
        log_info "DEBUG mode enabled - full trace will be logged"
        shift
        ;;
      -v|--verbose)
        export VERBOSE=1
        shift
        ;;
      -h|--help)
        show_usage
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        show_usage
        exit 1
        ;;
    esac
  done
}

main() {
  # If debug, enable tracing to log only
  if [[ "${DEBUG:-0}" == "1" ]]; then
    # Save original stdout (terminal)
    exec 3>&1
    # All output (stdout+stderr) still goes to tee (terminal+log)
    # But trace output goes only to log file
    export PS4='[DEBUG] ${BASH_SOURCE}:${LINENO}: '
    exec 4>>"$LOG_FILE"
    BASH_XTRACEFD=4
    set -x
    log_info "Debug tracing enabled (see $LOG_FILE)"
  fi
  banner "Steam Deck DTS Live Installer"

  parse_arguments "$@"

  require_command sudo
  require_command git
  require_command aplay
  require_command systemctl
  require_command wpctl
  require_command pactl

  if [[ "${RECONFIGURE:-0}" == "1" ]]; then
    log_info "Reconfiguration mode: skipping build"
  else
    ensure_sudo
    disable_readonly_root
    install_build_deps
    repair_core_packages

    log_info "Building dcaenc..."
    build_and_install_dcaenc "${XDG_RUNTIME_DIR:-/tmp}/steamdeck-dts-live-build"
    log_info "dcaenc build complete"
    echo
  fi

  # HDMI output selection
  local chosen_dev
  chosen_dev="$(choose_hdmi_output)"

  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[DRY RUN] Would use HDMI device: $chosen_dev"
  else
    log_info "Using HDMI device: $chosen_dev"
  fi
  echo

  # Write configurations
  write_asoundrc "$chosen_dev"
  write_pipewire_sink_config "$chosen_dev"
  write_wireplumber_restore_config

  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[DRY RUN] Dry run complete. Review the above to proceed."
    echo
    log_info "To apply changes, run: $0"
    exit 0
  fi

  # Restart audio and find sink
  restart_audio_stack
  wait_for_pipewire

  local sink_id
  sink_id="$(find_dts_sink_id || true)"

  if [[ -z "${sink_id:-}" ]]; then
    log_error "DTS sink was not found after restarting PipeWire."
    log_error "Troubleshooting steps:"
    log_error "  1. Check sink creation: wpctl status"
    log_error "  2. View PipeWire logs: journalctl --user -u pipewire -n 50"
    log_error "  3. Verify .asoundrc: cat ~/.asoundrc"
    log_error "  4. Test ALSA directly: speaker-test -D dcahdmi:CARD=Generic,DEV=$chosen_dev -c 6 -r 48000 -F S16_LE"
    exit 1
  fi

  set_default_sink "$sink_id"
  verify_sink_config "$sink_id"

  echo
  banner "Installation Complete"
  echo
  echo "DTS Live Sink:"
  echo "  ID: $sink_id"
  echo "  Name: DTS Live Sink"
  echo "  Channels: 6 (5.1 surround)"
  echo "  Sample Rate: 48000 Hz"
  echo
  echo "Next steps:"
  echo "  1. Verify with:     wpctl status"
  echo "  2. Test playback:   speaker-test -D default -c 6 -r 48000 -F S16_LE"
  echo "  3. Launch a game    (fully restart if already running)"
  echo "  4. Check receiver   (should display DTS signal)"
  echo
  echo "Troubleshooting:"
  echo "  Reconfigure sink:   $0 --reconfigure"
  echo "  Disable/remove:     ./uninstall.sh"
  echo
}

main "$@"