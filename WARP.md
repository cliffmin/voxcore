# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Rules Precedence
Global rules apply across prompts, but repository rules take precedence within this project. See canonical global rules at:
~/ai/global-rules/GlobalRules.md

## Overview
This repo delivers a macOS push-to-talk dictation workflow powered by Hammerspoon (Lua), ffmpeg audio capture, and the openai-whisper CLI via pipx. Hold F13 to record; on release the audio is transcribed offline and pasted at the cursor. Runtime artifacts (WAV, JSON, TXT, JSONL logs) live under ~/Documents/VoiceNotes and are not tracked in git.

## Big-picture architecture
- Entry point (Hammerspoon module): hammerspoon/push_to_talk.lua (symlinked at ~/.hammerspoon/push_to_talk.lua).
  - Hotkeys: F13 press-to-record; release to stop and transcribe. Cmd+Alt+Ctrl+I logs diagnostics (ffmpeg/whisper presence and avfoundation devices). Fn+T toggles a global TEST mode (dry-run logging, no external commands).
  - Capture: ffmpeg (avfoundation :0) writes 16 kHz mono s16 WAV to ~/Documents/VoiceNotes.
  - Transcription: ~/.local/bin/whisper (pipx, openai-whisper) with model base.en, beam_size=3, language=en, temperature=0, device=cpu, timeout 15s.
  - Reflow: JSON segments are reflowed into readable text (gap-aware single/double newlines), with optional disfluency stripping. Falls back to .txt if JSON absent.
  - UX: small on-screen dot (red while recording, orange blinking while transcribing), sound cues, clipboard copy + paste.
  - Long audio: clips ≥12s are preprocessed (loudnorm + light compression) before transcription.
  - Logging: JSONL events in ~/Documents/VoiceNotes/tx_logs/tx-YYYY-MM-DD.jsonl (toggle via LOG_ENABLED in config).
- Config: hammerspoon/ptt_config.lua provides tunables (INITIAL_PROMPT, GAP_NEWLINE_SEC, GAP_DOUBLE_NEWLINE_SEC, DISFLUENCIES, LOG flags). Loaded as require("ptt_config") if present.
- Dependencies: /opt/homebrew/bin/ffmpeg; pipx-installed openai-whisper at ~/.local/bin/whisper. Device forced to CPU for stability on macOS.
- Policy: hammerspoon/push_to_talk.lua is the source of truth; ~/.hammerspoon/push_to_talk.lua is a symlink. Runtime data under ~/Documents/VoiceNotes is excluded from git.

## Commands you will use
- First-time setup (fresh machine):
  ```bash
  # Install ffmpeg via Brewfile
  brew bundle --no-lock --file "$(pwd)/Brewfile"

  # Ensure pipx and install/reinstall openai-whisper CLI
  python3 -m pip install --user pipx
  python3 -m pipx ensurepath || true
  pipx install --include-deps openai-whisper || pipx reinstall openai-whisper

  # Link the Hammerspoon module and finish setup
  bash ./scripts/install.sh
  # Then: Hammerspoon menu bar → Reload Config (GUI step)
  ```
- Day-to-day development:
  ```bash
  # Edit and reload Hammerspoon (GUI step) to test changes
  $EDITOR hammerspoon/push_to_talk.lua
  # Test: press-and-hold F13 to record, release to transcribe and paste
  ```
- Diagnostics and verification:
  ```bash
  # List AVFoundation devices (ffmpeg prints to stderr)
  /opt/homebrew/bin/ffmpeg -f avfoundation -list_devices true -i "" 2>&1 | sed -n 's/^\[AVFoundation.*\] //p'

  # Check whisper CLI is available
  ~/.local/bin/whisper --help | head -n 5

  # Inspect JSONL logs for today
  tail -f ~/Documents/VoiceNotes/tx_logs/tx-$(date +%F).jsonl

  # Confirm symlink in place
  ls -l ~/.hammerspoon/push_to_talk.lua
  ```
- Uninstall / rollback:
  ```bash
  bash ./scripts/uninstall.sh
  # Reload Hammerspoon (GUI step)
  ```

## Notes for future automation in this repo
- There is no test or lint suite defined; validation is manual via Hammerspoon hotkeys and inspecting outputs/logs.
- Keep runtime artifacts (~/Documents/VoiceNotes, including tx_logs) out of git; see .gitignore. The Brewfile installs ffmpeg; whisper-cpp is noted as optional but unused by this workflow.

