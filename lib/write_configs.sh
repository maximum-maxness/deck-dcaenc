#!/usr/bin/env bash
set -euo pipefail

write_asoundrc() {
  local dev="$1"
  mkdir -p "$HOME"

  cat > "$HOME/.asoundrc" <<EOF
<confdir:pcm/dca.conf>

defaults.pcm.dca.iec61937 1

pcm.!default {
    type plug
    slave.pcm "dcahdmi:CARD=Generic,DEV=${dev}"
}

ctl.!default {
    type hw
    card Generic
}
EOF
}

write_pipewire_sink_config() {
  local dev="$1"
  mkdir -p "$HOME/.config/pipewire/pipewire.conf.d"

  cat > "$HOME/.config/pipewire/pipewire.conf.d/60-dts-live.conf" <<EOF
context.objects = [
    { factory = adapter
        args = {
            factory.name           = api.alsa.pcm.sink
            node.name              = "dts_live_sink"
            node.description       = "DTS Live Sink"
            media.class            = "Audio/Sink"

            device.api             = "alsa"
            device.class           = "sound"

            api.alsa.path          = "dcahdmi:CARD=Generic,DEV=${dev}"
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
EOF
}

write_wireplumber_restore_config() {
  mkdir -p "$HOME/.config/wireplumber/wireplumber.conf.d"

  cat > "$HOME/.config/wireplumber/wireplumber.conf.d/51-default-targets.conf" <<'EOF'
wireplumber.settings = {
  node.restore-default-targets = true
}
EOF
}