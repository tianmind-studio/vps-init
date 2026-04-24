#!/usr/bin/env bash
#
# vps-init installer.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/491034170/vps-init/main/install.sh | sudo bash
#
# Env:
#   VI_PREFIX   Install prefix for the CLI symlink. Default: /usr/local
#   VI_DEST     Where the source tree lives. Default: /opt/vps-init
#   VI_REF      Git ref (branch / tag). Default: main
#   VI_REPO     GitHub repo slug. Default: 491034170/vps-init

set -euo pipefail

VI_PREFIX="${VI_PREFIX:-/usr/local}"
VI_DEST="${VI_DEST:-/opt/vps-init}"
VI_REF="${VI_REF:-main}"
REPO="${VI_REPO:-491034170/vps-init}"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

if [[ "${EUID}" -ne 0 ]]; then
  echo "error: installer must run as root (sudo bash). vps-init needs /opt + /usr/local/bin write access." >&2
  exit 1
fi

echo "==> downloading vps-init@$VI_REF from $REPO"
curl -fsSL "https://codeload.github.com/$REPO/tar.gz/refs/heads/$VI_REF" \
  | tar -xz -C "$TMPDIR"

SRC="$TMPDIR/$(basename "$REPO")-$VI_REF"
mkdir -p "$VI_PREFIX/bin"

# Atomically replace destination (keep a quick backup for rollback).
if [[ -d "$VI_DEST" ]]; then
  mv "$VI_DEST" "${VI_DEST}.bak.$(date +%s)"
fi
cp -R "$SRC" "$VI_DEST"
ln -sf "$VI_DEST/bin/vps-init" "$VI_PREFIX/bin/vps-init"
chmod +x "$VI_DEST/bin/vps-init"

echo ""
echo "==> installed: $VI_PREFIX/bin/vps-init -> $VI_DEST/bin/vps-init"
echo ""
echo "Quick start:"
echo "  vps-init list                      # see built-in profiles"
echo "  sudo vps-init --dry-run apply web-cn   # preview"
echo "  sudo vps-init apply web-cn             # actually run"
