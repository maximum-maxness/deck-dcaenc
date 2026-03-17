#!/usr/bin/env bash
set -euo pipefail

build_and_install_dcaenc() {
  local build_root="$1"
  local src_dir="$build_root/dcaenc"

  mkdir -p "$build_root"

  if [[ ! -d "$src_dir/.git" ]]; then
    git clone https://gitlab.com/patrakov/dcaenc.git "$src_dir"
  else
    git -C "$src_dir" pull --ff-only
  fi

  pushd "$src_dir" >/dev/null
  make distclean 2>/dev/null || true
  autoreconf -f -i -v
  ./configure --prefix=/usr --libdir=/usr/lib
  make -j"$(nproc)"
  sudo make install
  sudo ldconfig
  popd >/dev/null

  if [[ ! -f /usr/lib/alsa-lib/libasound_module_pcm_dca.so ]]; then
    echo "dcaenc ALSA plugin was not installed correctly." >&2
    exit 1
  fi
}