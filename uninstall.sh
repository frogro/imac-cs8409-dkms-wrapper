#!/usr/bin/env bash
set -euo pipefail

PKG="cs8409-dkms"
MODNAME="snd-hda-codec-cs8409"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

VERSION="0.0.0"
[[ -f "${ROOT}/VERSION" ]] && VERSION="$(tr -d '\n\r' < "${ROOT}/VERSION")"

echo "[*] Entferne ${PKG}/${VERSION} aus DKMS"
sudo modprobe -r "${MODNAME}" 2>/dev/null || true
sudo dkms remove -m "${PKG}" -v "${VERSION}" --all || true
sudo depmod -a || true
echo "[+] Entfernt."
