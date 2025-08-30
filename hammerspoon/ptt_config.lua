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

  -- Logging
  LOG_ENABLED = true,               -- append JSONL logs per transcription event
  LOG_DIR = nil,                    -- default: NOTES_DIR/tx_logs (set in code)
}

