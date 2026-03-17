# Quick Reference

## Installation

```bash
# Clone the repo
git clone https://github.com/yourname/steamdeck-dts-live.git
cd steamdeck-dts-live

# Make scripts executable (usually automatic after git clone)
chmod +x install.sh uninstall.sh

# Run installer
./install.sh
```

## Common Commands

### Full Installation
```bash
./install.sh
```
Builds dcaenc, detects HDMI outputs, configures PipeWire, and sets DTS sink as default.

### Preview Changes (Dry Run)
```bash
./install.sh --dry-run
```
Show all steps that would be performed without making any changes.

### Verbose Installation
```bash
./install.sh -v
```
Same as full installation but with detailed logging for troubleshooting.

### Reconfigure HDMI Output
```bash
./install.sh --reconfigure
```
Skip building dcaenc, just re-select HDMI output and restart audio.

### Get Help
```bash
./install.sh --help
```
Display usage information and examples.

### Uninstall
```bash
./uninstall.sh
```
Remove user configuration files and restart PipeWire.

## Testing

### Verify DTS Sink Exists
```bash
wpctl status
```
Look for "DTS Live Sink" in the Output Sinks section.

### Sample HDMI Devices
```bash
aplay -l
```
Shows all connected HDMI outputs.

### Test DTS Audio Playback
```bash
speaker-test -D default -c 6 -r 48000 -F S16_LE
```
Plays 6-channel test audio through the default sink (should be DTS).

### Test Direct ALSA (bypass PipeWire)
```bash
speaker-test -D dcahdmi:CARD=Generic,DEV=2 -c 6 -r 48000 -F S16_LE
```
Replace `DEV=2` with your selected device number. Verifies ALSA/dcaenc works.

## Troubleshooting

### View PipeWire Status
```bash
systemctl --user status pipewire
```

### View PipeWire Logs
```bash
journalctl --user -u pipewire -n 50 --follow
```
Real-time PipeWire log output (Ctrl+C to stop).

### Restart Audio Stack
```bash
systemctl --user restart pipewire pipewire-pulse wireplumber
```

### Check Installed dcaenc
```bash
ls -la /usr/lib/alsa-lib/libasound_module_pcm_dca.so
dcaenc --version
```

### Check User Configuration
```bash
cat ~/.asoundrc
cat ~/.config/pipewire/pipewire.conf.d/60-dts-live.conf
cat ~/.config/wireplumber/wireplumber.conf.d/51-default-targets.conf
```

### PipeWire Adapter Info
```bash
wpctl inspect <sink_id>
```
Replace `<sink_id>` with the ID from `wpctl status` (e.g., `wpctl inspect 34`).

## Gaming Setup

1. Launch game
2. Go to audio settings
3. Select **5.1 / Surround / Home Theater** audio output
4. Confirm audio plays
5. Check AVR/receiver for DTS indicator

**Important:** If game was already running when you installed, fully close and restart it.

## For Developers

### Run Import Tests
```bash
./test-imports.sh
```
Validates that all libraries source correctly.

### Check Script Syntax
```bash
bash -n install.sh
bash -n lib/*.sh
bash -n uninstall.sh
```

### Review Code Changes
```bash
cat DEVELOPMENT.md
```
See detailed improvements and before/after comparison.

## File Locations

| File | Purpose |
|------|---------|
| `~/.asoundrc` | ALSA configuration |
| `~/.config/pipewire/pipewire.conf.d/60-dts-live.conf` | PipeWire sink config |
| `~/.config/wireplumber/wireplumber.conf.d/51-default-targets.conf` | WirePlumber settings |
| `/usr/lib/alsa-lib/libasound_module_pcm_dca.so` | dcaenc ALSA plugin |
| `/usr/share/alsa/pcm/dca.conf` | ALSA dcaenc configuration |

## SteamOS System Commands

### Disable Read-Only Root
```bash
sudo steamos-readonly disable
```

### Enable Read-Only Root
```bash
sudo steamos-readonly enable
```

### Update System Packages
```bash
sudo pacman -Syu
```

## Support

For issues:
1. Run: `./install.sh --dry-run -v` to preview with debug output
2. Check README.md Troubleshooting section
3. Review PipeWire logs: `journalctl --user -u pipewire -n 100`
4. Test ALSA directly with `speaker-test`
5. Check HDMI detection with `aplay -l`
