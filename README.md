# macos-ptt-dictation

Press-and-hold F13 to record; release to transcribe offline (openai-whisper via pipx) and paste at the cursor. Audio is captured with ffmpeg (avfoundation :0 -> 16 kHz mono s16 WAV). Transcripts are reflowed from Whisper JSON segments and pasted.

Storage: each recording is saved in its own folder under ~/Documents/VoiceNotes, named by timestamp (e.g., ~/Documents/VoiceNotes/2025-Jun-25_11.15.30_AM/), containing exactly one canonical WAV plus its JSON and TXT:
- 2025-Jun-25_11.15.30_AM.wav
- 2025-Jun-25_11.15.30_AM.json
- 2025-Jun-25_11.15.30_AM.txt

Goals
- Source of truth for this one feature (track changes as complexity grows)
- Portability for quick reinstall/restore on a fresh Mac

Architecture (current)
- Hammerspoon module: hammerspoon/push_to_talk.lua
- Config: hammerspoon/ptt_config.lua (domain prompt, gap thresholds, disfluencies)
- ffmpeg: /opt/homebrew/bin/ffmpeg
- Whisper CLI: ~/.local/bin/whisper (pipx venv for openai-whisper)
- Model/params: base.en, beam_size=3, language=en, temperature=0, device=cpu, timeout=120s (configurable TIMEOUT_MS)
- Preprocess for clips ≥12s: loudnorm + light compression -> .norm.wav (normalized audio replaces raw for long clips)
- Storage layout: per-recording folder named like 2025-Jun-25_11.15.30_AM containing WAV/JSON/TXT for that session
- UX: red dot (recording), orange blinking (transcribing), success/failure sounds; optional on-screen wave bars while recording

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
  - Long-form: Shift+F13 toggles recording on/off. After transcription, optional refine (VoxCompose) to Markdown and open in your default editor.
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
- Shift+F13 toggle + refine: In ptt_config.lua set SHIFT_TOGGLE_ENABLED=true. To enable refine, set LLM_REFINER.ENABLED=true and point CMD to your VoxCompose jar; Markdown files save under ~/Documents/VoiceNotes/refined and open via macOS.
- Device stability: currently device=cpu for reliability on macOS/PyTorch 3.13. If you enable MPS, also set --fp16 True in the invocation.
- Model speed: base.en is a good balance. tiny.en is faster but less accurate.
- Preprocessing: only runs for clips ≥12s; adjust PREPROCESS_MIN_SEC if desired.
- Timeout: default TIMEOUT_MS=120000 (2 minutes). On timeout, an on-screen alert includes the recording name and duration.
- Notes directory: override NOTES_DIR in ptt_config.lua (default ~/Documents/VoiceNotes).
- Hotkeys (Fn combos): Fn+T toggle test/live logs; Fn+R reloads Hammerspoon config; Fn+O opens ~/.hammerspoon/init.lua in VS Code.

Portability checklist
- Brewfile installs ffmpeg; whisper-cpp is optional and not used in this flow.
- Installer ensures pipx and (re)installs openai-whisper in its own venv.
- Symlink keeps ~/.hammerspoon/push_to_talk.lua pointing at the repo.
- Migration utilities: scripts/migrate_voicenotes_names.zsh and scripts/migrate_voicenotes_to_folders.zsh can rename old files and reorganize to the per-recording folder layout.

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
    "config": {"reflow_mode": "gap", "gap_newline_sec": 1.75, "gap_double_newline_sec": 2.50, "preprocess_min_sec": 12.0, "timeout_ms": 120000, "disfluencies": ["uh","um"], "initial_prompt_len": 120},
    "wav": "/Users/you/Documents/VoiceNotes/2025-Aug-30_12.31.34_AM/2025-Aug-30_12.31.34_AM.wav",
    "wav_bytes": 238670,
    "duration_sec": 6.1,
    "preprocess_used": false,
    "audio_used": "/Users/you/Documents/VoiceNotes/2025-Aug-30_12.31.34_AM/2025-Aug-30_12.31.34_AM.wav",
    "json_path": "/Users/you/Documents/VoiceNotes/2025-Aug-30_12.31.34_AM/2025-Aug-30_12.31.34_AM.json",
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

Interplay with VoxCompose (optional refine)
- Long-form (Shift+F13) can optionally run a second-pass refinement via the separate VoxCompose Java CLI.
- Flow:
  1) Capture + local Whisper transcription (this repo)
  2) Reflow transcript text (this repo)
  3) Optional refine to Markdown via VoxCompose (Ollama local model)
  4) Save .md under ~/Documents/VoiceNotes/refined and open in your OS default editor
- Enable/disable: hammerspoon/ptt_config.lua → LLM_REFINER.ENABLED (true/false)
- VoxCompose jar path: LLM_REFINER.CMD points at ~/code/voxcompose/build/libs/voxcompose-0.1.0-all.jar by default
- Memory: VoxCompose optionally reads JSONL at ~/Library/Application Support/voxcompose/memory.jsonl to incorporate preferences/glossary items

Why separate repos
- Clear separation of concerns:
  - macos-ptt-dictation: macOS automation, hotkeys, audio capture, Whisper transcription, UX, file and log management.
  - VoxCompose: language-model-backed refinement and formatting, pluggable provider, memory features.
- Modularity and reuse: VoxCompose is a standalone CLI usable by other tools/pipelines.
- Portfolio and maintainability: distinct technologies (Lua/macOS vs Java/LLM) with their own tests, versioning, and release cadence.

Single-file audio policy (canonical output)
- Per-recording folder: each session saves to ~/Documents/VoiceNotes/<timestamp>/ with WAV/JSON/TXT.
- Short clips: one file — <timestamp>/<timestamp>.wav (raw).
- Long clips (≥ PREPROCESS_MIN_SEC): audio is normalized, then the normalized content replaces the raw — still one file, <timestamp>/<timestamp>.wav.
- Controls in ptt_config.lua:
  - PREPROCESS_KEEP_RAW = false (delete raw when normalization succeeds)
  - CANONICALIZE_NORMALIZED_TO_WAV = true (rename normalized file to <timestamp>.wav)

Integration test (local long-form WAV; no audio in git)
- Script: tests/integration/longform_to_markdown.sh
  - Uses LONGFORM_WAV_PATH env var or tests/fixtures/local_longform.wav symlink to your local WAV.
  - Steps: Whisper → temp JSON/TXT → VoxCompose → Markdown → basic structure assertion.
- Smoke tests: tests/smoke/*.sh (module loads, hotkeys bound)
- Docs: tests/README.md
- Gitignore excludes tests/fixtures/*.wav so personal audio stays out of version control.

Requirements summary
- This repo: Hammerspoon, ffmpeg (Brewfile), pipx-installed whisper CLI.
- VoxCompose: Java 17+, Ollama with a pulled model (e.g., llama3.1), built jar at build/libs/voxcompose-0.1.0-all.jar.

License
- MIT (see LICENSE)

