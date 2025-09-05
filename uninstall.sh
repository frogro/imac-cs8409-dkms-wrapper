#!/usr/bin/env bash
set -euo pipefail

PKG="snd-hda-codec-cs8409"

blue(){ printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m[!]\033[0m  %s\n' "$*"; }
info(){ printf ' - %s\n' "$*"; }

blue "Entlade Kernelmodul (falls geladen)"
sudo modprobe -r snd_hda_codec_cs8409 2>/dev/null || true
# Hinweis: snd_hda_intel wird bewusst nicht entladen, da es andere Geräte betreffen kann.

blue "Entferne DKMS-Instanzen von ${PKG}"
found_any=false
while read -r line; do
  # erwartet Format wie: snd-hda-codec-cs8409/<version>, <kernel-xyz>, <status>
  ver="${line#${PKG}/}"; ver="${ver%%,*}"
  [[ -z "$ver" || "$ver" == "$line" ]] && continue
  found_any=true
  info "dkms remove ${PKG}/${ver}"
  sudo dkms remove -m "${PKG}" -v "${ver}" --all || true
  info "lösche /usr/src/${PKG}-${ver}"
  sudo rm -rf "/usr/src/${PKG}-${ver}" || true
done < <(dkms status 2>/dev/null | grep "^${PKG}/" || true)

if ! $found_any; then
  warn "Keine DKMS-Instanzen von ${PKG} gefunden."
fi

blue "Räume DKMS-Cache auf (falls vorhanden)"
sudo rm -rf "/var/lib/dkms/${PKG}" || true

blue "Aktualisiere Modul-Datenbank (depmod)"
sudo depmod -a

blue "Deinstallation abgeschlossen."
echo "Hinweis:"
echo " - Falls Audio nach dem Entfernen nicht erwartungsgemäß funktioniert,"
echo "   kann ein Neustart sinnvoll sein (insbesondere wenn snd_hda_intel weiter genutzt wird)."
