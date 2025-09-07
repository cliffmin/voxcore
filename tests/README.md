# Integration test: long-form audio → Markdown

This test uses your local long-form WAV and does not check any audio into git.

Setup options (choose one):
- Symlink your WAV (preferred):

  ln -s "/Users/you/Documents/VoiceNotes/2025-08-30_19-47-27.norm.wav" tests/fixtures/local_longform.wav

- Or set an env var:

  export LONGFORM_WAV_PATH="/Users/you/Documents/VoiceNotes/2025-08-30_19-47-27.norm.wav"

Run:

  bash tests/integration/longform_to_markdown.sh

What it does:
1) Runs Whisper (pipx CLI) with model base.en to produce JSON/TXT in a temp directory.
2) Picks the TXT (or extracts text from JSON as a fallback).
3) Pipes the text to VoxCompose (Ollama-backed) to refine into Markdown.
4) Asserts the Markdown is non-empty and has basic structure (headings/bullets), then prints the first ~60 lines.

Notes:
- Keep large personal audio out of git.
- If you also have a raw .wav next to a .norm.wav, the script prefers the .norm.wav automatically.
- Ensure Ollama is running and that you’ve pulled a model, e.g. `ollama pull llama3.1`.

---

# Hammerspoon smoke tests

These tests ensure your Hammerspoon config (init.lua) and the push_to_talk module both load without syntax errors.

Prerequisite: install Hammerspoon CLI
- Open Hammerspoon → Preferences → General → Install Command Line Tool
- Verify: `command -v hs` shows a path.

1) Module load (without starting hotkeys)

Run:

  bash tests/smoke/push_to_talk_load.sh

This checks that `require("push_to_talk")` compiles/loads and exports a `start()` function. It does not bind hotkeys or start recording.

2) Init.lua load (dry load)

Run:

  bash tests/smoke/init_load.sh

This executes your `~/.hammerspoon/init.lua` inside the Hammerspoon runtime and reports a pass/fail for load-time errors (e.g., syntax errors). Hotkey registration warnings from other parts of your config may still appear in Hammerspoon’s Console, but they should not fail the test.

3) Refine self-test (LLM layer only)

From a running Hammerspoon session, press Cmd+Alt+Ctrl+R to run the refiner self-test. This does not record audio; it invokes the VoxCompose refiner with a sample text and logs a `refine_probe` JSONL event under `~/Documents/VoiceNotes/tx_logs/tx-YYYY-MM-DD.jsonl`. An on-screen alert reports success/failure. Ensure `LLM_REFINER.ENABLED=true` in `ptt_config.lua`.

---

# New: VoxCompose CLI smoke tests

These verify the new flags and sidecar behavior in the refiner.

Prerequisites:
- Build the fat jar:

  (cd ~/code/voxcompose && ./gradlew --no-daemon clean fatJar)

- Verify jar exists:

  ls ~/code/voxcompose/build/libs/voxcompose-0.1.0-all.jar

1) Refinement disabled path (no Ollama required)

Run:

  bash tests/integration/refine_disabled_smoke.sh

Asserts that VOX_REFINE=0 bypasses the LLM call, logs a disabled INFO line on stderr, and echoes the raw input.

2) Sidecar smoke test (requires Ollama)

- Ensure Ollama is running and the model is pulled, e.g.:

  ollama serve &
  ollama pull llama3.1

- Then run:

  bash tests/integration/refine_sidecar_smoke.sh

Asserts the jar returns non-empty output and writes a JSON sidecar with {ok, provider, model, refine_ms}.

---

# New: E2E speech test script for mic runs

Read the script at:

  tests/fixtures/e2e_speech_script.md

It includes: timed pauses, words that commonly misheard (now covered by DICTIONARY_REPLACE), disfluencies, acronyms, and domain terms. Use it to compare F13 (paste, no refine) vs Shift+F13 (refine) behavior after changes.

Batching and labeling in Test mode
- Toggle Test mode: hold Fn and press T. The dot shows TEST.
- While in Test mode, each successful recording is exported as symlinks under:
  tests/fixtures/samples_current/batches/<batch_id>/{short,medium,long}
  where <batch_id> encodes timestamp and repo HEAD (e.g., 20250907-0210_ab12cd3).
- Auto vs manual categorization:
  - Auto (default): duration ≤10s short; ≤30s medium; else long.
  - Manual (for the next recording only): hold Fn and press 1=short, 2=medium, 3=long. Fn+0 returns to auto.
- Batch metadata: metadata.json in the batch root captures git HEAD, branch, timestamp, and key config values for traceability.

Build a baseline set from your latest logs
- Create a curated baseline by selecting top per-bucket WAVs from the most recent log:

  tests/util/select_best_fixtures.zsh --per-bucket=5

- This creates symlinks under:

  tests/fixtures/baselines/<baseline_id>/{short,medium,long}

Benchmark against current Whisper
- Run the benchmark (measures elapsed sec per WAV):

  tests/integration/benchmark_against_baseline.sh tests/fixtures/baselines/<baseline_id>

- It reports rc|elapsed_sec|wav|json and writes a results file in the baseline directory.

