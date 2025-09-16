# macOS Push-to-Talk Dictation

[![CI](https://github.com/cliffmin/macos-ptt-dictation/actions/workflows/ci.yml/badge.svg)](https://github.com/cliffmin/macos-ptt-dictation/actions/workflows/ci.yml) 
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**Offline push-to-talk voice dictation for macOS.** Hold a hotkey to record, release to transcribe and paste text at cursor.

## Features

- 🏠 **100% Offline** - All transcription happens on-device, no internet required
- ⚡ **Fast** - Sub-second response for short recordings with whisper-cpp
- ⌨️ **System-wide** - Works in any macOS application
- 🎯 **Smart** - Automatically selects model based on recording length
- 🧹 **Clean** - Removes "um", "uh" and other speech disfluencies
- 📝 **Direct** - Pastes transcribed text at cursor position

## Quick Start

```bash
# Install dependencies
brew install --cask hammerspoon
brew install ffmpeg whisper-cpp openjdk@17

# Clone and setup
git clone https://github.com/cliffmin/macos-ptt-dictation.git
cd macos-ptt-dictation
./scripts/setup/install.sh

# Build Java post-processor (optional but recommended)
make build-java

# Reload Hammerspoon to activate
```

## Usage

Default keybindings:
1. **Hold** `Cmd+Alt+Ctrl+Space` to record
2. **Release** to transcribe and paste
3. **Add Shift** for toggle mode (long-form recording)

You can customize keybindings in `~/.hammerspoon/ptt_config.lua` - see [Configuration](docs/setup/configuration.md) for details.

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

The system automatically selects the appropriate model based on recording length.

## Installation Details

After running the install script:
1. Configuration is symlinked to `~/.hammerspoon/`
2. Reload Hammerspoon from the menu bar
3. Test with the default keybinding (Cmd+Alt+Ctrl+Space)

For troubleshooting, see [Setup Guide](docs/setup/).

## Contributing

Contributions welcome! Please:
- Follow the structure defined in [WARP.md](WARP.md)
- Add tests for new features
- Update documentation as needed

See [Development Documentation](docs/development/) for architecture details.

## License

MIT - See [LICENSE](LICENSE) for details.