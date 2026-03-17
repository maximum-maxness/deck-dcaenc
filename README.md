# Steam Deck DTS Live

Interactive installer and configuration script for real-time DTS encoding on Steam Deck.

This project automates the setup of a PipeWire audio sink that encodes 5.1 surround sound to DTS in real-time, allowing Steam Deck games to output DTS over HDMI to AVRs and soundbars that support DTS decoding.

## Features

- **Automated build and installation** of dcaenc (DTS encoder) from GitLab upstream
- **HDMI output detection** - automatically finds all connected HDMI outputs
- **Interactive selection** - lets you choose which HDMI port to use
- **PipeWire integration** - creates a modern, reliable audio sink
- **Automatic configuration** - writes ALSA and PipeWire configs with correct parameters
- **Verification** - checks installation success before completing
- **Easy reconfiguration** - switch HDMI outputs without rebuilding
- **Dry-run mode** - preview changes before applying
- **Comprehensive logging** - verbose output for troubleshooting

## Requirements

- **Steam Deck** running SteamOS (tested on SteamOS 3.x)
- **Desktop Mode** or SSH access
- **sudo** password configured
- **HDMI-connected display** with DTS support (AVR or soundbar recommended)
- **5GB+ free space** in `/tmp` for building dcaenc

## Installation

### Quick Start

```bash
git clone https://github.com/yourname/steamdeck-dts-live.git
cd steamdeck-dts-live
chmod +x install.sh uninstall.sh
./install.sh
```

### Advanced Options

```bash
# Preview changes without applying
./install.sh --dry-run

# Full verbose output for troubleshooting
./install.sh -v

# Reconfigure HDMI output for existing installation
./install.sh --reconfigure

# Combine options
./install.sh --dry-run -v
./install.sh --reconfigure --verbose
```

### Installation Steps Performed

1. Validates required commands
2. Prompts for sudo password (needed for package installation)
3. Disables SteamOS read-only root filesystem
4. Installs build dependencies (git, base-devel, autoconf, etc.)
5. Repairs core packages (alsa-lib, linux-api-headers)
6. Clones and builds dcaenc from GitLab
7. Detects HDMI outputs via `aplay -l`
8. Prompts to select target HDMI output
9. Generates and writes configuration files
10. Restarts PipeWire audio stack
11. Verifies DTS sink creation and sets as default
12. Displays test instructions

## Testing

After installation completes, verify the DTS sink is working:

```bash
# Check that the DTS sink exists
wpctl status

# Should show:
#   Sinks:
#     34. DTS Live Sink [vol: 1.00]

# Test 5.1 channel output
speaker-test -D default -c 6 -r 48000 -F S16_LE

# Test with actual game audio
# Launch a game, set audio to 5.1/Surround in game settings
# Your AVR should display "DTS" indicator
```

## Configuration Files

The installer creates three configuration files:

### 1. `~/.asoundrc`
ALSA configuration directing the default PCM through dcaenc to the selected HDMI port.

### 2. `~/.config/pipewire/pipewire.conf.d/60-dts-live.conf`
PipeWire adapter sink configuration that:
- Connects ALSA's dcaenc PCM to PipeWire
- Sets 5.1 channel configuration
- Specifies proper channel mapping (FL, FR, RL, RR, FC, LFE)
- Configures buffer settings and priority

### 3. `~/.config/wireplumber/wireplumber.conf.d/51-default-targets.conf`
WirePlumber settings to restore the DTS sink as the default after restarts.

## Troubleshooting

### DTS sink appears in `wpctl status` but no sound

1. **Verify ALSA path directly:**
   ```bash
   speaker-test -D dcahdmi:CARD=Generic,DEV=2 -c 6 -r 48000 -F S16_LE
   ```
   (Replace `DEV=2` with the device number you selected)

2. **Check PipeWire logs:**
   ```bash
   journalctl --user -u pipewire -n 50 --follow
   ```

3. **Verify game output settings:**
   - Set game audio to 5.1 / Surround / Home Theater in game settings
   - Ensure game is fully relaunched after sink creation

### DTS sink not found after installation

1. **Check if ALSA plugin installed correctly:**
   ```bash
   ls -la /usr/lib/alsa-lib/libasound_module_pcm_dca.so
   ```
   Should exist and be readable.

