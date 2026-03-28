#!/usr/bin/env bash
# Update quickshell config from the repo to ~/.config/quickshell

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$REPO_DIR/dots/.config/quickshell"
DEST="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"

echo "Syncing $SRC → $DEST ..."
rsync -a --delete --out-format='  %n' "$SRC/" "$DEST/"

echo "Reloading quickshell..."
if pkill -SIGUSR2 quickshell 2>/dev/null; then
    echo "Done."
else
    echo "quickshell not running or reload failed, you may need to restart it manually."
fi
