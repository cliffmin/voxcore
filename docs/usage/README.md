# Usage

## Basic Usage

**Hold Mode:**
- Hold `Cmd+Alt+Ctrl+Space` → Speak → Release
- Text pastes at cursor instantly
- Recording saved to `~/Documents/VoiceNotes/`

**Toggle Mode:**
- Press `Shift+Cmd+Alt+Ctrl+Space` to start
- Speak as long as you want
- Press again to stop and transcribe

## Customization

Edit `~/.hammerspoon/ptt_config.lua`:
- Change hotkeys
- Select audio device
- Configure post-processing
- Add custom dictionary entries

See [Configuration](../setup/configuration.md) for details.

## Output

Each recording creates:
- `recording.wav` - Original audio
- `recording.txt` - Clean transcription
- `recording.json` - Whisper metadata

Located in `~/Documents/VoiceNotes/{timestamp}/`
