#!/usr/bin/env bash
set -euo pipefail

choose_hdmi_output() {
  mapfile -t lines < <(aplay -l | grep -E 'device [0-9]+: HDMI')
  if [[ "${#lines[@]}" -eq 0 ]]; then
    echo "No HDMI playback devices found." >&2
    exit 1
  fi

  echo
  echo "Detected HDMI outputs:"
  local i=0
  for line in "${lines[@]}"; do
    local label
    label="$(sed -E 's/^.*device [0-9]+: HDMI [0-9]+ \[(.*)\].*$/\1/' <<<"$line")"
    printf "  [%d] %s\n" "$i" "$label"
    ((i+=1))
  done

  echo
  read -r -p "Choose HDMI output index: " choice

  if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 0 || choice >= ${#lines[@]} )); then
    echo "Invalid selection." >&2
    exit 1
  fi

  echo "$choice"
}