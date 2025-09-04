#!/usr/bin/env bash
set -euo pipefail

PKG="cs8409-dkms"
MODNAME="snd-hda-codec-cs8409"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KREL="$(uname -r)"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Fehlt: $1"; exit 2; }; }

need dkms
need make

if ! dpkg -s "linux-headers-${KREL}" >/dev/null 2>&1; then
  echo "Installiere Kernel-Header für ${KREL}…"
  sudo apt-get update -y
  sudo apt-get install -y "linux-headers-${KREL}"
fi

VERSION="0.0.0"
[[ -f "${ROOT}/VERSION" ]] && VERSION="$(tr -d '\n\r' < "${ROOT}/VERSION")"

echo "[*] Registriere ${PKG}/${VERSION} bei DKMS aus ${ROOT}"
# Sauberer Remove gleicher Version (falls vorher probiert)
if dkms status | grep -q "^${PKG}/${VERSION}"; then
  sudo dkms remove -m "${PKG}" -v "${VERSION}" --all || true
fi

# Add/Build/Install
sudo dkms add    -m "${PKG}" -v "${VERSION}" -k "${KREL}" -q --verbose || sudo dkms add -m "${PKG}" -v "${VERSION}" -q
sudo dkms build  -m "${PKG}" -v "${VERSION}"
sudo dkms install -m "${PKG}" -v "${VERSION}" --force

echo "[+] Fertig: ${PKG}/${VERSION} installiert."
echo "    Prüfen:  modinfo ${MODNAME} | head"
echo "             lsmod | grep ${MODNAME} || sudo modprobe ${MODNAME}"
EOF
chmod +x scripts/install.sh

scripts/uninstall.sh (neu)

cat > scripts/uninstall.sh <<'EOF'
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
EOF
chmod +x scripts/uninstall.sh

Top-Level Wrapper (falls überschrieben/fehlt)
install.sh

cat > install.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec "$(cd "$(dirname "$0")" && pwd)/scripts/install.sh" "$@"
