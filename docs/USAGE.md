# Usage

## Daily
- Hold F13 to record. Release to transcribe and paste at the cursor.
- Toggle long-form: Shift+F13 to start; press again to stop.
- Optional refine (if VoxCompose is configured): long-form transcript is refined to Markdown and saved under ~/Documents/VoiceNotes/refined.

## Outputs
- Each session has its own folder under ~/Documents/VoiceNotes, named by timestamp.
- Files inside a session folder:
  - <timestamp>.wav (canonical WAV)
  - <timestamp>.json (Whisper JSON)
  - <timestamp>.txt (reflowed transcript)

## Logs
- JSONL at ~/Documents/VoiceNotes/tx_logs/tx-YYYY-MM-DD.jsonl
- Toggle logging via ptt_config.lua

## Diagnostics
- List devices: /opt/homebrew/bin/ffmpeg -f avfoundation -list_devices true -i '' 2>&1 | sed -n 's/^\[AVFoundation.*\] //p'
- Whisper CLI help: ~/.local/bin/whisper --help | head -n 5
- Check the Hammerspoon symlink: ls -l ~/.hammerspoon/push_to_talk.lua

