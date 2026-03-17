#!/usr/bin/env bash
set -euo pipefail

echo "========================================="
echo "PipeWire Diagnostic & Recovery"
echo "========================================="
echo

# Stop all audio services first
echo "[*] Stopping audio services..."
systemctl --user stop pipewire pipewire-pulse wireplumber 2>/dev/null || true
systemctl --user stop pipewire.socket 2>/dev/null || true
systemctl --user reset-failed 2>/dev/null || true
sleep 2

# Test 1: Can PipeWire start without our config?
echo "[*] Test 1: Starting PipeWire without DTS adapter config..."
if [[ -f ~/.config/pipewire/pipewire.conf.d/60-dts-live.conf ]]; then
  mv ~/.config/pipewire/pipewire.conf.d/60-dts-live.conf ~/.config/pipewire/pipewire.conf.d/60-dts-live.conf.backup
fi

systemctl --user start pipewire.socket 2>/dev/null || true
sleep 1
systemctl --user start pipewire 2>/dev/null || true
sleep 3

if wpctl status >/dev/null 2>&1; then
  echo "✓ PipeWire started successfully WITHOUT DTS config"
  echo "  Issue is in the DTS adapter configuration."
else
  echo "✗ PipeWire still fails without DTS config"
  echo "  Need to investigate system audio setup."
fi

echo
echo "[*] Stopping services again..."
systemctl --user stop pipewire pipewire-pulse wireplumber 2>/dev/null || true
systemctl --user stop pipewire.socket 2>/dev/null || true
systemctl --user reset-failed 2>/dev/null || true
sleep 2

# Restore backup
if [[ -f ~/.config/pipewire/pipewire.conf.d/60-dts-live.conf.backup ]]; then
  echo "[*] Analyzing DTS config file..."
  echo "Current DTS config:"
  echo "---"
  cat ~/.config/pipewire/pipewire.conf.d/60-dts-live.conf.backup
  echo "---"
  echo
  echo "Known issues to check:"
  echo "  1. Missing closing braces"
  echo "  2. Invalid ALSA device path"
  echo "  3. Incorrect property values"
fi

echo
echo "Recommendations:"
echo "  1. Check PipeWire logs: journalctl --user -u pipewire -n 100"
echo "  2. Test ALSA device directly:"
echo "     aplay -D dcahdmi:CARD=Generic,DEV=8 /dev/zero &"
echo "     sleep 1; kill %1"
echo "  3. Verify dcaenc installed: ls /usr/lib/alsa-lib/libasound_module_pcm_dca.so"
