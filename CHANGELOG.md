# Changelog

All notable changes to this project will be documented in this file.

## 2025-08-31

- Transcription timeout increased to 2 minutes (configurable via TIMEOUT_MS)
- Per-recording folder structure: each session writes to `~/Documents/VoiceNotes/<timestamp>/`
  - Files saved side-by-side: `<timestamp>.wav`, `<timestamp>.json`, `<timestamp>.txt`
- Single WAV policy (canonical output)
  - Short clips: raw `<timestamp>.wav`
  - Long clips: normalized audio replaces raw; still exactly one `<timestamp>.wav`
- Filename format now includes seconds: `YYYY-Mon-DD_HH.MM.SS_AM`
- New Fn hotkeys (grouped with Fn+T)
  - Fn+T: toggle test/live mode
  - Fn+R: reload Hammerspoon config
  - Fn+O: open `~/.hammerspoon/init.lua` in VS Code
- Config improvements
  - NOTES_DIR override (defaults to `~/Documents/VoiceNotes`)
  - Default AUDIO_DEVICE_INDEX set to the built‑in mic (`:1`) with override via `ptt_config.lua`
  - Added SOUND_ENABLED option internally (default off) for UX cues
- Reliability and UX hardening
  - Clear on‑screen alerts for timeout, missing Whisper CLI, no audio captured, or no voice detected
  - Indicator and wave UI now cleanly turn off on early exits and errors
- Migration utilities
  - `scripts/migrate_voicenotes_names.zsh`: rename legacy files to the new timestamp format
  - `scripts/migrate_voicenotes_to_folders.zsh`: reorganize into per‑recording folders and enforce single WAV
- Tests
  - Smoke probes added:
    - `tests/smoke/capture_probe.sh`: 2s ffmpeg capture sanity check for the configured mic
    - `tests/smoke/whisper_probe.sh`: generate a 1s file and run Whisper to assert environment/CLI health
    - Wired into `tests/smoke/all.sh`
  - Integration: `tests/integration/whisper_on_samples.sh` runs Whisper against 4 real samples (short→long) and asserts non‑empty outputs
  - Utility: `tests/util/select_voice_samples.zsh` picks 4 successful sessions from VoiceNotes and copies them to `tests/fixtures/samples/`
- Documentation
  - README updated with new storage layout, timeout, hotkeys, logging paths, and test/migration instructions