2. **Verify dcaenc was built:**
   ```bash
   which dcaenc
   dcaenc --version
   ```

3. **Check PipeWire events:**
   ```bash
   journalctl --user -e | grep -i "dts\|adapter\|pcm"
   ```

4. **Try manual PipeWire restart:**
   ```bash
   systemctl --user restart pipewire pipewire-pulse wireplumber
   sleep 2
   wpctl status
   ```

### HDMI outputs not detected

```bash
# Verify HDMI detection
aplay -l

# Must show HDMI lines like:
# card 0, device 3: HDMI 0 [HDMI 0]
# card 0, device 8: HDMI 2 [LG TV RVU]
```

If nothing shows, your HDMI device may not be properly detected by PulseAudio/ALSA.

### Build fails during dcaenc compilation

1. **Ensure packages are up to date:**
   ```bash
   sudo pacman -Syu
   sudo pacman -S --needed --overwrite='*' alsa-lib linux-api-headers
   ```

2. **Try rebuilding:**
   ```bash
   ./install.sh --dry-run -v  # Preview
   ./install.sh -v            # Run with verbose output
   ```

3. **Check gcc:**
   ```bash
   gcc --version
   which gcc
   ```

## Usage in Game Mode

Once installed, the DTS sink works in both **Desktop Mode** and **Game Mode**:

1. Launch a game
2. Go to game audio settings
3. Set output to **5.1 / Surround Sound / Home Theater**
4. Confirm audio comes through
5. Check your AVR for DTS signal indicator

⚠️ **Important:** If a game was already running when you installed/reconfigured, fully close and relaunch the game for audio routing to take effect.

## Reconfiguration

To change which HDMI port the DTS sink uses (e.g., switching from TV to AVR):

```bash
./install.sh --reconfigure
```

This will:
- Skip rebuilding dcaenc (already installed)
- Prompt for a new HDMI output
- Write new configuration files
- Restart PipeWire

Much faster than a full reinstall.

## Uninstallation

To remove the DTS configuration and revert to normal audio:

```bash
./uninstall.sh
```

This removes:
- `~/.asoundrc`
- `~/.config/pipewire/pipewire.conf.d/60-dts-live.conf`
- `~/.config/wireplumber/wireplumber.conf.d/51-default-targets.conf`

Then restarts PipeWire to apply changes.

**Note:** The `dcaenc` ALSA plugin files remain installed in `/usr`. To fully remove them:

```bash
sudo rm /usr/lib/alsa-lib/libasound_module_pcm_dca.so
sudo rm /usr/share/alsa/pcm/dca.conf
sudo ldconfig
```

## Known Limitations

- **Single output support:** Currently configures one HDMI port per setup (can reconfigure for another)
- **5.1 only:** Sink is configured for 5.1 surround; 7.1 not yet tested
- **Real-time encoding:** DTS encoding happens in real-time, CPU usage is negligible but GPU remains available
- **SteamOS specific:** Designed for Steam Deck; may work on generic SteamOS but untested

## Technical Notes

### Why dcaenc?

DTS encoding on Linux typically requires proprietary libraries. The `dcaenc` project provides an open-source encoder that creates valid DTS bitstreams. Games route their 5.1 PCM audio to this encoder, which outputs DTS over HDMI.

### PipeWire vs Pulse

This uses PipeWire directly rather than PulseAudio's `module-alsa-sink` because:
- More reliable configuration
- Better channel mapping support
- Native support for custom PCMs
- SteamOS 3.x uses PipeWire as default

### Channel Mapping

The sink uses: `[ FL FR RL RR FC LFE ]` (Front-Left, Front-Right, Rear-Left, Rear-Right, Front-Center, LFE/Subwoofer)

This ensures proper 5.1 routing from games to the AVR.

## Contributing

Contributions welcome! Please:

1. Test on actual Steam Deck hardware
2. Report issues with HDMI model info and SteamOS version
3. Submit PRs with improvements to scripts or documentation

## License

MIT License

Copyright (c) 2026

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## References

- [dcaenc GitLab](https://gitlab.com/patrakov/dcaenc)
- [PipeWire Configuration](https://pipewire.readthedocs.io/)
- [WirePlumber](https://pipewire.pages.freedesktop.org/wireplumber/)
- [Steam Deck](https://www.steampowered.com/steamdeck)