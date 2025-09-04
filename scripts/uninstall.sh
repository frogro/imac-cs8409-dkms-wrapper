#!/usr/bin/env bash
set -euo pipefail

PKG="cs8409-dkms"
MOD="snd-hda-codec-cs8409"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Fehlt: $1"; exit 2; }; }
need dkms

if [[ -f "${ROOT}/VERSION" ]]; then
  VERSION="$(tr -d '\n\r' < "${ROOT}/VERSION")"
else
  # Fallback: entferne alle installierten Versionen
  VERSION=""
fi

echo "[*] Entlade Modul (falls aktiv) …"
sudo modprobe -r "${MOD}" 2>/dev/null || true

if [[ -n "${VERSION}" ]]; then
  echo "[*] Entferne ${PKG}/${VERSION} aus DKMS …"
  sudo dkms remove -m "${PKG}" -v "${VERSION}" --all || true
else
  echo "[*] Entferne alle DKMS-Versionen von ${PKG} …"
  while read -r line; do
    ver="$(sed -E 's/^.*cs8409-dkms\/([^, ]+).*$/\1/' <<<"$line")"
    [[ -n "${ver}" ]] && sudo dkms remove -m "${PKG}" -v "${ver}" --all || true
  done < <(dkms status | grep -E '^cs8409-dkms/')
fi

sudo depmod -a || true
echo "[+] Entfernt."
