# Dependencies

## Required

| Dependency | Purpose | Install |
|-----------|---------|---------|
| [Hammerspoon](https://www.hammerspoon.org/) | macOS automation (hotkeys, recording, paste) | `brew install --cask hammerspoon` |
| [ffmpeg](https://ffmpeg.org/) | Audio recording (avfoundation capture) | `brew install ffmpeg` |
| [whisper-cpp](https://github.com/ggerganov/whisper.cpp) | Local speech-to-text transcription | `brew install whisper-cpp` |
| [OpenJDK 17](https://openjdk.org/) | Java runtime for VoxCore CLI and post-processor | `brew install openjdk@17` |

## Optional

| Dependency | Purpose | Install |
|-----------|---------|---------|
| [VoxCompose](https://github.com/cliffmin/voxcompose) | ML-powered transcript refinement | `brew install voxcompose` |
| [Ollama](https://ollama.ai/) | Local LLM (required by VoxCompose) | `brew install ollama` |

## Whisper Models

After installing `whisper-cpp`, download the model files:

```bash
# Required: base.en (fast, ~150MB)
# Used for short recordings (<21s)
./scripts/setup/download_whisper_models.sh base

# Recommended: medium.en (more accurate, ~500MB)
# Used for longer recordings (>=21s)
./scripts/setup/download_whisper_models.sh medium
```

Models are stored at `/opt/homebrew/share/whisper-cpp/`. See [Whisper Models Setup](whisper-models.md) for details.

## Architecture

```
Hammerspoon (Lua)
  └── push_to_talk_v2.lua    ← macOS glue: hotkeys, recording, paste
        │
        │ calls: voxcore transcribe <audio.wav> --model base.en
        ▼
VoxCore CLI (Java 17)
  └── whisper-post.jar        ← config, whisper invocation, post-processing
        │
        │ calls: whisper-cli -m <model> -f <audio> --prompt <vocabulary>
        ▼
whisper-cpp (C++)              ← on-device transcription
```

No Python dependencies. No network access. Everything runs locally.
