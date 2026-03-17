# Steam Deck DTS Live

Interactive installer for real-time DTS encoding on Steam Deck using `dcaenc`, ALSA, PipeWire, and WirePlumber.

## Features

- Builds and installs `dcaenc`
- Detects HDMI outputs
- Lets you choose the target TV / AVR
- Creates a PipeWire DTS sink
- Sets the DTS sink as default
- Works with games that output 5.1 audio

## Requirements

- Steam Deck / SteamOS
- Desktop Mode
- sudo password set
- HDMI-connected TV / AVR

## Install

```bash
git clone https://github.com/YOURNAME/steamdeck-dts-live.git
cd steamdeck-dts-live
chmod +x install.sh uninstall.sh
./install.sh
```

## Test

```bash
wpctl status
speaker-test -D default -c 6 -r 48000 -F S16_LE
```

## Notes

- Games may need to be restarted after the default sink changes.
- In-game audio should be set to 5.1 / Surround / Home Theater.
- SteamOS updates may require reinstalling the `dcaenc` plugin.