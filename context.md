Project context: Steam Deck real-time DTS encoder installer

Goal
- I want to build a GitHub repository that lets Steam Deck users easily install and configure a real-time DTS encoder sink for games.
- The end result should let SteamOS / PipeWire / WirePlumber route 5.1 game audio into dcaenc, then output DTS over HDMI to an older AVR/receiver.
- It should support Desktop Mode and Game Mode.
- It should prompt the user to choose the target HDMI output (TV / AVR), then generate the needed ALSA + PipeWire config automatically.

What we proved manually
1. dcaenc can be built and installed on Steam Deck.
2. The correct upstream source is:
   - https://gitlab.com/patrakov/dcaenc.git
   - The archived GitHub mirror was incomplete / not suitable because it did not install the ALSA plugin.
3. On Steam Deck, SteamOS package state may need repair:
   - alsa-lib reinstall restored /usr/lib/pkgconfig/alsa.pc
   - linux-api-headers reinstall restored /usr/include/linux/errno.h
4. Successful dcaenc build/install produces:
   - /usr/lib/alsa-lib/libasound_module_pcm_dca.so
   - /usr/share/alsa/pcm/dca.conf
5. ALSA direct DTS testing worked with:
   - speaker-test -D dcahdmi:CARD=Generic,DEV=2 -c 6 -r 48000 -F S16_LE
6. That only worked when PipeWire / wireplumber / pipewire-pulse were stopped, confirming the ALSA path itself was correct.
7. PipeWire integration now works with a custom PipeWire adapter sink.
8. The custom sink shows up as:
   - “DTS Live Sink”
   - s16le 6ch 48000Hz
9. Games now successfully route through the DTS sink, but there were channel-order quirks that were fixed by choosing the right PipeWire channel map.
10. speaker-test against default shows channels 2-5 as “Unknown”; that appears to be only a label issue, not an actual routing failure.
11. pw-play on stereo test clips only comes out of front speakers because the clips are stereo, not because the DTS sink is broken.

Current desired repo purpose
- A repo with scripts that automate the entire install/config flow for other Steam Deck users.
- Main user flow:
  1. Install dependencies
  2. Build/install dcaenc
  3. Detect HDMI outputs from aplay -l
  4. Prompt the user to choose one
  5. Write ~/.asoundrc
  6. Write ~/.config/pipewire/pipewire.conf.d/60-dts-live.conf
  7. Write a small WirePlumber config to restore default targets
  8. Restart PipeWire stack
  9. Detect the DTS sink
  10. Set it as default
  11. Print test instructions

Steam Deck / SteamOS specifics discovered
- SteamOS rootfs may be read-only; installer should call:
  - sudo steamos-readonly disable
- Required packages:
  - git
  - base-devel
  - autoconf
  - automake
  - libtool
  - alsa-lib
  - pkgconf
  - linux-api-headers
- In practice, installer also needed to repair:
  - sudo pacman -S --needed --overwrite='*' alsa-lib linux-api-headers
- After package repair:
  - pkg-config --modversion alsa -> worked
- Build/install target:
  - ./configure --prefix=/usr --libdir=/usr/lib
- Must verify:
  - /usr/lib/alsa-lib/libasound_module_pcm_dca.so exists after install

Important build pitfall already found
- Building dcaenc inside the installer repo tree caused autotools/libtool issues:
  - libtoolize put auxiliary files in parent dirs
  - configure.ac then failed with missing ./ltmain.sh
- Fix: build in a neutral temp directory, not inside the repo tree.
- Good build dir:
  - ${XDG_RUNTIME_DIR:-/tmp}/steamdeck-dts-live-build

Known working PipeWire sink config
- The PipeWire Pulse module-alsa-sink attempt failed / was unreliable for this custom ALSA PCM.
- The working approach is a PipeWire adapter sink in:
  - ~/.config/pipewire/pipewire.conf.d/60-dts-live.conf

Working sink config template
- Chosen HDMI output must be substituted into DEV=...
- Current tested example used DEV=2 for LG TV RVU.

Config content:

