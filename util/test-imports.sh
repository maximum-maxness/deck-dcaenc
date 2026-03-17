#!/usr/bin/env bash
# Simple test to verify all lib files can be sourced without errors


# Log file location
LOG_FILE="${STEAMDECK_DTS_LOG:-$PWD/steamdeck-dts-live.log}"

# If not already logging, re-exec with tee
if [[ -z "${STEAMDECK_DTS_LOGGING:-}" ]]; then
  export STEAMDECK_DTS_LOGGING=1
  exec > >(tee -a "$LOG_FILE") 2>&1
fi

# Debug mode: enable with --debug or DEBUG=1
for arg in "$@"; do
  if [[ "$arg" == "--debug" ]]; then
    export DEBUG=1
  fi
done
if [[ "${DEBUG:-0}" == "1" ]]; then
  export PS4='[DEBUG] ${BASH_SOURCE}:${LINENO}: '
  exec 4>>"$LOG_FILE"
  BASH_XTRACEFD=4
  set -x
  echo "[INFO] Debug tracing enabled (see $LOG_FILE)"
fi

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Testing library imports..."
echo

# Test each library import
for lib in common.sh build_dcaenc.sh detect_outputs.sh write_configs.sh pipewire.sh; do
  echo -n "Sourcing lib/$lib... "
  if source "$REPO_DIR/lib/$lib" 2>/dev/null; then
    echo "✓"
  else
    echo "✗ FAILED"
    exit 1
  fi
done

echo
echo "Testing main functions are available..."
echo

# Check that key functions exist
functions=(
  "banner"
  "require_command"
  "log_info"
  "log_error"
  "build_and_install_dcaenc"
  "choose_hdmi_output"
  "write_asoundrc"
  "restart_audio_stack"
  "find_dts_sink_id"
)

for func in "${functions[@]}"; do
  echo -n "Checking function $func... "
  if declare -f "$func" >/dev/null; then
    echo "✓"
  else
    echo "✗ MISSING"
    exit 1
  fi
done

echo
echo "All tests passed! ✓"
