#!/usr/bin/env bash
set -euo pipefail

build_and_install_dcaenc() {
  local build_root="$1"
  local src_dir="$build_root/dcaenc"

  mkdir -p "$build_root"

  log_info "Preparing build directory: $build_root"
  log_verbose "Source directory will be: $src_dir"

  if [[ ! -d "$src_dir/.git" ]]; then
    log_info "Cloning dcaenc from GitLab..."
    rm -rf "$src_dir" 2>/dev/null || true
    if [[ "$DRY_RUN" != "1" ]]; then
      git clone https://gitlab.com/patrakov/dcaenc.git "$src_dir" 2>&1 | grep -v "^Cloning" || true
    fi
  else
    log_info "Updating existing dcaenc repository..."
    if [[ "$DRY_RUN" != "1" ]]; then
      git -C "$src_dir" fetch --all 2>&1 | grep -v "^From " || true
      git -C "$src_dir" reset --hard origin/master || {
        log_verbose "Could not reset to origin/master, trying main branch"
        git -C "$src_dir" reset --hard origin/main || true
      }
      git -C "$src_dir" clean -fdx >/dev/null 2>&1 || true
    fi
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[DRY RUN] Would build and install dcaenc from $src_dir"
    return
  fi

  log_info "Building dcaenc..."
  pushd "$src_dir" >/dev/null

  rm -f ltmain.sh
  make distclean 2>/dev/null || true

  log_verbose "Running autoreconf..."
  autoreconf -f -i -v 2>&1 | tail -3 || true

  log_verbose "Running configure..."
  ./configure --prefix=/usr --libdir=/usr/lib >/dev/null 2>&1

  log_verbose "Compiling with $(nproc) jobs..."
  make -j"$(nproc)" >/dev/null 2>&1

  log_info "Installing dcaenc..."
  sudo make install >/dev/null 2>&1
  sudo ldconfig >/dev/null 2>&1

  popd >/dev/null

  # Verify installation
  if [[ ! -f /usr/lib/alsa-lib/libasound_module_pcm_dca.so ]]; then
    log_error "dcaenc ALSA plugin was not installed correctly."
    log_error "Expected: /usr/lib/alsa-lib/libasound_module_pcm_dca.so"
    exit 1
  fi

  log_verbose "dcaenc ALSA plugin verified at /usr/lib/alsa-lib/libasound_module_pcm_dca.so"
  log_info "dcaenc build and install complete"
}