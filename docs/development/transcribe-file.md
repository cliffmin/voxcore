# Transcribe a Local Audio File

Manual workflow to emulate the push-to-talk flow using an existing audio file.

## Quick Start

```bash
# Build JAR and ensure daemon will start on first use
make dev-install

# Transcribe and print the processed text (no paste)
make transcribe /absolute/path/to/audio.wav
```

This uses:
- PTTServiceDaemon (`http://127.0.0.1:8765`) to normalize and transcribe
- Java post-processor (whisper-post.jar) to clean up text

## Script
The implementation lives at `scripts/utilities/transcribe_and_paste.sh`.

Options:
- Pass the audio path as an argument: `make transcribe /path/to/audio.wav`
- Optionally set `MODEL` (e.g., `small.en`) via the script directly
- Runs with `--no-paste` by default (prints output only)

## Troubleshooting
- If you see `Missing 'jq'` → `brew install jq`
- If daemon isn’t responding, `make dev-install` will build the JAR and reload Hammerspoon which auto-starts the daemon on demand.
- Logs:
  - Daemon: `/tmp/ptt_daemon.log`
  - Hammerspoon: Console > Hammerspoon
