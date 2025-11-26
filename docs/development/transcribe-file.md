# Transcribe a Local Audio File and Paste

Manual workflow to emulate the push-to-talk flow using an existing audio file.

## Quick Start

```bash
# Build JAR and ensure daemon will start on first use
make dev-install

# Transcribe and paste the result at the cursor
make paste-file AUDIO=/absolute/path/to/audio.wav [MODEL=base.en]
```

This uses:
- PTTServiceDaemon (`http://127.0.0.1:8765`) to normalize and transcribe
- Java post-processor (whisper-post.jar) to clean up text
- Clipboard + Cmd+V to paste into the front-most app

## Script
The implementation lives at `scripts/utilities/transcribe_and_paste.sh`.

Options:
- `AUDIO` (required): absolute path to audio
- `MODEL` (optional): whisper model name (e.g., `base.en`, `small.en`)
- Add `--no-paste` to the script to just print instead of pasting.

## Troubleshooting
- If you see `Missing 'jq'` → `brew install jq`
- If daemon isn’t responding, `make dev-install` will build the JAR and reload Hammerspoon which auto-starts the daemon on demand.
- Logs:
  - Daemon: `/tmp/ptt_daemon.log`
  - Hammerspoon: Console > Hammerspoon
