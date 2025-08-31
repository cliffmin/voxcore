#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"

run() {
  local name="$1"; shift
  echo "==> $name"
  if "$@"; then
    echo "PASS: $name"
  else
    echo "FAIL: $name" >&2
    exit 1
  fi
}

run "capture probe" bash "$root/tests/smoke/capture_probe.sh"
run "whisper probe" bash "$root/tests/smoke/whisper_probe.sh"
run "push_to_talk module load" bash "$root/tests/smoke/push_to_talk_load.sh"
run "init.lua load" bash "$root/tests/smoke/init_load.sh"

echo "All smoke tests passed."

