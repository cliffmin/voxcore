# macos-ptt-dictation

Press-and-hold F13 to record; release to transcribe offline (openai-whisper via pipx) and paste at the cursor. Audio is captured with ffmpeg (avfoundation :0 -> 16 kHz mono s16 WAV). Transcripts are reflowed from Whisper JSON segments and pasted, with files saved under ~/Documents/VoiceNotes.

Goals
- Source of truth for this one feature (track changes as complexity grows)
- Portability for quick reinstall/restore on a fresh Mac

Architecture (current)
- Hammerspoon module: hammerspoon/push_to_talk.lua
- Config: hammerspoon/ptt_config.lua (domain prompt, gap thresholds, disfluencies)
- ffmpeg: /opt/homebrew/bin/ffmpeg
- Whisper CLI: ~/.local/bin/whisper (pipx venv for openai-whisper)
- Model/params: base.en, beam_size=3, language=en, temperature=0, device=cpu, timeout=15s
- Preprocess for clips ≥12s: loudnorm + light compression -> .norm.wav
- UX: red dot (recording), orange blinking (transcribing), success/failure sounds

Install (fresh machine)
1) Clone repo
   git clone <your-private-remote-url> ~/code/macos-ptt-dictation
2) Run installer (installs ffmpeg via Brewfile, ensures pipx + openai-whisper, creates symlink)
   bash ~/code/macos-ptt-dictation/scripts/install.sh
3) Reload Hammerspoon
   - Hammerspoon menu bar icon → Reload Config
4) Test
   - Press-and-hold F13 to record, release to transcribe and paste

Uninstall / rollback
- Run:
  bash ~/code/macos-ptt-dictation/scripts/uninstall.sh
- This removes the symlink and restores the latest backup of ~/.hammerspoon/push_to_talk.lua if available.

Source of truth policy
- The repo file hammerspoon/push_to_talk.lua is the canonical source of truth for this feature.
- ~/.hammerspoon/push_to_talk.lua is a symlink to the repo file for runtime loading.
- Runtime data (~/Documents/VoiceNotes) is NOT tracked in git.

Recommended workflows
- Daily use
  - Use as normal: F13 press-and-hold → release → paste.
  - Diagnostics: Cmd+Alt+Ctrl+I shows config and avfoundation devices in Hammerspoon logs.

- Making changes (safe, reviewable)
  1) Edit the module in the repo
     - File: ~/code/macos-ptt-dictation/hammerspoon/push_to_talk.lua
     - The ~/.hammerspoon symlink ensures Hammerspoon loads the updated code.
  2) Reload Hammerspoon and test
     - Menu → Reload Config
     - Quick smoke tests: short clip (2–4s), medium (10–15s). Confirm .json/.txt outputs and paste.
  3) Stage and commit changes with a clear message
     - git -C ~/code/macos-ptt-dictation add -p
     - git -C ~/code/macos-ptt-dictation commit -m "ptt: <concise change summary>"
  4) Push to your private remote
     - git -C ~/code/macos-ptt-dictation push origin main

- Versioning milestones
  - Optionally tag stable versions: git -C ~/code/macos-ptt-dictation tag -a v0.1.0 -m "initial extraction" && git -C ~/code/macos-ptt-dictation push origin v0.1.0

Config tips
- Domain prompt (ptt_config.lua INITIAL_PROMPT): nudge Whisper toward your vocabulary (e.g., Raycast, Hammerspoon, instruction precedence/consent gating) to reduce mishears.
- Gap thresholds (GAP_NEWLINE_SEC/DOBULE_NEWLINE): newline only at sentence end or >= 1.75s gaps; adjust to taste.
- Disfluencies (DISFLUENCIES): whole-word removal at boundaries (e.g., "uh", "um").
- Device stability: currently device=cpu for reliability on macOS/PyTorch 3.13. If you enable MPS, also set --fp16 True in the invocation.
- Model speed: base.en is a good balance. tiny.en is faster but less accurate.
- Preprocessing: only runs for clips ≥12s; adjust PREPROCESS_MIN_SEC if desired.

Portability checklist
- Brewfile installs ffmpeg; whisper-cpp is optional and not used in this flow.
- Installer ensures pipx and (re)installs openai-whisper in its own venv.
- Symlink keeps ~/.hammerspoon/push_to_talk.lua pointing at the repo.

Logging (JSONL)
- Default path: ~/Documents/VoiceNotes/tx_logs/tx-YYYY-MM-DD.jsonl
- One JSON object per line, examples of fields:
  {
    "ts": "2025-08-30T21:59:30Z",
    "kind": "success" | "error" | "timeout" | "no_transcript",
    "app": "macos-ptt-dictation",
    "model": "base.en",
    "device": "cpu",
    "beam_size": 3,
    "lang": "en",
    "config": {"reflow_mode": "gap", "gap_newline_sec": 1.75, "gap_double_newline_sec": 2.50, "preprocess_min_sec": 12.0, "timeout_ms": 15000, "disfluencies": ["uh","um"], "initial_prompt_len": 120},
    "wav": "/Users/you/Documents/VoiceNotes/2025-08-30_21-59-01.wav",
    "wav_bytes": 238670,
    "duration_sec": 6.1,
    "preprocess_used": false,
    "audio_used": "/Users/you/Documents/VoiceNotes/2025-08-30_21-59-01.wav",
    "json_path": "/Users/you/Documents/VoiceNotes/2025-08-30_21-59-01.json",
    "tx_ms": 1450,
    "tx_code": 0,
    "transcript_chars": 67,
    "transcript": "<exact text pasted>"
  }
- Toggle via ptt_config.lua: LOG_ENABLED=true/false and optional LOG_DIR override.

Repository hygiene
- .gitignore excludes system cruft; keep runtime data out of git.
- Keep commits small and focused; prefer logical units of change.

Future (optional)
- Migrate to faster-whisper or whisper.cpp backend for speed while keeping the same Hammerspoon wrapper.
- Consider a config.lua to externalize tunables (device/model/thresholds) without editing code.

License
- MIT (see LICENSE)

