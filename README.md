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

## Why now

In the era of AI agents, natural language is the universal interface. When spoken ideas become text, they become searchable, editable, automatable—and actionable. This project makes that instant and private: hold a key, speak, release to paste. For longer thoughts, the optional Refiner promotes raw transcripts into clear, structured Markdown that’s ready for prompts, tickets, docs, or automation.

### Why this vs. others
- 100% local: no tokens, no network, consistent latency
- One key anywhere: no window switching; paste at the cursor
- Structured output: optional refiner produces clean Markdown
- Deterministic pipeline: ffmpeg → Whisper → (optional) Refiner; logs and sidecars for traceability
- Extensible: hotkeys, models, retention policy, and refiner provider are all configurable

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

## 🧩 Extensibility (plugin‑style processors)

This project exposes a plugin‑style post‑processing stage. Any CLI that follows a simple contract can be used:
- Input: transcript text on stdin
- Output: refined text on stdout (e.g., Markdown) or analysis
- Optional: write a JSON sidecar with metrics
- Exit code: 0 = success; non‑zero = we fall back to the original transcript

Built‑in example: the Refiner (voxcompose) formats long‑form speech into clean Markdown. Planned: a Coaching analyzer to score clarity/pacing and surface actionable feedback.

### Refiner (optional)
Install via Homebrew (Apple Silicon shown):
```bash
brew tap cliffmin/tap
brew install voxcompose
```
Enable in your config (auto‑detects the voxcompose binary on PATH):
```lua
LLM_REFINER = {
  ENABLED = true,
  -- CMD = { "/opt/homebrew/bin/voxcompose" }, -- optional, auto‑detected if omitted
  ARGS = { "--model", "llama3.1", "--timeout-ms", "9000" },
  TIMEOUT_MS = 9000,
}
```
Run the self‑test (default): Cmd+Alt+Ctrl+R → “LLM refine self‑test OK”.

## 🎥 Demo

![Push-to-Talk Demo](docs/assets/demo.gif)

## ⚡ Performance: 10-40x Faster Than Before

Through [data-driven optimization](docs/PERFORMANCE_OPTIMIZATION.md), we achieved:
- **Instant feedback** for quick notes (<21s): ~0.5 seconds
- **Fast accurate transcription** for longer content (>21s): ~4 seconds
- **Smart model switching** at the optimal 21-second threshold

### The Numbers Don't Lie:
| Recording Length | Before (Python) | Now (whisper-cpp) | Speedup |
|-----------------|-----------------|-------------------|---------|  
| 5 seconds       | 12 seconds      | 0.5 seconds       | **24x** |
| 20 seconds      | 30 seconds      | 0.7 seconds       | **43x** |
| 45 seconds      | 45+ seconds     | 4 seconds         | **11x** |

[Read the full optimization story →](docs/PERFORMANCE_OPTIMIZATION.md)

![Performance](docs/assets/metrics.svg)

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
