# Configuration

Configuration lives at `~/.hammerspoon/ptt_config.lua`. A sample is created by `voxcore-install` or `./scripts/setup/install.sh`.

Fallback locations: `~/.config/voxcore/ptt_config.lua` or `$XDG_CONFIG_HOME/voxcore/ptt_config.lua`.

## Audio Device

VoxCore resolves the microphone **by name** (not index), which prevents iPhone Continuity from hijacking recordings when connected.

```lua
-- Default: MacBook Pro Microphone
AUDIO_DEVICE_NAME = "MacBook Pro Microphone"

-- Override with explicit index (only if name matching fails)
-- AUDIO_DEVICE_INDEX = 1
```

List available devices:
```bash
/opt/homebrew/bin/ffmpeg -f avfoundation -list_devices true -i '' 2>&1 | grep "audio devices" -A 20
```

## Model Selection

VoxCore automatically picks the Whisper model based on recording duration. Short clips use a faster model; longer recordings use a more accurate one.

```lua
DYNAMIC_MODEL = true           -- Enable automatic model selection (default: true)
MODEL_THRESHOLD_SEC = 21       -- Duration threshold in seconds
SHORT_MODEL = "base.en"        -- Model for clips < threshold (~500ms)
LONG_MODEL = "medium.en"       -- Model for clips >= threshold (~2s, more accurate)
```

To use a single model for everything, set `DYNAMIC_MODEL = false`. The CLI defaults to `base.en`.

## Key Bindings

```lua
KEYS = {
  HOLD = { mods = {"cmd", "alt", "ctrl"}, key = "space" },
}
```

Hold the key to record, release to transcribe and paste. Keys use Hammerspoon identifiers (e.g., `"f13"`, `"f18"`, `"space"`).

## Paths

```lua
VOXCORE_CLI = "/opt/homebrew/bin/voxcore"       -- VoxCore binary (Homebrew default)
VOXCOMPOSE_CLI = "/opt/homebrew/bin/voxcompose"  -- VoxCompose binary (optional)
NOTES_DIR = "~/Documents/VoiceNotes"             -- Recording storage
-- LOG_DIR = "~/.local/state/voxcore/tx_logs"    -- Custom log dir (default: NOTES_DIR/tx_logs)
```

Paths support `~`, `$HOME`, and `${VAR}` expansion.

## UX

```lua
SOUND_ENABLED = false    -- Play sound cues on record start/stop
LOG_ENABLED = false      -- Transaction logging (JSONL, off by default for privacy)
DEBUG_MODE = false       -- Pass --debug to VoxCore CLI for verbose output
```

## VoxCompose Vocabulary (Optional)

If VoxCompose is installed, vocabulary is automatically refreshed on Hammerspoon load and after each transcription. No configuration needed -- it reads from `~/.config/voxcompose/vocabulary.txt`.

To customize the vocabulary file path in VoxCore's Java config (`~/.config/voxcore/config.json`):

```json
{
  "vocabulary_file": "~/.config/voxcompose/vocabulary.txt",
  "enable_dynamic_vocab": true
}
```

## Example Config

```lua
-- ~/.hammerspoon/ptt_config.lua
return {
  AUDIO_DEVICE_NAME = "MacBook Pro Microphone",
  DYNAMIC_MODEL = true,
  KEYS = {
    HOLD = { mods = {"cmd", "alt", "ctrl"}, key = "space" },
  },
  SOUND_ENABLED = false,
  LOG_ENABLED = true,
  DEBUG_MODE = false,
}
```

See `hammerspoon/ptt_config.lua.sample` for the full list of options.
