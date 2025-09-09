# macos-ptt-dictation

[![CI](https://github.com/cliffmin/macos-ptt-dictation/actions/workflows/ci.yml/badge.svg)](https://github.com/cliffmin/macos-ptt-dictation/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> Privacy-first push-to-talk dictation for macOS. Hold Hyper+Space to speak, release to paste.

## ✨ Features

- **100% Offline** - No cloud services, everything runs locally
- **One-Key Operation** - Just hold Hyper+Space (Cmd+Alt+Ctrl+Space) to record, release to transcribe
- **Fast Transcription** - 5-6x faster than realtime
- **Smart Formatting** - Handles pauses, punctuation, and paragraphs naturally
- **Auto-Save** - All recordings preserved in `~/Documents/VoiceNotes`
- **Customizable** - Adjust models, prompts, and formatting to your needs

## 🚀 Quick Start

### Prerequisites
```bash
# Install Hammerspoon (automation framework)
brew install --cask hammerspoon

# Install ffmpeg (audio capture)
brew install ffmpeg
```

### Installation
```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/macos-ptt-dictation.git
cd macos-ptt-dictation

# Install dependencies and set up
brew bundle --no-lock
python3 -m pip install --user pipx && python3 -m pipx ensurepath
pipx install --include-deps openai-whisper
bash ./scripts/install.sh
```

### First Use
1. **Reload Hammerspoon**: Menu bar → Reload Config
2. **Grant Permissions**: 
   - Accessibility (for hotkeys)
   - Microphone (for recording)
3. **Test**: Hold Hyper+Space, speak, release to paste

## 📖 Documentation

- [**Usage Guide**](docs/USAGE.md) - Features and workflows
- [**Configuration**](docs/CONFIG.md) - Customize behavior
- [**Troubleshooting**](docs/TROUBLESHOOTING.md) - Common issues
- [**Architecture**](docs/ARCHITECTURE.md) - Technical overview

## 🎯 Key Bindings

Defaults shown; all are configurable in `~/.hammerspoon/ptt_config.lua` under `KEYS`.

| Hotkey | Action |
|--------|--------|
| **Hyper+Space** (hold) | Record while held, paste on release |
| **Shift+Hyper+Space** | Toggle recording on/off (long-form) |
| **Cmd+Alt+Ctrl+I** | Show device info and diagnostics |

## 🔒 Privacy & Security

- **Local Processing** - Audio never leaves your machine
- **No Analytics** - Zero telemetry or tracking
- **Your Data** - Recordings saved locally in `~/Documents/VoiceNotes`
- **Open Source** - Audit the code yourself

## 🤝 Contributing

Contributions welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

## 📄 License

MIT - See [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

- [OpenAI Whisper](https://github.com/openai/whisper) for transcription
- [Hammerspoon](https://www.hammerspoon.org/) for macOS automation
- [ffmpeg](https://ffmpeg.org/) for audio capture
