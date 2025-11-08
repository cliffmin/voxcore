# Setup

This page replaces the previous multi-page setup/docs. It covers minimal installation, configuration, and troubleshooting.

## Install (Homebrew - Recommended)

```bash
brew tap cliffmin/tap
brew install voxcore
voxcore-install  # Setup Hammerspoon integration
```

Optional: Start daemon for audio padding and WebSocket API
```bash
brew services start voxcore
```

## Install (from source)

```bash
brew install --cask hammerspoon
brew install ffmpeg whisper-cpp openjdk@17
# clone and install
git clone https://github.com/cliffmin/voxcore.git
cd voxcore
./scripts/setup/install.sh
```

Optional: build the Java post-processor (recommended)
```bash
make build-java
```

Optional: setup daemon auto-start
```bash
./scripts/setup/setup_daemon_service.sh
# or manually start: make daemon
```

## Configure

Your config lives at ~/.hammerspoon/ptt_config.lua. A sample is installed by the setup script.

- Default hotkeys: Hold Cmd+Alt+Ctrl+Space to record; add Shift for toggle mode
- Audio device: set AUDIO_DEVICE_INDEX in ptt_config.lua (use diagnostics to list devices)
- Post-processing: enabled natively via Java pipeline; no Python required

## Background Daemon

The optional PTT daemon provides:
- **200ms audio pre-roll** to prevent cutting off initial words
- **WebSocket API** for advanced integrations
- **Prometheus metrics** for monitoring

Start with Homebrew:
```bash
brew services start voxcore
brew services stop voxcore
```

Or setup manually for auto-start:
```bash
./scripts/setup/setup_daemon_service.sh
```

Manual start/stop:
```bash
make daemon       # Start in background
make stop-daemon  # Stop daemon
```

## Troubleshooting

- Whisper not found: `brew install whisper-cpp` (or verify it's in PATH)
- No audio captured: verify input device and test with `make test-audio`
- Slow or missing first word: Start the daemon for audio padding (`brew services start voxcore` or `make daemon`)
- Daemon not starting: Check logs at `~/Library/Logs/voxcore-daemon.*.log`
- Logs: `~/Documents/VoiceNotes/tx_logs/tx-YYYY-MM-DD.jsonl` (toggle via ptt_config.lua)

## Uninstall

```bash
./scripts/setup/uninstall.sh
```
