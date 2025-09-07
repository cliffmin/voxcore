# E2E Speech Test Script

Read this out loud to validate end-to-end behavior. Perform two passes:
- Pass A (F13 hold): paste unrefined transcript
- Pass B (Shift+F13 toggle): refined Markdown via VoxCompose

Tips
- Use a clear mic at a normal distance.
- Follow the timed pauses; they exercise gap-based reflow.
- After each pass, inspect ~/Documents/VoiceNotes/<timestamp>/ and tx_logs for canonical_wav, audio_processing_chain, reflow_* fields.

Section 1: Short clip (~6–8s)
- Say: "Quick smoke test of push-to-talk. JSON, Jira, NoSQL, symlinks, XDG."
- Pause: 1s
- Say: "Avalara tax, dedupe, lead role, file paths."

Section 2: Medium clip (~20–25s)
- Say (start with a disfluency): "So, um, you know, this is a medium-length test to validate reflow and dictionary replacements."
- Pause: 1s
- Say: "We will mention DynamoDB, Salesforce, HyperDX, and Postman collections."
- Pause: 2s
- Say: "Ensure tricky phrases are correct: with the lines; JSON, not Jason; symlinks, not sim links; XDG, not XDD; Jira, not Jura; NoSQL, not no-sequel; Avalara tax, not Abilare attacks; dedupe, not D-Doop; lead role, not deadly role; paths, not pads."

Section 3: Long clip (~60–75s)
- Say: "This is a longer passage to cross the preprocessing threshold and validate normalization."
- Pause: 2s
- Say: "In our architecture, the audio is captured with ffmpeg via avfoundation, then Whisper base-dot-en transcribes to segments in JSON."
- Pause: 1s
- Say: "The module reflows text based on segment gaps: small gaps become spaces; sentence ends or gaps above one-point-seven-five seconds become newlines; gaps above two-point-five seconds become paragraph breaks."
- Pause: 3s
- Say: "We also test post-processing: remove disfluency starters like 'so', 'um', 'uh'; dedupe immediate repeats; capitalize sentences."
- Pause: 1s
- Say: "Domain terms and acronyms: JSON, YAML, HTTP, Jira, OAuth; DynamoDB, NoSQL; HyperDX logging; Postman tests; Avalara tax; symlinks; XDG base directories; dedupe; file paths; lead role."
- Pause: 2s
- Say: "Finally, we check that canonicalization results in a single WAV per session and that telemetry includes canonical_wav and audio_processing_chain, along with reflow_total_segments and reflow_dropped_segments."

Section 4: Micro-tap (hold <150ms)
- Tap F13 extremely briefly and release (under 150ms). Expect a '[No transcript: recording too short]' fallback.

How to run
1) Pass A (F13)
- Hold F13 and read Section 1 and 2 (about 25–30 seconds total). Release.
- Verify paste content and tx_logs fields.

2) Pass B (Shift+F13)
- Press Shift+F13 to start. Read Section 3 (60–75 seconds). Press Shift+F13 to stop.
- A Markdown file should open (refined). Verify tx_logs contains refine_ms, refine_provider, refine_model and canonical_wav/audio_processing_chain.

3) Micro-tap (F13)
- Do Section 4 and confirm a graceful fallback message.

