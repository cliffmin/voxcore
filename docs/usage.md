# Usage

## Core
- Hold Cmd+Alt+Ctrl+Space to record; release to transcribe and paste at the cursor
- Shift+Cmd+Alt+Ctrl+Space toggles long-form recording (press again to stop)
- Output files (per-session folder under ~/Documents/VoiceNotes): .wav, .json (from Whisper), .txt (reflowed transcript)

## Key customization
Edit ~/.hammerspoon/ptt_config.lua to change keys, thresholds, or output routing.

## Corrections and cleanup
- Java post-processor fixes disfluencies, capitalization, punctuation, merged words, and common technical terms
- Optional personal corrections via dictionary: ~/.config/ptt-dictation/corrections.lua
- For details on the Java CLI, see whisper-post-processor/README.md

## Models
- Default model selection balances speed and accuracy automatically by duration
- You can pin a model in ptt_config.lua if desired (e.g., base.en or medium.en)

## Diagnostics
- Device list: ffmpeg -f avfoundation -list_devices true -i '' 2>&1 | sed -n 's/^\[AVFoundation.*\] //p'
- Quick status: make status; hot reload: make reload

## Notes
- Advanced long-form AI refinement (VoxCompose/Ollama) is out of scope for VoxCore and documented in the VoxCompose repo
