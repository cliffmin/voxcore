-- hammerspoon/ptt_config.lua
-- Tunables for macos-ptt-dictation

return {
  -- Domain prompt biases Whisper toward your vocabulary and phrasing.
  INITIAL_PROMPT = table.concat({
    "Software and product operations; Hammerspoon/macOS automation; Raycast and Spotlight; ",
    "instruction precedence and consent gating; options, recommendations, flags, defaults; ",
    "CLI, Brew, pipx, transcription, dictation, clipboard paste."
  }),

  -- Reflow thresholds (seconds)
  GAP_NEWLINE_SEC = 1.75,           -- insert newline at sentence end or if gap exceeds this
  GAP_DOUBLE_NEWLINE_SEC = 2.50,    -- paragraph break for larger gaps

  -- Disfluency list to strip as standalone words (not inside tokens)
  DISFLUENCIES = { "uh", "um", "uhh", "uhm" },

  -- Output modes per session type
  -- HOLD: classic press-and-hold F13 flow (paste)
  -- TOGGLE: Shift+F13 long-form flow (editor markdown)
  SHIFT_TOGGLE_ENABLED = true,
  OUTPUT = {
    HOLD = { mode = "paste",  format = "txt" },
    TOGGLE = { mode = "editor", format = "md" },
  },

  -- Optional LLM refiner (VoxCompose CLI)
  -- Disabled by default. When enabled for TOGGLE sessions, the transcript will be
  -- piped to the Java CLI, which returns refined Markdown to save + open.
  LLM_REFINER = {
    ENABLED = true,
    CMD = { "/usr/bin/java", "-jar", (os.getenv("HOME") or "") .. "/code/voxcompose/build/libs/voxcompose-0.1.0-all.jar" },
    ARGS = { "--model", "llama3.1", "--timeout-ms", "8000", "--memory", (os.getenv("HOME") or "") .. "/Library/Application Support/voxcompose/memory.jsonl" },
    TIMEOUT_MS = 9000,
  },

  -- Audio retention policy
  -- If false, when normalization succeeds for long clips (creating .norm.wav),
  -- delete the original raw .wav to avoid duplicate storage.
  PREPROCESS_KEEP_RAW = false,
  -- If true, when normalization succeeds for long clips, rename the normalized
  -- file back to the original timestamp.wav (single canonical file). If false,
  -- keep .norm.wav as the filename when normalization is used.
  CANONICALIZE_NORMALIZED_TO_WAV = true,

  -- Output directory
  -- Set this to change where audio and transcripts are saved
  NOTES_DIR = (os.getenv("HOME") or "") .. "/Documents/VoiceNotes",

  -- Logging
  LOG_ENABLED = true,               -- append JSONL logs per transcription event
  LOG_DIR = nil,                    -- default: NOTES_DIR/tx_logs (set in code)
}

