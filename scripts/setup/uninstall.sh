#!/usr/bin/env bash
set -euo pipefail

# Remove symlinks and restore latest backup if present
rm -f "$HOME/.hammerspoon/push_to_talk_v2.lua"
rm -f "$HOME/.hammerspoon/push_to_talk.lua"
TS_LATEST="$(ls -1t "$HOME/.hammerspoon"/push_to_talk.lua.bak-* 2>/dev/null | head -n1 || true)"
if [ -n "$TS_LATEST" ]; then
  echo "Found backup: $TS_LATEST (not restoring deprecated v1)"
  rm -f "$TS_LATEST"
fi
echo "VoxCore Lua files removed."

echo "Uninstall complete. Reload Hammerspoon."

