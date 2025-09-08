# Roadmap

Status: living document for upcoming work across macos-ptt-dictation and VoxCompose.

## Critical Bugs to Fix
- **F13 tap issue**: Single tap causes infinite transcribing indicator (yellow blink never ends)
  - Root cause: When F13 is tapped quickly, `stopRecording()` is called but no recording was actually started
  - Fix: Add proper state check in stopRecording() and handle the no-recording case gracefully
- **Audio cutoff at start**: First few words consistently missing or garbled
  - Root cause: Recording starts immediately but audio buffer/hardware may not be ready
  - Fix: Add small pre-roll buffer or delay to ensure clean audio capture from the start
- **Wave indicator broken**: Current wave meter implementation not working
  - Fix: Remove or replace with simpler visual feedback implementation

## Now
- **Standalone operation** (for initial public release)
  - Ensure repo works completely without VoxCompose dependency
  - Short and long form work as pure transcription (no LLM layer required)
  - Clear documentation that refiner is optional enhancement
- **UI improvements**
  - **More prominent transcribing indicator** (current orange blink too subtle)
    - Options: near-mouse overlay, larger indicator, or status text
    - Make it "discoverable" and "intuitive" (better UX terms than "ergonomic")
  - Replace broken waveform with simpler visual feedback
  - Status overlays: Recording, Transcribing, Refining, Pasted
  - Sounds are subtle and optional
- **Audio isolation during recording**
  - Mute system audio (YouTube, music, etc.) when F13 pressed
  - Ensures clean voice recording without background media
  - Options: mute via AppleScript, or use audio routing to isolate mic input
  - Restore audio state on recording end
- Single-key auto mode
  - Auto short vs long on release based on duration threshold (default 12s)
  - Double-press F13 toggles recording start/stop (no second hotkey)
  - Threshold cue optional (sound or dot color) when crossing threshold while holding
  - Log auto_mode_decision and gesture events in JSONL
- Refiner modularity
  - Capability-detect refiner at runtime (voxcompose, none)
  - Long flow runs without refine if unavailable; graceful fallback on refine timeout
  - Timeouts configurable (short vs long) with clear user alerts

## Next
- VoxCompose enhancements
  - Streaming output with time-to-first-token under load
  - Provider abstraction: ollama (local), openai (cloud), lmstudio (local), none
  - Robust exit codes, retries, exponential backoff, and cancellation
  - Sidecar JSON schema with timing, token usage, model, stop_reason, error_code
  - Template tasks: transcript_to_markdown, bulletize, title, gist
- Performance
  - Evaluate faster-whisper/whisper.cpp backends while preserving CLI contract
  - Long-clip refine: chunked prompting or summarization tree for reliability
- Installer and preflight
  - Optional LaunchAgent for Ollama; clear preflight warnings in Hammerspoon if missing
- Observability
  - Structured logs for gesture decisions, paste anchor app/window, refine stats

## Later
- Menubar Swift app alternative (no Hammerspoon dependency)
- Homebrew Tap formulae for both projects
- Multi-language support and domain-specific dictionaries
- Optional memory/glossary integration across sessions

## Acceptance and rollout
- Ship behind config flags by default; enable AUTO_MODE.enabled=true after validation
- Manual verification: quick matrix of short/long, refine present/absent, timeouts, overlay behavior
- Update docs: README Coming soon and RELEASE process
