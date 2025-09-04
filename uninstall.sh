#!/usr/bin/env bash
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Wenn wir innerhalb des Repos (mit scripts/) laufen → echtes Uninstall-Script aufrufen
if [[ -f "${SELF_DIR}/scripts/uninstall.sh" ]]; then
  exec "${SELF_DIR}/scripts/uninstall.sh" "$@"
fi

# Bootstrap-Fall: entferne lokal installierte DKMS-Version(en), ohne Repo zu klonen
PKG="cs8409-dkms"
MOD="snd-hda-codec-cs8409"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Fehlt: $1"; exit 2; }; }
need dkms

echo "[*] Entferne Kernelmodul (falls geladen) …"
sudo modprobe -r "${MOD}" 2>/dev/null || true

echo "[*] Entferne alle installierten DKMS-Versionen von ${PKG} …"
while read -r line; do
  ver="$(sed -E 's/^.*cs8409-dkms\/([^, ]+).*$/\1/' <<<"$line")"
  [[ -n "${ver}" ]] && sudo dkms remove -m "${PKG}" -v "${ver}" --all || true
done < <(dkms status | grep -E '^cs8409-dkms/')

sudo depmod -a || true
echo "[+] Entfernt."
