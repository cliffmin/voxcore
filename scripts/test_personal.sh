#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Personal test runner (stub)
# This script is intentionally minimal and non-destructive.
# It helps you run tests against your own voice recordings, which are gitignored.

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PERS_DIR="$ROOT_DIR/tests/fixtures/personal"
SAMPLES_DIR="$PERS_DIR/samples"

cat <<'EOT'
Personal test runner
====================

Your personal recordings should live under:
  tests/fixtures/personal/samples/

Examples:
  tests/fixtures/personal/samples/2025-Aug-31_01.10.56_AM/*.wav|.json|.txt

Suggested workflows:
1) Quick Whisper probe on all WAVs:
   bash tests/integration/whisper_on_samples.sh

2) Compare refined vs unrefined (if VoxCompose is available):
   bash tests/integration/compare_unrefined_vs_refined_smoke.sh

3) Review latest transcripts by category:
   bash tests/integration/reflow_on_latest_samples.sh

Notes:
- Personal data is gitignored and will not be committed.
- Ensure ffmpeg and whisper CLI are installed as in README.
- These test scripts are headless (no GUI required).
EOT

# Exit successfully after printing guidance
exit 0

