# macOS Push-to-Talk Dictation

[![CI](https://github.com/cliffmin/macos-ptt-dictation/actions/workflows/ci.yml/badge.svg)](https://github.com/cliffmin/macos-ptt-dictation/actions/workflows/ci.yml) 
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**Offline push-to-talk dictation for macOS using OpenAI Whisper.** Hold a key to record, release to transcribe and paste at cursor.

## Features

- 🏠 **100% Local** - All transcription happens on-device, no cloud dependencies
- ⚡ **Fast Response** - Sub-second transcription for short recordings with whisper-cpp
- ⌨️ **System-wide** - Works in any application with customizable hotkeys
- 🎯 **Smart Accuracy** - Automatic model switching based on recording length
- 🧹 **Clean Output** - Automatic removal of "um", "uh" and other speech disfluencies
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

| Recording Length | Typical Speed | Model Used | Accuracy |
|-----------------|---------------|------------|----------|
| < 21 seconds | <1 second | base.en | Good for general dictation |
| > 21 seconds | 2-5 seconds | medium.en | Better for technical content |

### Speed Improvements
- **whisper-cpp**: 5-10x faster than Python implementation
- **Dynamic model selection**: Balances speed vs accuracy
- **Optimized preprocessing**: Reduces latency

## Requirements

### System
- macOS 11.0+ (Big Sur or later)
- 8GB RAM recommended
- Disk space:
  - **600MB** for whisper-cpp models (recommended)
  - **1.7GB** for OpenAI Whisper models (if using Python version)

### Software
- **Hammerspoon** 0.9.100+ - macOS automation framework
- **FFmpeg** 6.0+ - Audio processing
- **Java** 17+ - Post-processor for text cleanup

### Transcription (choose one)
- **whisper-cpp** (recommended) - Fast C++ implementation, 5-10x speed
- **openai-whisper** (optional) - Original Python implementation

### Models Used
- **base.en** (75MB) - Fast transcription for recordings <21 seconds
- **medium.en** (500MB) - Accurate transcription for recordings >21 seconds

Optional Python tools are listed in [requirements-optional.txt](requirements-optional.txt)

## Contributing

See [Development Documentation](docs/development/) for architecture details and contribution guidelines.

Repository structure is defined in [WARP.md](WARP.md) - please follow the canonical structure when adding files.

## License

MIT - See [LICENSE](LICENSE) for details.