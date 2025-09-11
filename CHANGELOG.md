# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Java-based post-processor for transcript cleaning
  - Pipeline pattern with modular text processors
  - Fixes merged words ("theyconfigure" → "they configure")
  - Sentence boundary detection for run-on sentences
  - Smart capitalization and punctuation normalization
  - Extensible architecture for custom processors
  - Gradle build system with one-command install script
  - Smart path discovery (no hardcoded paths)

### Changed
- Replaced Lua text processing with Java processor
- Improved transcript quality with better word separation
- Streamlined processing pipeline (single pass instead of multiple)
- Better distribution support (works on any macOS system)

### Removed
- Duplicate Lua text processing functions
- Hardcoded file paths in configuration
- Obsolete transcript_enhancer.lua module
## 0.1.0 - 2025-08-31
### Added
- Transcription timeout increased to 2 minutes (configurable via `TIMEOUT_MS`).
- Per-recording folder structure: each session writes to `~/Documents/VoiceNotes/<timestamp>/`.
  - Files saved side-by-side: `<timestamp>.wav`, `<timestamp>.json`, `<timestamp>.txt`.
- Single WAV policy (canonical output):
  - Short clips: raw `<timestamp>.wav`.
  - Long clips: normalized audio replaces raw; still exactly one `<timestamp>.wav`.
- Filename format now includes seconds: `YYYY-Mon-DD_HH.MM.SS_AM`.
- New Fn hotkeys (grouped with Fn+T):
  - Fn+T: toggle test/live mode.
  - Fn+R: reload Hammerspoon config.
  - Fn+O: open `~/.hammerspoon/init.lua` in VS Code.
- Config improvements:
  - `NOTES_DIR` override (defaults to `~/Documents/VoiceNotes`).
  - Default `AUDIO_DEVICE_INDEX` set to the built‑in mic (`:1`) with override via `ptt_config.lua`.
  - Added internal `SOUND_ENABLED` option (default off) for UX cues.
- Reliability and UX hardening:
  - Clear on‑screen alerts for timeout, missing Whisper CLI, no audio captured, or no voice detected.
  - Indicator and wave UI now cleanly turn off on early exits and errors.
- Migration utilities:
  - `scripts/migrate_voicenotes_names.zsh` — rename legacy files to the new timestamp format.
  - `scripts/migrate_voicenotes_to_folders.zsh` — reorganize into per‑recording folders and enforce single WAV.
- Tests:
  - Smoke probes: `tests/smoke/capture_probe.sh`, `tests/smoke/whisper_probe.sh`, wired into `tests/smoke/all.sh`.
  - Integration: `tests/integration/whisper_on_samples.sh` runs Whisper against four real samples (short→long).
  - Utility: `tests/util/select_voice_samples.zsh` collects fixtures into `tests/fixtures/samples/`.
- Documentation: README updated with storage layout, timeout, hotkeys, logging paths, and test/migration instructions.

