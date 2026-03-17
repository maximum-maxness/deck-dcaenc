#!/usr/bin/env bash
set -euo pipefail

write_asoundrc() {
  local dev="$1"

  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[DRY RUN] Would write ~/.asoundrc with DEV=$dev"
    return
  fi

  mkdir -p "$HOME"
  log_info "Writing ~/.asoundrc..."

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

  log_verbose "Created: $HOME/.asoundrc"
}

write_pipewire_sink_config() {
  local dev="$1"

  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[DRY RUN] Would write PipeWire config with DEV=$dev"
    return
  fi

  local config_dir="$HOME/.config/pipewire/pipewire.conf.d"
  mkdir -p "$config_dir"
  
  log_info "Writing PipeWire DTS sink configuration..."

  cat > "$config_dir/60-dts-live.conf" <<EOF
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

  log_verbose "Created: $config_dir/60-dts-live.conf"
}

write_wireplumber_restore_config() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[DRY RUN] Would write WirePlumber restore config"
    return
  fi

  local config_dir="$HOME/.config/wireplumber/wireplumber.conf.d"
  mkdir -p "$config_dir"
  
  log_info "Writing WirePlumber default target restore configuration..."

  cat > "$config_dir/51-default-targets.conf" <<'EOF'
wireplumber.settings = {
  node.restore-default-targets = true
}
EOF

  log_verbose "Created: $config_dir/51-default-targets.conf"
}