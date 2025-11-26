# Setup

This page replaces the previous multi-page setup/docs. It covers minimal installation, configuration, and troubleshooting.

## Install (minimal)

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

## Configure

Your config lives at ~/.hammerspoon/ptt_config.lua. A sample is installed by the setup script.

- Default hotkeys: Hold Cmd+Alt+Ctrl+Space to record; add Shift for toggle mode
- Audio device: set AUDIO_DEVICE_INDEX in ptt_config.lua (use diagnostics to list devices)
  - Tip: To avoid Continuity iPhone Microphone, pin the built‑in mic index (often 2) or run: make auto-audio
  - List devices: /opt/homebrew/bin/ffmpeg -f avfoundation -list_devices true -i '' 2>&1 | sed -n 's/^\[AVFoundation.*\] //p'
- Post-processing: enabled natively via Java pipeline; no Python required

## Troubleshooting

See [Configuration](configuration.md) for common issues.

**Quick fixes:**
- Wrong mic: Check `AUDIO_DEVICE_INDEX` in config
- Whisper not found: `brew install whisper-cpp`
- No audio: Test with `make test-audio`
