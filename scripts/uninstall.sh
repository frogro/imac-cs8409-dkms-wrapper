#!/usr/bin/env bash
# Uninstall DKMS package cs8409-dkms
set -euo pipefail
PKG="cs8409-dkms"
VER="$(cat "$(dirname "$0")/../VERSION")"
if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] Please run as root (use sudo)." >&2
  exit 1
fi

echo "==> Unloading module (if loaded)"
modprobe -r snd_hda_codec_cs8409 2>/dev/null || true

echo "==> Removing DKMS build/install"
dkms remove -m "${PKG}" -v "${VER}" --all || true

echo "==> Removing sources from /usr/src/${PKG}-${VER}"
rm -rf "/usr/src/${PKG}-${VER}"

echo "==> Done."
