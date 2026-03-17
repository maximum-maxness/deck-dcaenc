#!/usr/bin/env bash


# Log file location
LOG_FILE="${STEAMDECK_DTS_LOG:-$PWD/steamdeck-dts-live.log}"

# Setup logging (redirect to log file, keep terminal clean)
exec {LOG_FD}>>"$LOG_FILE"
exec > >(tee /dev/fd/$LOG_FD)
exec 2>&1

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

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================"
echo "Steam Deck DTS Live - Uninstall"
echo "========================================"
echo

removed_count=0

# Remove user configuration files
if [[ -f "$HOME/.asoundrc" ]]; then
  rm -f "$HOME/.asoundrc"
  echo "Removed: ~/.asoundrc"
  removed_count=$((removed_count + 1))
fi

if [[ -f "$HOME/.config/pipewire/pipewire.conf.d/60-dts-live.conf" ]]; then
  rm -f "$HOME/.config/pipewire/pipewire.conf.d/60-dts-live.conf"
  echo "Removed: ~/.config/pipewire/pipewire.conf.d/60-dts-live.conf"
  removed_count=$((removed_count + 1))
fi

if [[ -f "$HOME/.config/wireplumber/wireplumber.conf.d/51-default-targets.conf" ]]; then
  rm -f "$HOME/.config/wireplumber/wireplumber.conf.d/51-default-targets.conf"
  echo "Removed: ~/.config/wireplumber/wireplumber.conf.d/51-default-targets.conf"
  removed_count=$((removed_count + 1))
fi

echo

# Restart audio stack
echo "Restarting PipeWire audio stack..."
systemctl --user restart pipewire pipewire-pulse wireplumber || true
sleep 2
echo "Audio stack restarted"
echo

if [[ $removed_count -eq 0 ]]; then
  echo "No DTS configuration files were found."
else
  echo "Removed $removed_count configuration file(s)."
fi

echo
echo "Note: System-installed dcaenc files remain in place:"
echo "  /usr/lib/alsa-lib/libasound_module_pcm_dca.so"
echo "  /usr/share/alsa/pcm/dca.conf"
echo
echo "To uninstall dcaenc completely, run:"
echo "  sudo pacman -R dcaenc  (if installed as package)"
echo "  (or manually remove the files above)"

# Cleanup: close log file descriptor  
exec {LOG_FD}>&-
exit 0