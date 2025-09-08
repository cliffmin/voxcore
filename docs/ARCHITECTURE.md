# Architecture

Overview
- Hammerspoon module: hammerspoon/push_to_talk.lua
- Config: hammerspoon/ptt_config.lua
- Audio capture: ffmpeg avfoundation → 16 kHz mono WAV
- Transcription: ~/.local/bin/whisper (openai-whisper via pipx)
- Long audio: preprocess (normalize/compress) for clips ≥ 12s
- Outputs: per-session folder in ~/Documents/VoiceNotes
- Optional refine: VoxCompose CLI to Markdown

Log example
```json path=null start=null
{
  "ts": "2025-08-30T21:59:30Z",
  "kind": "success",
  "app": "macos-ptt-dictation",
  "model": "base.en",
  "device": "cpu",
  "beam_size": 3,
  "wav": "/Users/you/Documents/VoiceNotes/2025-Aug-30_12.31.34_AM/2025-Aug-30_12.31.34_AM.wav",
  "duration_sec": 6.1,
  "preprocess_used": false,
  "tx_ms": 1450,
  "transcript_chars": 67
}
```

Why separate repos
- macos-ptt-dictation: macOS automation, capture, transcription, UX, files, logs
- VoxCompose: refinement and formatting with pluggable providers

