#!/usr/bin/env bash
set -euo pipefail

rm -f "$HOME/.asoundrc"
rm -f "$HOME/.config/pipewire/pipewire.conf.d/60-dts-live.conf"
rm -f "$HOME/.config/wireplumber/wireplumber.conf.d/51-default-targets.conf"

systemctl --user restart pipewire pipewire-pulse wireplumber

echo "User DTS configuration removed."
echo "System-installed dcaenc files were left in place."