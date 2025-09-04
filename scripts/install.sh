#!/usr/bin/env bash
set -euo pipefail

PKG="cs8409-dkms"
MOD="snd-hda-codec-cs8409"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KREL="$(uname -r)"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Fehlt: $1"; exit 2; }; }
need dkms
need make

# Dependencies (Header)
if ! dpkg -s "linux-headers-${KREL}" >/dev/null 2>&1; then
  echo "[*] Installiere Kernel-Header für ${KREL} …"
  sudo apt-get update -y
  sudo apt-get install -y "linux-headers-${KREL}"
fi

# Version aus VERSION-Datei
if [[ -f "${ROOT}/VERSION" ]]; then
  VERSION="$(tr -d '\n\r' < "${ROOT}/VERSION")"
else
  echo "Fehler: VERSION-Datei fehlt."
  exit 1
fi

SRC_DST="/usr/src/${PKG}-${VERSION}"

echo "[*] Bereite /usr/src vor: ${SRC_DST}"
sudo rm -rf "${SRC_DST}"
sudo mkdir -p "${SRC_DST}"
# Wir kopieren nur, was DKMS zum Bauen braucht:
sudo cp -a "${ROOT}/module" "${SRC_DST}/"
sudo install -m 0644 /dev/stdin "${SRC_DST}/dkms.conf" <<EOF
PACKAGE_NAME="${PKG}"
PACKAGE_VERSION="${VERSION}"

BUILT_MODULE_NAME[0]="${MOD}"
# Die .ko entsteht durch 'make -C module' unter module/src/
BUILT_MODULE_LOCATION[0]="module/src"
DEST_MODULE_LOCATION[0]="/updates"

MAKE[0]="make -C module KERNELRELEASE=\${kernelver}"
CLEAN="make -C module clean"

AUTOINSTALL="yes"
EOF

echo "[*] Registriere DKMS ${PKG}/${VERSION}"
# Sauberer Remove gleicher Version (idempotent)
sudo dkms remove -m "${PKG}" -v "${VERSION}" --all >/dev/null 2>&1 || true

sudo dkms add -m "${PKG}" -v "${VERSION}"
sudo dkms build -m "${PKG}" -v "${VERSION}"
sudo dkms install -m "${PKG}" -v "${VERSION}" --force

echo "[*] Lade Modul (falls nicht automatisch) …"
sudo modprobe "${MOD}" 2>/dev/null || true

echo
echo "[+] Fertig: ${PKG}/${VERSION} installiert."
echo "    Prüfen:"
echo "      modinfo ${MOD} | head"
echo "      lsmod | grep ${MOD} || echo '(noch nicht geladen)'"
