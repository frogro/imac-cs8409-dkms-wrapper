#!/usr/bin/env bash
set -euo pipefail

# DKMS Paket- und Modulnamen
PKG="cs8409-dkms"
MODNAME="snd-hda-codec-cs8409"

# Repo-Root = Verzeichnis dieser Datei/../
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Voraussetzungen
if ! command -v dkms >/dev/null 2>&1; then
  echo "Fehler: dkms nicht gefunden. Bitte 'sudo apt install dkms build-essential linux-headers-$(uname -r)' ausführen." >&2
  exit 1
fi

# Version aus VERSION lesen (Fallback 0.0.0)
VERSION="0.0.0"
if [[ -f "${ROOT}/VERSION" ]]; then
  VERSION="$(tr -d '\n\r' < "${ROOT}/VERSION")"
fi

echo "[*] Installiere DKMS-Paket ${PKG} v${VERSION}"

# Aufräumen evtl. ältere Einträge der gleichen Version
if dkms status | grep -q "^${PKG}/${VERSION}"; then
  echo "[*] Entferne bereits registriertes ${PKG}/${VERSION}"
  sudo dkms remove -m "${PKG}" -v "${VERSION}" --all || true
fi

# Registrieren
sudo dkms add -m "${PKG}" -v "${VERSION}" -k "$(uname -r)" -q --verbose || \
sudo dkms add -m "${PKG}" -v "${VERSION}" -q

# Bauen
sudo dkms build -m "${PKG}" -v "${VERSION}"

# Installieren
sudo dkms install -m "${PKG}" -v "${VERSION}" --force

echo "[+] Fertig. Modul sollte nun unter /lib/modules/$(uname -r)/{updates,extra}/dkms/${MODNAME}.ko liegen."
echo "    Test: 'modinfo ${MODNAME}' und 'lsmod | grep ${MODNAME}'"