context.objects = [
    { factory = adapter
        args = {
            factory.name           = api.alsa.pcm.sink
            node.name              = "dts_live_sink"
            node.description       = "DTS Live Sink"
            media.class            = "Audio/Sink"

            device.api             = "alsa"
            device.class           = "sound"

            api.alsa.path          = "dcahdmi:CARD=Generic,DEV=2"
            api.alsa.pcm.card      = 0
            api.alsa.disable-mmap  = true
            node.pause-on-idle     = false

            audio.format           = "S16LE"
            audio.rate             = 48000
            audio.channels         = 6
            audio.position         = [ FL FR RL RR FC LFE ]

            priority.session       = 1200
        }
    }
]

Notes about this config
- api.alsa.pcm.card = 0 was important because PipeWire earlier complained:
  - “Could not determine card index, maybe set api.alsa...”
- The sink appeared successfully after restart with this config.
- The sink showed up in wpctl status as:
  - DTS Live Sink
- pactl showed:
  - Channel Map: front-left,front-right,rear-left,rear-right,front-center,lfe

Known working ~/.asoundrc template
- DEV must be substituted.

<confdir:pcm/dca.conf>

defaults.pcm.dca.iec61937 1

pcm.!default {
    type plug
    slave.pcm "dcahdmi:CARD=Generic,DEV=2"
}

ctl.!default {
    type hw
    card Generic
}

WirePlumber persistence config
- File:
  - ~/.config/wireplumber/wireplumber.conf.d/51-default-targets.conf
- Content:

wireplumber.settings = {
  node.restore-default-targets = true
}

How HDMI output selection should work
- Detect outputs from:
  - aplay -l
- Example output on tested Deck:
  - card 0, device 3: HDMI 0 [HDMI 0]
  - card 0, device 7: HDMI 1 [HDMI 1]
  - card 0, device 8: HDMI 2 [LG TV RVU]
  - card 0, device 9: HDMI 3 [HDMI 3]
- For the custom dcaenc devices, this mapped to:
  - dcahdmi:CARD=Generic,DEV=0
  - dcahdmi:CARD=Generic,DEV=1
  - dcahdmi:CARD=Generic,DEV=2
  - dcahdmi:CARD=Generic,DEV=3
- So the installer can present a numbered list of HDMI outputs and use the selected list index as DEV.

Important bug already found in installer
- A function like:
  - chosen_dev="$(choose_hdmi_output)"
  captures stdout.
- If the menu is printed to stdout inside choose_hdmi_output, the menu text gets swallowed into the variable and not shown properly.
- Fix:
  - Print menu / prompts to stderr
  - Print only the final selected value to stdout

Known script bug already found
- install.sh failed with:
  - restart_audio_stack: command not found
- Cause:
  - install.sh did not properly source lib/pipewire.sh or that file/function was missing.
- Need to ensure:
  - source "$REPO_DIR/lib/pipewire.sh"
  - and that file defines:
    - restart_audio_stack
    - wait_for_pipewire
    - find_dts_sink_id
    - set_default_sink

Desired repo structure
- steamdeck-dts-live/
  - README.md
  - LICENSE
  - install.sh
  - uninstall.sh
  - lib/common.sh
  - lib/build_dcaenc.sh
  - lib/detect_outputs.sh
  - lib/write_configs.sh
  - lib/pipewire.sh
  - templates/ (optional)
  - examples/ (optional)

Current script design
1. install.sh
- source helper libs
- check required commands
- sudo -v
- disable readonly root
- install deps
- repair core packages
- build/install dcaenc in temp dir
- prompt for HDMI output
- write configs
- restart PipeWire
- wait for PipeWire
- detect DTS sink
- set sink default
- print success / test instructions

2. lib/common.sh
- banner()
- require_command()
- ensure_sudo()
- disable_readonly_root()
- install_build_deps()
- repair_core_packages()

3. lib/build_dcaenc.sh
- clone/update gitlab upstream
- build in temp dir
- autoreconf -f -i -v
- ./configure --prefix=/usr --libdir=/usr/lib
- make -j"$(nproc)"
- sudo make install
- sudo ldconfig
- verify /usr/lib/alsa-lib/libasound_module_pcm_dca.so exists

