# Security and privacy

- Local-first: audio capture and transcription are local by default (ffmpeg + whisper-cpp; openai-whisper via pipx is optional fallback)
- No telemetry or network calls required for core functionality
- Runtime data (WAV/JSON/TXT/logs) lives under ~/Documents/VoiceNotes by default and is excluded from git
- Optional refinement via VoxCompose uses your configured local or cloud provider; review VoxCompose docs before enabling cloud

## Reporting

Please report security issues privately or open a GitHub issue with minimal details and a way to contact you. Avoid sharing sensitive information.

