# Configuration

Edit ~/.hammerspoon/ptt_config.lua (a sample is installed by scripts/install.sh).

Key options
- INITIAL_PROMPT: domain/context prompt to bias Whisper
- GAP_NEWLINE_SEC, GAP_DOUBLE_NEWLINE_SEC: reflow thresholds
- DISFLUENCIES and BEGIN_DISFLUENCIES: remove ums/uhs
- DICTIONARY_REPLACE: domain spelling and common mishears
- PREPROCESS_MIN_SEC: normalize long clips (default 12)
- TIMEOUT_MS: Whisper timeout
- LLM_REFINER: enable/disable refine and set command path
- NOTES_DIR: change the output folder from ~/Documents/VoiceNotes

Paste behavior (coming soon)
- Policies to paste into the anchored app only, always current app, or clipboard-only

See also
- docs/USAGE.md
- docs/TROUBLESHOOTING.md
- docs/ROADMAP.md

