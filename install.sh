#!/usr/bin/env bash
set -euo pipefail

REPO_SLUG="frogro/cs8409-dkms-wrapper"
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Wenn wir innerhalb des Repos (mit module/src) laufen → direkt das echte Installer-Script aufrufen
if [[ -d "${SELF_DIR}/module/src" && -f "${SELF_DIR}/scripts/install.sh" ]]; then
  exec "${SELF_DIR}/scripts/install.sh" "$@"
fi

# Andernfalls: Bootstrap – lade das Repo frisch herunter und führe dort aus
need() { command -v "$1" >/dev/null 2>&1 || { echo "Fehlt: $1"; exit 2; }; }
need curl

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "[*] Lade aktuelles Repo herunter …"
curl -fsSL "https://codeload.github.com/${REPO_SLUG}/zip/refs/heads/main" -o "${TMP}/repo.zip"

echo "[*] Entpacke …"
unz() { command -v unzip >/dev/null 2>&1 && unzip -q "$@"; }
if unz "${TMP}/repo.zip" -d "${TMP}"; then
  :
else
  # Fallback ohne unzip: nutzt tar (GNU tar kann Zip lesen)
  tar -xf "${TMP}/repo.zip" -C "${TMP}"
fi

# Der entpackte Ordner heißt <repo>-main
SRC_DIR="$(find "${TMP}" -maxdepth 1 -type d -name '*cs8409-dkms-wrapper*' | head -n1)"
if [[ -z "${SRC_DIR}" ]]; then
  echo "Fehler: Entpacktes Repo nicht gefunden."
  exit 1
fi

echo "[*] Starte Installation aus ${SRC_DIR}"
exec "${SRC_DIR}/scripts/install.sh" "$@"
