# Architecture

Overview
- Hammerspoon (Lua): macOS automation & UX (hotkeys, notifications)
- Audio capture: ffmpeg avfoundation → 16 kHz mono WAV
- Java Service (Undertow): long-running daemon (no per-request JVM cold-start)
  - HTTP: /health, /transcribe, /metrics (Prometheus)
  - WebSocket: /ws (incremental processing of accumulated text)
- Transcription: whisper.cpp via WhisperService/WhisperCppAdapter
- Java Post-Processor Pipeline: Reflow → Context → Disfluency → MergedWord → Sentences → Capitalization → PunctuationProcessor → Dictionary → PunctuationNormalizer
- Config precedence: request > env/file (~/.config/ptt-dictation/config.json) > defaults
- Outputs: pasted text (Hammerspoon), optional files/logs
- Optional refine: VoxCompose remains supported but Java now covers most cleanup

Log example
```json path=null start=null
{
  "ts": "2025-08-30T21:59:30Z",
  "kind": "success",
  "app": "voxcore",
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

Key benefits of the Java service
- Faster start-of-speech capture (service is warm; avoids JVM cold-start delays that used to truncate first words when combined with silence gating)
- Real-time streaming via WebSocket (incremental refinement)
- Observability via Prometheus metrics
- Clean API seam (Lua ↔ HTTP/WS) and better CI test surfaces

Why separate repos
- VoxCore: macOS automation, capture, transcription, UX, files, logs
- VoxCompose: refinement and formatting with pluggable providers

