# VoxCore Documentation

Welcome to the VoxCore documentation. This guide will help you install, configure, and use VoxCore for fast, private, local transcription on macOS.

## Quick Links

### Getting Started
- **[Setup Guide](setup/)** - Installation and initial configuration
- **[Usage Guide](usage/)** - How to use VoxCore day-to-day
- **[Configuration](setup/configuration.md)** - Customize VoxCore behavior
- **[Troubleshooting](setup/troubleshooting.md)** - Common issues and solutions


### Development
- **[Architecture](development/architecture.md)** - System design and plugin model
- **[Versioning](development/versioning.md)** - Version management and release process
- **[Testing](development/testing.md)** - Running and writing tests
- **[Release Process](development/release.md)** - How releases are created
- **[Dependency Policy](development/dependency-policy.md)** - Managing dependencies
- **[Contributing](../CONTRIBUTING.md)** - How to contribute to VoxCore

### API Reference
- **[Whisper Service](api/whisper-service.md)** - Java transcription service API

### Official Plugins
- **[VoxCompose](https://github.com/cliffmin/voxcompose)** - ML-based transcript refinement via local LLMs (Ollama)
  - [Integration Guide](https://github.com/cliffmin/voxcompose/blob/main/docs/voxcore-integration.md)

## Documentation Structure

```
docs/
├── README.md                    # This file
├── setup/                       # Installation
│   ├── README.md
│   ├── configuration.md
│   └── dependencies.md
├── usage/                       # How to use
│   └── README.md
└── development/                 # For contributors
    ├── README.md
    ├── architecture.md
    └── ... (dev docs)
```

## Need Help?

- **Issues**: Report bugs or request features on [GitHub Issues](https://github.com/cliffmin/voxcore/issues)
- **Discussions**: Ask questions on [GitHub Discussions](https://github.com/cliffmin/voxcore/discussions)
- **Contributing**: See [CONTRIBUTING.md](../CONTRIBUTING.md) for how to contribute

## Quick Reference

### Installation
```bash
brew install --cask hammerspoon
brew install ffmpeg whisper-cpp openjdk@17
git clone https://github.com/cliffmin/voxcore.git
cd voxcore
./scripts/setup/install.sh
```

### Basic Usage
- Hold `Cmd+Alt+Ctrl+Space` → Speak → Release
- Text pastes at cursor
- Recording saved to `~/Documents/VoiceNotes/`

### Configuration
Edit `~/.hammerspoon/ptt_config.lua` to customize hotkeys, audio device, and behavior.

---

**Fast. Private. Secure. Yours.**
