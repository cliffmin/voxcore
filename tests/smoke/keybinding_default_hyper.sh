#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Smoke test: default Hyper+Space when KEYS missing (uses code defaults)
# We simulate a minimal ptt_config.lua with no KEYS to force defaults.

if ! command -v hs >/dev/null 2>&1; then
  echo "ERROR: 'hs' CLI not found. Install from Hammerspoon Preferences → General." >&2
  exit 2
fi

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Minimal config without KEYS
cat >"$TMP_DIR/ptt_config.lua" <<'LUA'
return {
  SHIFT_TOGGLE_ENABLED = true,
}
LUA

# Lua probe
cat >"$TMP_DIR/keybinding_probe.lua" <<'LUA'
local tmp = os.getenv('TMP_DIR')
local root = os.getenv('ROOT')
package.path = tmp .. "/?.lua;" .. root .. "/hammerspoon/?.lua;" .. package.path
local ok, mod = pcall(require, 'push_to_talk')
if not ok then
  print('ERR:' .. tostring(mod))
  os.exit(1)
end
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
LUA

OUT=$(env ROOT="$ROOT" TMP_DIR="$TMP_DIR" hs -c "dofile('$TMP_DIR/keybinding_probe.lua')" 2>&1 || true)

echo "$OUT" | sed -n 's/^RESOLVED_/\0/p'

HOLD=$(echo "$OUT" | sed -n 's/^RESOLVED_HOLD=//p')
TOGGLE=$(echo "$OUT" | sed -n 's/^RESOLVED_TOGGLE=//p')

if [[ "$HOLD" != "cmd+alt+ctrl+space" ]]; then
  echo "FAIL: default HOLD expected cmd+alt+ctrl+space, got '$HOLD'" >&2
  exit 1
fi
if [[ "$TOGGLE" != "cmd+alt+ctrl+shift+space" ]]; then
  echo "FAIL: default TOGGLE expected cmd+alt+ctrl+shift+space, got '$TOGGLE'" >&2
  exit 1
fi

echo "OK: default keybindings (HOLD=$HOLD, TOGGLE=$TOGGLE)"

