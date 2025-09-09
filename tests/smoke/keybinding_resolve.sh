#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Smoke test: resolve keybindings from ptt_config and verify module exposes combos
# This does not bind real keys in a persistent session; it runs via hs CLI.

if ! command -v hs >/dev/null 2>&1; then
  echo "ERROR: 'hs' CLI not found. Install from Hammerspoon Preferences → General." >&2
  exit 2
fi

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Create a test ptt_config.lua with custom keys unlikely to conflict
cat >"$TMP_DIR/ptt_config.lua" <<'LUA'
return {
  SHIFT_TOGGLE_ENABLED = true,
  KEYS = {
    HOLD = { mods = {}, key = "f18" },
    TOGGLE = { mods = {"ctrl","shift"}, key = "f18" },
  },
}
LUA

# Write a small lua probe to run inside hs that prints resolved keys
cat >"$TMP_DIR/keybinding_probe.lua" <<'LUA'
local tmp = os.getenv('TMP_DIR')
local root = os.getenv('ROOT')
package.path = tmp .. "/?.lua;" .. root .. "/hammerspoon/?.lua;" .. package.path
local ok, mod = pcall(require, 'push_to_talk')
if not ok then
  print('ERR:' .. tostring(mod))
  os.exit(1)
end
if type(mod.start) ~= 'function' then
  print('ERR:no start')
  os.exit(1)
end
-- Initialize taps (binds and computes resolved keys)
mod.start()
local rk = mod._resolvedKeys and mod._resolvedKeys() or nil
if not rk or not rk.hold then
  print('ERR:no resolved keys')
  os.exit(1)
end
local function combo(t)
  if not t or not t.key then return 'disabled' end
  local m = t.mods or {}
  if #m == 0 then return t.key end
  return table.concat(m, '+') .. '+' .. t.key
end
print('RESOLVED_HOLD=' .. combo(rk.hold))
print('RESOLVED_TOGGLE=' .. combo(rk.toggle))
os.exit(0)
LUA

# Run the probe and capture output
OUT=$(ROOT="$ROOT" TMP_DIR="$TMP_DIR" hs -c "dofile('$TMP_DIR/keybinding_probe.lua')" 2>&1 || true)

# Expect our test combos
echo "$OUT" | sed -n 's/^RESOLVED_/\0/p'

HOLD=$(echo "$OUT" | sed -n 's/^RESOLVED_HOLD=//p')
TOGGLE=$(echo "$OUT" | sed -n 's/^RESOLVED_TOGGLE=//p')

if [[ "$HOLD" != "f18" ]]; then
  echo "FAIL: HOLD expected f18, got '$HOLD'" >&2
  exit 1
fi
if [[ "$TOGGLE" != "ctrl+shift+f18" ]]; then
  echo "FAIL: TOGGLE expected ctrl+shift+f18, got '$TOGGLE'" >&2
  exit 1
fi

echo "OK: keybinding resolve (HOLD=$HOLD, TOGGLE=$TOGGLE)"

