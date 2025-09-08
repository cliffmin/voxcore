# Auto mode, gestures, refiner modularity, and UI overlay design

Audience: internal design notes for implementing single-key control, optional double-press toggle, and optional refine.

## Goals
- Keep MVP ergonomics: press-and-hold to record, release to transcribe and paste
- Make long vs short automatic; optional double-press to toggle
- If refiner is present, use it; if not, degrade gracefully
- Replace broken waveform with a small, readable overlay near the mouse
- Make pasting predictable and safe if the user changes focus before paste

## Input gestures
- F13 press-and-hold (hold mode)
  - Keydown schedules a hold start after tap_or_hold_decision_ms (default 180 ms)
  - Keyup stops recording and triggers decision
- F13 double-press (toggle mode)
  - Two keyup events within double_tap_window_ms (default 300 ms) start a toggle recording
  - Any press while in toggle mode stops recording

Timers
- tap_or_hold_decision_ms: differentiate a tap from a hold
- double_tap_window_ms: window to detect a double-press

## Auto short vs long decision
- On stop, compute duration = now - record_start
- is_long = AUTO_MODE.enabled and duration >= long_threshold_sec (default 12)
- If short: paste baseline transcript
- If long: run preprocess + transcribe, then refine if available; on refine failure/timeout, paste baseline and alert

## Refiner capability detection
- Adapter returns provider { name, available, refine(text, opts) }
- Auto-detect on first use and cache the result
- Providers: voxcompose (preferred), none
- For voxcompose
  - CLI contract: '--in -' for stdin, '--out -' for stdout, '--sidecar <path>', '--provider ollama', '--timeout <sec>', '--task transcript_to_markdown'
  - Exit codes: 0 success, 2 provider unavailable, 3 request error, 124 timeout

## UI overlay (replace waveform)
- hs.canvas overlay anchored near current mouse position
- Modes and visuals
  - Recording: red dot with elapsed seconds
  - Transcribing: orange dot with spinner and 'Transcribing…'
  - Refining: orange dot with spinner and 'Refining…'
  - Pasted: green check and 'Pasted' for ~1.2s then auto-dismiss
- Threshold cue (optional): when holding and crossing long_threshold_sec, play a subtle sound and tint the dot
- Config flags
  - UI_OVERLAY.enabled=true
  - UI_OVERLAY.anchor='mouse'|'screen_corner'
  - UI_OVERLAY.show_ms=1200 after paste
  - UI_OVERLAY.threshold_cue=false

## Paste ergonomics
- Anchor app/window on stop (release/toggle-stop)
- Paste policy
  - 'anchor_only': paste only if the anchored app is still frontmost; else copy to clipboard and show 'Ready to paste'
  - 'always_current': paste into whatever is frontmost at paste time
  - 'clipboard_only': never paste automatically; only copy and notify
- Default: anchor_only to avoid surprising pastes in the wrong app
- Log paste_target and whether anchor matched at paste time

## State machine
States: idle → recording_hold|recording_toggle → transcribing → refining? → pasting → idle

Transitions
- idle + f13_down → schedule_hold_timer
- f13_up during schedule_hold_timer → tap (counts toward double)
- double-press detected → recording_toggle
- f13_down while recording_toggle → stop_recording
- f13_up while recording_hold → stop_recording
- stop_recording → decide short/long
- long + refine_available → refining → paste
- long + refine_unavailable or refine_failed → paste baseline
- short → paste

## Metrics and logging
- auto_mode_decision { duration_sec, threshold_sec, decided }
- refine_unavailable { provider }
- refine_result { ok, ms, tokens_in, tokens_out, stop_reason }
- paste_decision { policy, anchor_app, anchor_matched }

## Config additions (ptt_config.lua)
- INPUT_GESTURES { enabled, double_tap_window_ms, tap_or_hold_decision_ms, threshold_cue, threshold_cue_sound }
- AUTO_MODE { enabled, long_threshold_sec, fallback_on_refine_fail }
- REFINER { provider='auto'|'voxcompose'|'none', timeout_short_sec, timeout_long_sec }
- UI_OVERLAY { enabled, anchor, show_ms, threshold_cue }

## Rollout plan
- Implement behind flags; keep Shift+F13 as an escape hatch initially
- Manual tests: short under threshold, long over threshold, refine present/absent, timeout path, overlay behavior
- Observe logs for decision correctness and paste safety

