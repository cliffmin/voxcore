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

