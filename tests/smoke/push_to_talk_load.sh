#!/usr/bin/env bash
set -euo pipefail

# Hammerspoon module load smoke test (no side effects)
# Verifies that `require("push_to_talk")` compiles/loads and exports a start() function.

if ! command -v hs >/dev/null 2>&1; then
  echo "ERROR: 'hs' CLI not found. In Hammerspoon: Preferences → General → Install Command Line Tool" >&2
  exit 2
fi

# Run within Hammerspoon runtime
hs -c '
  local ok, mod = pcall(require, "push_to_talk")
  if not ok then
    print("PUSH_TO_TALK_REQUIRE_ERROR:\n" .. tostring(mod))
    os.exit(1)
  end
  local hasStart = (type(mod) == "table" and type(mod.start) == "function")
  if not hasStart then
    print("PUSH_TO_TALK_NO_START")
    os.exit(1)
  end
  print("PUSH_TO_TALK_LOAD_OK")
'

