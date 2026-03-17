#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$REPO_DIR/lib/common.sh"
source "$REPO_DIR/lib/build_dcaenc.sh"
source "$REPO_DIR/lib/detect_outputs.sh"
source "$REPO_DIR/lib/write_configs.sh"
source "$REPO_DIR/lib/pipewire.sh"

main() {
  banner "Steam Deck DTS Live Installer"

  require_command sudo
  require_command git
  require_command aplay
  require_command systemctl

  ensure_sudo
  disable_readonly_root
  install_build_deps
  repair_core_packages
  build_and_install_dcaenc "$REPO_DIR/.build"

  local chosen_dev
  chosen_dev="$(choose_hdmi_output)"

  write_asoundrc "$chosen_dev"
  write_pipewire_sink_config "$chosen_dev"
  write_wireplumber_restore_config

  restart_audio_stack
  wait_for_pipewire

  local sink_id
  sink_id="$(find_dts_sink_id || true)"
  if [[ -n "${sink_id:-}" ]]; then
    set_default_sink "$sink_id"
    echo
    echo "DTS sink created successfully."
    echo "Sink ID: $sink_id"
  else
    echo
    echo "Warning: DTS sink was not detected automatically."
    echo "Check: wpctl status"
    exit 1
  fi

  echo
  echo "Test with:"
  echo "  speaker-test -D default -c 6 -r 48000 -F S16_LE"
  echo "  wpctl status"
  echo
  echo "You may need to relaunch games after changing the default sink."
}

main "$@"