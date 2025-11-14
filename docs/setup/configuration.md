# Configuration Guide

Configuration is done via `~/.hammerspoon/ptt_config.lua` (a sample is installed by `scripts/setup/install.sh`).

XDG fallback
- Also supported: `~/.config/voxcore/ptt_config.lua` or `$XDG_CONFIG_HOME/voxcore/ptt_config.lua` (legacy macos-ptt-dictation paths also supported)

## Core Settings

### Audio Device
```lua
AUDIO_DEVICE_INDEX = 1  -- Set to your microphone index (1 = MacBook Pro Microphone)
```
Use `Cmd+Alt+Ctrl+I` to list available devices.

Notes:
- macOS may expose your iPhone as an input ("iPhone … Microphone") via Continuity. If recordings switch to iPhone unexpectedly, set AUDIO_DEVICE_INDEX to your Mac’s built‑in mic (see device list), or run `make auto-audio` to auto‑select and update `~/.hammerspoon/ptt_config.lua`.
- Device list (CLI):
  ```bash
  /opt/homebrew/bin/ffmpeg -f avfoundation -list_devices true -i '' 2>&1 | sed -n 's/^\[AVFoundation.*\] //p'
  ```

### Transcription Model
```lua
INITIAL_PROMPT = "..."  -- Domain-specific vocabulary to improve accuracy
```
Add technical terms, product names, or jargon you use frequently.

## Text Processing

### Formatting Thresholds
```lua
GAP_NEWLINE_SEC = 1.75         -- Insert newline for pauses >= this
GAP_DOUBLE_NEWLINE_SEC = 2.50  -- Insert paragraph break for longer pauses
```

### Cleanup Options
```lua
DISFLUENCIES = {"uh", "um", "uhh", "uhm"}  -- Remove these filler words
DISFLUENCY_BEGIN_STRIP = true               -- Strip common starters
BEGIN_DISFLUENCIES = {"so", "um", "uh", "like", "you know", "okay", "yeah", "well"}

AUTO_CAPITALIZE_SENTENCES = true  -- Capitalize after punctuation
DEDUPE_IMMEDIATE_REPEATS = true   -- Remove duplicate words
DROP_LOWCONF_SEGMENTS = true      -- Filter low-confidence segments
```

### Custom Replacements
```lua
DICTIONARY_REPLACE = {
  ["github"] = "GitHub",
  ["json"] = "JSON",
  -- Add your common corrections here
}
```

## User Experience

### Audio Feedback
```lua
SOUND_ENABLED = true     -- Play sound cues
ARM_DELAY_MS = 700       -- Delay before recording starts
WAVE_METER_MODE = "off"  -- Visual feedback ("off", "inline", "monitor")
```

### Recording Modes
```lua
SHIFT_TOGGLE_ENABLED = true  -- Enable Shift+F13 for toggle recording

OUTPUT = {
  HOLD = { mode = "paste", format = "txt" },    -- hold behavior (key configurable)
  TOGGLE = { mode = "editor", format = "md" }   -- toggle behavior (key configurable)
}
```

### Key Bindings
```lua
-- Change the hotkeys (defaults shown)
KEYS = {
  HOLD = { mods = {"cmd","alt","ctrl"}, key = "space" },            -- default: Hyper+Space
  TOGGLE = { mods = {"cmd","alt","ctrl","shift"}, key = "space" },  -- default: Shift+Hyper+Space
  INFO = { mods = {"cmd","alt","ctrl"}, key = "I" },
  REFINER_TEST = { mods = {"cmd","alt","ctrl"}, key = "R" },
  DIAGNOSTICS = { mods = {"cmd","alt","ctrl"}, key = "D" },
}
```

Notes:
- Keys use Hammerspoon identifiers (e.g., "f13", "f18", "space", "I").
- Choose a spare key that doesn’t interfere with typing. External keyboards often have F13–F19; foot pedals also work well.

## Advanced Settings

### Performance
```lua
TIMEOUT_MS = 120000           -- Transcription timeout (2 minutes)
PREPROCESS_MIN_SEC = 12       -- Normalize audio for clips >= this duration
```

### Storage
```lua
NOTES_DIR = "~/Documents/VoiceNotes"  -- Where recordings are saved
PREPROCESS_KEEP_RAW = false           -- Keep original audio after normalization
CANONICALIZE_NORMALIZED_TO_WAV = true -- Use single canonical filename
```

### Logging
```lua
LOG_ENABLED = true  -- Enable JSONL logging for analytics
LOG_DIR = nil       -- Custom log directory (default: NOTES_DIR/tx_logs)
```

### LLM Refinement (Optional)
```lua
LLM_REFINER = {
  ENABLED = false,  -- Enable AI refinement for long-form recordings
  CMD = { "/usr/bin/java", "-jar", "path/to/voxcompose.jar" },
  TIMEOUT_MS = 9000
}
```

## Testing Features

### Test Mode
```lua
TEST_FIXTURE_EXPORT = {
  ENABLED = true,  -- Export test fixtures when in test mode (Fn+T)
  MODE = "auto"    -- Categorize by duration automatically
}
```

## Example Configuration

```lua
-- ~/.hammerspoon/ptt_config.lua
return {
  -- Use MacBook microphone
  AUDIO_DEVICE_INDEX = 1,
  
  -- Improve accuracy for technical terms
  INITIAL_PROMPT = "software development, API, GitHub, JavaScript, Python",
  
  -- Clean up transcripts
  AUTO_CAPITALIZE_SENTENCES = true,
  DEDUPE_IMMEDIATE_REPEATS = true,
  
  -- Custom corrections
  DICTIONARY_REPLACE = {
    ["github"] = "GitHub",
    ["api"] = "API",
    ["javascript"] = "JavaScript"
  },
  
  -- Enable all features
  SOUND_ENABLED = true,
  SHIFT_TOGGLE_ENABLED = true,
  LOG_ENABLED = true
}
```

## Troubleshooting

- **Wrong microphone**: Update `AUDIO_DEVICE_INDEX` after checking with `Cmd+Alt+Ctrl+I`
- **Poor accuracy**: Add domain terms to `INITIAL_PROMPT`
- **Formatting issues**: Adjust `GAP_NEWLINE_SEC` thresholds
- **Missing words**: Check `DISFLUENCIES` isn't removing wanted words

See [Troubleshooting](troubleshooting.md) for more help.
