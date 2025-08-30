#!/usr/bin/env bash
set -euo pipefail

# Remove symlink and restore latest backup if present
TS_LATEST="$(ls -1t "$HOME/.hammerspoon"/push_to_talk.lua.bak-* 2>/dev/null | head -n1 || true)"
rm -f "$HOME/.hammerspoon/push_to_talk.lua"
if [ -n "$TS_LATEST" ]; then
  mv "$TS_LATEST" "$HOME/.hammerspoon/push_to_talk.lua"
  echo "Restored from backup: $TS_LATEST"
else
  echo "No backup found. push_to_talk.lua removed."
fi

echo "Uninstall complete. Reload Hammerspoon."

