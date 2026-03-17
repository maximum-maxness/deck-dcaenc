#!/usr/bin/env bash
set -euo pipefail

choose_hdmi_output() {
  local choice

  log_verbose "Detecting HDMI outputs..."
  mapfile -t lines < <(aplay -l | grep -E 'device [0-9]+: HDMI' || echo "")

  if [[ "${#lines[@]}" -eq 0 ]]; then
    log_error "No HDMI playback devices found."
    log_error "Please ensure an HDMI device is connected and detected."
    log_error "Run 'aplay -l' to see available devices."
    exit 1
  fi

  log_verbose "Found ${#lines[@]} HDMI output(s)"

  echo "========================================" >&2
  echo "Detected HDMI Outputs" >&2
  echo "========================================" >&2
  echo >&2

  local i=0
  local -a alsa_dev_map  # Map aplay -l index to ALSA DEV number
  
  for line in "${lines[@]}"; do
    local label hdmi_num
    # Extract HDMI number: "HDMI 0" -> "0", "HDMI 1" -> "1"
    hdmi_num="$(sed -E 's/^.*HDMI ([0-9]+).*/\1/' <<<"$line")"
    # Extract label: "card 0, device 3: HDMI 0 [LG TV RVU]" -> "LG TV RVU"
    label="$(sed -E 's/^.*\[(.*)\].*$/\1/' <<<"$line")"
    # If no bracket label found, use the HDMI number
    if [[ "$label" == "$line" ]]; then
      label="HDMI $hdmi_num"
    fi
    # Store the HDMI DEV number (HDMI 0 -> DEV 0, HDMI 1 -> DEV 1, etc)
    alsa_dev_map[$i]="$hdmi_num"
    printf "  [%d] %s\n" "$i" "$label" >&2
    ((i+=1))
  done

  echo >&2
  read -r -p "Choose HDMI output index (0-$((${#lines[@]} - 1))): " choice >&2

  if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 0 || choice >= ${#lines[@]} )); then
    log_error "Invalid selection: $choice"
    exit 1
  fi

  # Get the ALSA DEV number (which corresponds to HDMI N)
  local selected_dev="${alsa_dev_map[$choice]}"
  local selected_label
  selected_label="$(sed -E 's/^.*\[(.*)\].*$/\1/' <<<"${lines[$choice]}")"
  if [[ "$selected_label" == "${lines[$choice]}" ]]; then
    selected_label="HDMI $selected_dev"
  fi

  log_info "Selected: $selected_label (ALSA DEV=$selected_dev)"
  printf '%s\n' "$selected_dev"
}