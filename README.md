# VoxCore

[![CI](https://github.com/cliffmin/voxcore/actions/workflows/ci.yml/badge.svg)](https://github.com/cliffmin/voxcore/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Offline push-to-talk dictation for macOS. Hold a hotkey to record, release to transcribe, and paste at the cursor — fully on-device.

## Quick start

```bash
brew install --cask hammerspoon
brew install ffmpeg whisper-cpp openjdk@17

git clone https://github.com/cliffmin/voxcore.git
cd voxcore
./scripts/setup/install.sh
# optional
make build-java
```

## Use it
- Hold Cmd+Alt+Ctrl+Space to record; release to paste
- Add Shift for toggle mode (start/stop)
- Customize keys and options in ~/.hammerspoon/ptt_config.lua

## Docs
- Setup: docs/setup.md
- Usage: docs/usage.md
- Architecture: docs/development/architecture.md
- Post-processor CLI: whisper-post-processor/README.md

## Notes
- Fast by default via whisper-cpp; model auto-selection balances speed/accuracy
- Native Java post-processing cleans disfluencies, punctuation, and capitalization

## License
MIT — see LICENSE
