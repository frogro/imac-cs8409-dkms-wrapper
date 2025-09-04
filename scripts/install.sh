#!/usr/bin/env bash
# DKMS installer for cs8409-dkms (DKMS package) building module snd-hda-codec-cs8409
set -euo pipefail

PKG="cs8409-dkms"
VER="$(cat "$(dirname "$0")/../VERSION")"
SRC_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
USR_SRC="/usr/src/${PKG}-${VER}"

if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] Please run as root (use sudo)." >&2
  exit 1
fi

echo "==> Installing build prerequisites (dkms, headers, toolchain)"
if command -v apt-get >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y dkms build-essential "linux-headers-$(uname -r)"
elif command -v dnf >/dev/null 2>&1; then
  dnf install -y dkms kernel-devel "kernel-devel-$(uname -r)" @development-tools || true
elif command -v pacman >/dev/null 2>&1; then
  pacman -Sy --noconfirm dkms base-devel linux-headers || true
fi

echo "==> Staging sources into ${USR_SRC}"
rm -rf "${USR_SRC}"
install -d "${USR_SRC}"
# Copy dkms.conf, module tree, and VERSION
install -m 0644 "${SRC_ROOT}/dkms.conf" "${USR_SRC}/"
install -d "${USR_SRC}/module"
cp -a "${SRC_ROOT}/module/." "${USR_SRC}/module/"
install -m 0644 "${SRC_ROOT}/VERSION" "${USR_SRC}/"

echo "==> Register with DKMS"
dkms remove -m "${PKG}" -v "${VER}" --all >/dev/null 2>&1 || true
dkms add -m "${PKG}" -v "${VER}"

echo "==> Build via DKMS"
dkms build -m "${PKG}" -v "${VER}"

echo "==> Install the module into the running kernel"
dkms install -m "${PKG}" -v "${VER}"

echo "==> Done. You can now load the module:"
echo "    sudo modprobe snd_hda_codec_cs8409"
echo "    # check: dmesg | grep -i cs8409"
