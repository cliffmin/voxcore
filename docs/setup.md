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
- Post-processing: enabled natively via Java pipeline; no Python required

## Troubleshooting

- Whisper not found: brew install whisper-cpp (or verify it’s in PATH)
- No audio captured: verify input device and test with make test-audio
- Slow or missing first word: Java daemon and pre-roll padding reduce truncation; ensure Java build exists (make build-java)
- Logs: ~/Documents/VoiceNotes/tx_logs/tx-YYYY-MM-DD.jsonl (toggle via ptt_config.lua)

## Uninstall

```bash
./scripts/setup/uninstall.sh
```