4. lib/detect_outputs.sh
- parse aplay -l for HDMI lines
- print choices to stderr
- return only selected index to stdout

5. lib/write_configs.sh
- write ~/.asoundrc
- write ~/.config/pipewire/pipewire.conf.d/60-dts-live.conf
- write ~/.config/wireplumber/wireplumber.conf.d/51-default-targets.conf

6. lib/pipewire.sh
- restart_audio_stack()
- wait_for_pipewire()
- find_dts_sink_id() using wpctl status / awk
- set_default_sink() using wpctl set-default

Functional state reached manually
- DTS sink appears in wpctl status
- Example:
  - Sinks:
    - 34. DTS Live Sink [vol: 1.00]
- pactl list sinks short showed:
  - 34 dts_live_sink PipeWire s16le 6ch 48000Hz SUSPENDED
- Games launched afterward can output through DTS sink
- Receiver displayed DTS and channel tests worked
- Problem area now is packaging and making the installer robust

What I want Copilot to help with
- Fix and polish the Bash installer
- Make HDMI selection menu display reliably
- Ensure build occurs in temp dir
- Ensure helper functions are sourced correctly
- Improve error handling and logging
- Add uninstall.sh
- Improve README
- Potentially add:
  - --dry-run
  - --reconfigure
  - better output mapping verification
  - sanity checks for sink creation
  - friendlier user prompts

Specific implementation details to preserve
- Use the GitLab dcaenc upstream, not the archived GitHub mirror
- Use /usr prefix and /usr/lib libdir
- Use a PipeWire adapter sink, not the earlier failing pulse module approach
- Use:
  - audio.position = [ FL FR RL RR FC LFE ]
- Use:
  - api.alsa.pcm.card = 0
- Use:
  - api.alsa.disable-mmap = true
- Use:
  - node.pause-on-idle = false
- Use:
  - priority.session = 1200
- Set default sink with wpctl after creation
- Make the HDMI target configurable from installer selection

Example helper code already considered correct enough
- HDMI chooser should look roughly like:

choose_hdmi_output() {
  mapfile -t lines < <(aplay -l | grep -E 'device [0-9]+: HDMI')
  if [[ "${#lines[@]}" -eq 0 ]]; then
    echo "No HDMI playback devices found." >&2
    exit 1
  fi

  echo "========================================" >&2
  echo "Detected HDMI outputs" >&2
  echo "========================================" >&2

  local i=0
  for line in "${lines[@]}"; do
    local label
    label="$(sed -E 's/^.*device [0-9]+: HDMI [0-9]+ \[(.*)\].*$/\1/' <<<"$line")"
    printf "[%d] %s\n" "$i" "$label" >&2
    ((i+=1))
  done

  echo >&2
  read -r -p "Choose HDMI output index: " choice >&2

  if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 0 || choice >= ${#lines[@]} )); then
    echo "Invalid selection: $choice" >&2
    exit 1
  fi

  printf '%s\n' "$choice"
}

- PipeWire helper should define:

restart_audio_stack() {
  systemctl --user restart pipewire pipewire-pulse wireplumber
}

wait_for_pipewire() {
  local i
  for i in {1..20}; do
    if wpctl status >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.5
  done
  echo "PipeWire did not come up in time." >&2
  exit 1
}

find_dts_sink_id() {
  wpctl status | awk '
    /Sinks:/ { in_sinks=1; next }
    /Sources:/ { in_sinks=0 }
    in_sinks && /DTS Live Sink/ {
      gsub(/\./, "", $1)
      print $1
      exit
    }
  '
}

set_default_sink() {
  local sink_id="$1"
  wpctl set-default "$sink_id"
}

Current blocker in the repo work
- The installer still needs polishing and debugging:
  - output selection display
  - helper sourcing / function availability
  - general cleanup
- The underlying manual method is proven working.

Please help me turn this into a robust, clean, user-friendly GitHub repo with working Bash scripts and documentation.