# macos-ptt-dictation

[![CI](https://github.com/cliffmin/macos-ptt-dictation/actions/workflows/ci.yml/badge.svg)](https://github.com/cliffmin/macos-ptt-dictation/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Offline push-to-talk dictation for macOS using OpenAI Whisper. Hold a key to record, release to transcribe and paste at cursor.

## Overview

A macOS automation tool that provides system-wide voice-to-text functionality using local speech recognition. Built with Hammerspoon, FFmpeg, and Whisper for privacy-conscious users who need fast, accurate transcription without cloud dependencies.

## Key Features

- **Local Processing** - All transcription happens on-device using Whisper models
- **System-wide Hotkey** - Works in any application via configurable keyboard shortcuts
- **Direct Insertion** - Transcribed text pastes directly at cursor position
- **Performance Optimized** - Sub-second transcription for most recordings ([details](docs/PERFORMANCE_OPTIMIZATION.md))
- **Automatic Formatting** - Intelligent paragraph breaks and punctuation based on speech patterns
- **Session Recording** - All audio saved locally with searchable transcripts

## Requirements

- macOS 11.0 or later
- Hammerspoon 0.9.100+
- FFmpeg 6.0+
- whisper-cpp (recommended) or Python 3.9+ with pipx (optional fallback)
- Java 17+ (for post-processor)
- 2GB free disk space for models

## Installation

### Quick Start

```bash
# Clone and setup
git clone https://github.com/cliffmin/macos-ptt-dictation.git
cd macos-ptt-dictation
./scripts/install.sh
```

### Manual Installation

1. Install core dependencies:
```bash
brew install --cask hammerspoon
brew install ffmpeg
brew install whisper-cpp  # Recommended for performance
brew install openjdk      # For Java post-processor
```

2. Configure Hammerspoon:
```bash
cp -r hammerspoon/* ~/.hammerspoon/
cp hammerspoon/ptt_config.lua.sample ~/.hammerspoon/ptt_config.lua
```

3. Install post-processor:
```bash
cd whisper-post-processor
./install.sh
```

4. Optional: Install Python tools (isolated via pipx):
```bash
# Only if you need Python fallback instead of whisper-cpp
brew install pipx
pipx ensurepath
pipx install openai-whisper  # Fallback transcription
```

5. Grant required permissions:
   - System Preferences → Security & Privacy → Accessibility → Hammerspoon ✓
   - System Preferences → Security & Privacy → Microphone → Hammerspoon ✓

6. Reload Hammerspoon configuration

## Usage

### Default Keybindings

| Keybinding | Action |
|------------|--------|
| `Hyper+Space` (hold) | Record while held, transcribe and paste on release |
| `Shift+Hyper+Space` | Toggle recording (for longer sessions) |
| `Cmd+Alt+Ctrl+I` | Show system info and diagnostics |

*Hyper = Cmd+Alt+Ctrl (configurable in `ptt_config.lua`)*

### Configuration

Edit `~/.hammerspoon/ptt_config.lua` to customize:
- Whisper model selection
- Keybindings
- Audio quality settings
- Output formatting
- Storage location

See [Configuration Guide](docs/CONFIG.md) for all options.

## Architecture

### Processing Pipeline

```
Audio Capture (FFmpeg) → Transcription (Whisper) → Post-Processing (Java) → Clipboard
```

### Components

- **Hammerspoon**: macOS automation and hotkey management (Lua)
- **FFmpeg**: Audio recording and normalization
- **Whisper**: Speech-to-text engine (whisper-cpp recommended, Python fallback via pipx)
- **Post-Processor**: Java-based text correction pipeline
- **Storage**: Local filesystem with JSON metadata

**Note**: Python dependencies (if used) are isolated in pipx virtual environments, not installed globally. See [Dependencies Documentation](docs/DEPENDENCIES.md) for details.

### Performance Optimizations

- Dynamic model selection based on recording duration
- Optimized 21-second threshold for model switching
- Metal acceleration on Apple Silicon
- Native C++ implementation via whisper-cpp

See [Performance Analysis](docs/PERFORMANCE_OPTIMIZATION.md) for detailed benchmarks.

## Recent Improvements

- **Performance**: 10-40x faster transcription with whisper-cpp ([details](docs/PERFORMANCE_OPTIMIZATION.md))
- **Accuracy**: Java post-processor fixes common Whisper issues ([details](whisper-post-processor/README.md))
- **Model Optimization**: Discovered optimal 21-second threshold for model switching ([research](docs/THRESHOLD_ANALYSIS.md))

## Documentation

- [Configuration Guide](docs/CONFIG.md) - Detailed configuration options
- [Dependencies](docs/DEPENDENCIES.md) - Dependency management and isolation
- [Performance Analysis](docs/PERFORMANCE_OPTIMIZATION.md) - Benchmarks and optimization details
- [Threshold Discovery](docs/THRESHOLD_ANALYSIS.md) - 21-second model switching research
- [Architecture](docs/ARCHITECTURE.md) - System design and components
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Common issues and solutions
- [Testing](docs/TESTING.md) - Test infrastructure and accuracy metrics

## Testing

Run the test suite:
```bash
make test                          # Quick smoke tests
./scripts/test_accuracy.sh         # Full accuracy testing
cd whisper-post-processor && gradle test  # Java processor tests
```

See [Testing Guide](docs/TESTING.md) for comprehensive testing documentation.

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT - See [LICENSE](LICENSE) for details.

## Acknowledgments

- [OpenAI Whisper](https://github.com/openai/whisper) - Speech recognition models
- [Hammerspoon](https://www.hammerspoon.org/) - macOS automation framework
- [whisper-cpp](https://github.com/ggerganov/whisper.cpp) - High-performance C++ implementation
- [FFmpeg](https://ffmpeg.org/) - Audio processing
