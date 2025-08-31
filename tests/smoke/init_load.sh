#!/usr/bin/env bash
set -euo pipefail

# Hammerspoon init.lua load smoke test
# Executes ~/.hammerspoon/init.lua inside the Hammerspoon runtime, reporting pass/fail on load errors.
# Note: This will run your init.lua; it should not exit Hammerspoon. Hotkey registration warnings may still
# appear in Hammerspoon Console, but this test exits non-zero only on hard load/compile errors.

if ! command -v hs >/dev/null 2>&1; then
  echo "ERROR: 'hs' CLI not found. In Hammerspoon: Preferences → General → Install Command Line Tool" >&2
  exit 2
fi

HS_INIT="$HOME/.hammerspoon/init.lua"
if [[ ! -f "$HS_INIT" ]]; then
  echo "ERROR: No ~/.hammerspoon/init.lua found" >&2
  exit 2
fi

hs -c "local ok, err = pcall(function() dofile(os.getenv('HOME') .. '/.hammerspoon/init.lua') end); if not ok then print('HS_INIT_LOAD_ERR\n' .. tostring(err)); os.exit(1) else print('HS_INIT_LOAD_OK') end"

