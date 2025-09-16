# macOS Push-to-Talk Dictation

[![CI](https://github.com/cliffmin/macos-ptt-dictation/actions/workflows/ci.yml/badge.svg)](https://github.com/cliffmin/macos-ptt-dictation/actions/workflows/ci.yml) 
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**Offline push-to-talk dictation for macOS using OpenAI Whisper.** Hold a key to record, release to transcribe and paste at cursor.

## Features

- 🏠 **100% Local** - All transcription happens on-device, no cloud dependencies
- ⚡ **Sub-second Response** - Average 889ms transcription with whisper-cpp
- ⌨️ **System-wide** - Works in any application with customizable hotkeys
- 🎯 **Smart Accuracy** - Automatic model switching, text corrections, and punctuation restoration
- 🧹 **Clean Output** - Automatic removal of "um", "uh" and other disfluencies
- 📝 **Direct Insertion** - Transcribed text pastes directly at cursor position

## Quick Start

```bash
# Install dependencies
brew install --cask hammerspoon
brew install ffmpeg whisper-cpp

# Clone and setup
git clone https://github.com/cliffmin/macos-ptt-dictation.git
cd macos-ptt-dictation
./scripts/setup/install.sh
```

## Usage

1. **Hold** `F13` (or your configured key) to record
2. **Release** to transcribe and paste
3. **Shift+F13** for long-form recording (toggle mode)

See [Basic Usage](docs/usage/basic-usage.md) for details and [Configuration](docs/setup/configuration.md) for customization.

## Documentation

- **[Setup Guide](docs/setup/)** - Installation, configuration, troubleshooting
- **[Usage Guide](docs/usage/)** - Features, models, dictionaries
- **[Post-Processing](docs/usage/post-processing.md)** - Disfluency removal and text cleanup
- **[Development](docs/development/)** - Architecture, testing, contributing
- **[API Reference](docs/api/)** - Plugin and integration APIs

## Performance

| Recording Length | Transcription Time | Model Used |
|-----------------|-------------------|------------|
| < 21 seconds    | 300-600ms         | base.en    |
| > 21 seconds    | 3-5 seconds       | medium.en  |

Achieved through:
- whisper-cpp C++ implementation (5-10x faster than Python)
- Dynamic model selection based on duration
- Optimized audio preprocessing

## Requirements

- macOS 11.0+
- Hammerspoon 0.9.100+
- FFmpeg 6.0+
- whisper-cpp (recommended) or openai-whisper
- Java 17+ (for post-processor)
- 2GB free disk space for models

Optional Python tools are listed in [requirements-optional.txt](requirements-optional.txt)

## Contributing

See [Development Documentation](docs/development/) for architecture details and contribution guidelines.

Repository structure is defined in [WARP.md](WARP.md) - please follow the canonical structure when adding files.

## License

MIT - See [LICENSE](LICENSE) for details.