#!/usr/bin/env bash
set -euo pipefail

# --- Projekt / Upstream ---
PKG="snd-hda-codec-cs8409"
UPSTREAM_URL="https://github.com/davidjo/snd_hda_macbookpro.git"
DEFAULT_REF="master"

# --- Pfade im Repo ---
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${REPO_ROOT}/upstream"

# --- Helfer ---
blue(){ printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m[!]\033[0m  %s\n' "$*"; }
err(){  printf '\033[1;31m[✗]\033[0m %s\n' "$*" >&2; }

install_deps() {
  # prüfe und installiere fehlende Tools: git dkms rsync sed
  local missing=()
  for pkg in git dkms rsync sed; do
    command -v "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
  done

  if ((${#missing[@]} == 0)); then
    blue "Alle Abhängigkeiten vorhanden: git dkms rsync sed"
    return
  fi

  warn "Fehlende Abhängigkeiten: ${missing[*]}"

  if command -v apt-get >/dev/null 2>&1; then
    blue "Installiere via apt-get: ${missing[*]}"
    sudo apt-get update
    sudo apt-get install -y "${missing[@]}"
  elif command -v dnf >/dev/null 2>&1; then
    blue "Installiere via dnf: ${missing[*]}"
    sudo dnf install -y "${missing[@]}"
  elif command -v zypper >/dev/null 2>&1; then
    blue "Installiere via zypper: ${missing[*]}"
    sudo zypper install -y "${missing[@]}"
  elif command -v pacman >/dev/null 2>&1; then
    blue "Installiere via pacman: ${missing[*]}"
    sudo pacman -S --needed "${missing[@]}"
  else
    err "Kein unterstützter Paketmanager gefunden – bitte ${missing[*]} manuell installieren."
    exit 1
  fi
}

# --- 0) Abhängigkeiten sicherstellen ---
install_deps

# echten Benutzer ermitteln (für chown des Arbeitsordners)
owner_of_repo="$(stat -c %U "${REPO_ROOT}" 2>/dev/null || stat -f %Su "${REPO_ROOT}" 2>/dev/null || echo "")"
if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
  REALUSER="${SUDO_USER}"
elif [[ -n "${owner_of_repo}" && "${owner_of_repo}" != "root" ]]; then
  REALUSER="${owner_of_repo}"
else
  REALUSER="${USER}"
fi

# --- 1) Upstream frisch klonen ---
blue "Klonen von Upstream (${DEFAULT_REF}) nach ${WORK_DIR}"
sudo rm -rf "${WORK_DIR}"
mkdir -p "${WORK_DIR}"
sudo chown -R "${REALUSER}:${REALUSER}" "${WORK_DIR}"
sudo -u "${REALUSER}" git clone --depth 1 --branch "${DEFAULT_REF}" "${UPSTREAM_URL}" "${WORK_DIR}"

# --- 2) Version ableiten (Datums-Suffix + Kurz-SHA des Upstream-Commits) ---
SHORTSHA="$(sudo -u "${REALUSER}" git -C "${WORK_DIR}" rev-parse --short=7 HEAD)"
DATE="$(date +%Y%m%d)"
PKG_VERSION="1.0+${DATE}-${SHORTSHA}"
blue "Version: ${PKG_VERSION}"

# --- 3) Alte DKMS-Versionen ausräumen ---
blue "Entferne evtl. vorhandene DKMS-Versionen von ${PKG}"
while read -r line; do
  ver="${line#${PKG}/}"; ver="${ver%%,*}"
  [[ -z "$ver" ]] && continue
  blue " - dkms remove ${PKG}/${ver}"
  sudo dkms remove -m "${PKG}" -v "${ver}" --all || true
  sudo rm -rf "/usr/src/${PKG}-${ver}" || true
done < <(dkms status | grep "^${PKG}/" || true)
sudo rm -rf "/var/lib/dkms/${PKG}" || true

# --- 4) DKMS-Quellenbaum bereitstellen (/usr/src/<name>-<version>) ---
DKMS_SRC="/usr/src/${PKG}-${PKG_VERSION}"
blue "Spiegele Upstream nach ${DKMS_SRC}"
sudo rm -rf "${DKMS_SRC}"
sudo mkdir -p "${DKMS_SRC}"
sudo rsync -a --delete --exclude ".git" "${WORK_DIR}/" "${DKMS_SRC}/"

# --- 5) dkms.conf setzen ---
# Falls Upstream KEINE dkms.conf hat, nimm die eigene aus dem Repo-Stamm
if [[ ! -f "${DKMS_SRC}/dkms.conf" ]]; then
  if [[ -f "${REPO_ROOT}/dkms.conf" ]]; then
    blue "Übernehme eigene dkms.conf aus dem Repo"
    sudo install -m 0644 "${REPO_ROOT}/dkms.conf" "${DKMS_SRC}/dkms.conf"
  else
    err "Keine dkms.conf gefunden (weder Upstream noch Repo). Abbruch."
    exit 2
  fi
fi

# PACKAGE_VERSION in dkms.conf auf die dynamische ${PKG_VERSION} setzen
sudo sed -i -E "s/^PACKAGE_VERSION=\"[^\"]*\"/PACKAGE_VERSION=\"${PKG_VERSION}\"/" "${DKMS_SRC}/dkms.conf"

# Sicherheit: BUILT_MODULE_LOCATION ergänzen, wenn nicht vorhanden
# (Viele Upstream-Builds legen das .ko unter build/hda/ ab)
if ! grep -q "^BUILT_MODULE_LOCATION\[0\]=" "${DKMS_SRC}/dkms.conf"; then
  echo 'BUILT_MODULE_LOCATION[0]="build/hda"' | sudo tee -a "${DKMS_SRC}/dkms.conf" >/dev/null
fi

# --- 6) DKMS add/build/install ---
blue "DKMS add/build/install"
sudo dkms add -m "${PKG}" -v "${PKG_VERSION}" || true
sudo dkms build -m "${PKG}" -v "${PKG_VERSION}"
sudo dkms install -m "${PKG}" -v "${PKG_VERSION}"

# --- 7) Modul-Cache & Module neu laden ---
blue "depmod & Module neu laden"
sudo depmod -a
sudo modprobe -r snd_hda_codec_cs8409 2>/dev/null || true
sudo modprobe snd_hda_intel 2>/dev/null || true
sudo modprobe snd_hda_codec_cs8409 2>/dev/null || true

blue "Fertig: ${PKG}-${PKG_VERSION}"
echo "Hinweis:"
echo " - Effektive dkms.conf unter: ${DKMS_SRC}/dkms.conf"
echo " - Build-Log: /var/lib/dkms/${PKG}/${PKG_VERSION}/build/make.log"

# --- 8) Aufräumen: Upstream-Ordner löschen ---
if [[ -d "${WORK_DIR}" ]]; then
  blue "Entferne temporären Upstream-Ordner: ${WORK_DIR}"
  sudo rm -rf "${WORK_DIR}"
fi
