# Setup

## Install via Homebrew (Recommended)

```bash
brew tap cliffmin/tap
brew install --cask hammerspoon
brew install voxcore
voxcore-install
```

Grant Hammerspoon **Microphone** and **Accessibility** permissions in System Settings, then reload (Cmd+Opt+Ctrl+R).

## Install from Source (Development)

```bash
brew install --cask hammerspoon
brew install ffmpeg whisper-cpp openjdk@17
git clone https://github.com/cliffmin/voxcore.git
cd voxcore
./scripts/setup/install.sh
```

This builds the Java post-processor, symlinks Lua scripts, and creates a config file.

## Local Dev Workflow

After making changes, rebuild and reload:

```bash
# Build Java post-processor
cd whisper-post-processor && ./gradlew shadowJar --no-daemon

# Reload Hammerspoon to pick up Lua changes
# Menu bar -> Reload Config, or Cmd+Opt+Ctrl+R
```

Or use the Makefile shortcut:

```bash
make dev    # Builds JAR and reloads Hammerspoon
```

## Upgrade

```bash
brew update && brew upgrade voxcore && voxcore-install
```

Reload Hammerspoon after upgrading. Your config (`~/.hammerspoon/ptt_config.lua`) and recordings (`~/Documents/VoiceNotes/`) are preserved.

## Configure

Edit `~/.hammerspoon/ptt_config.lua`. See [Configuration](configuration.md) for all options.

Key settings:
- `AUDIO_DEVICE_NAME` -- Microphone selection (by name, handles Continuity)
- `DYNAMIC_MODEL` -- Auto-select Whisper model based on recording duration
- `KEYS` -- Hotkey binding
- `DEBUG_MODE` -- Verbose CLI output for troubleshooting

## Troubleshooting

See [Troubleshooting](troubleshooting.md) for common issues.

Quick fixes:
- **Wrong mic**: Set `AUDIO_DEVICE_NAME` in config (default: `"MacBook Pro Microphone"`)
- **Whisper not found**: `brew install whisper-cpp` then download models
- **No audio**: Check Microphone permissions for Hammerspoon in System Settings
