-- hammerspoon/ptt_config.lua
-- Tunables for VoxCore

return {
  -- Domain prompt biases Whisper toward your vocabulary and phrasing.
  INITIAL_PROMPT = table.concat({
    "Software and product operations; Hammerspoon/macOS automation; Raycast and Spotlight; ",
    "instruction precedence and consent gating; options, recommendations, flags, defaults; ",
    "CLI, Brew, pipx, transcription, dictation, clipboard paste; symlink; complexity metrics; retest and commit."
  }),

  -- Whisper model configuration
  -- Based on comprehensive testing (see docs/model_comparison.md):
  -- - base.en: Fast (3-8s), 19.89% WER, struggles with technical terms
  -- - small.en: Moderate (4-10s), 19.19% WER, minimal improvement
  -- - medium.en: Slower (8-22s), 16.86% WER, best accuracy, handles technical terms well
  WHISPER_MODEL = "medium.en",      -- Recommended: best accuracy for technical content
  
  -- Whisper implementation (PERFORMANCE CRITICAL)
  -- Options:
  --   "whisper-cpp" - C++ implementation, 5-10x faster (RECOMMENDED)
  --   "openai-whisper" - Python implementation, slower but more features
  --   nil/false - auto-detect (prefers whisper-cpp if available)
  WHISPER_IMPL = nil,  -- Auto-detect by default
  
  -- Model selection by audio duration (optional advanced configuration)
  -- Set MODEL_BY_DURATION to use different models based on recording length
  MODEL_BY_DURATION = {
    ENABLED = true,                -- ENABLED: Use fast base.en for short clips
    SHORT_SEC = 21.0,              -- Clips <= 21s use base.en (fast)
    MODEL_SHORT = "base.en",       -- Fast model for quick dictation
    MODEL_LONG = "medium.en",      -- Accurate model for longer content (>21s)
  },
  
  -- Reflow thresholds (seconds)
  GAP_NEWLINE_SEC = 1.75,           -- insert newline at sentence end or if gap exceeds this
  GAP_DOUBLE_NEWLINE_SEC = 2.50,    -- paragraph break for larger gaps

  -- Disfluency list to strip as standalone words (not inside tokens)
  -- These are universal filler words that should be removed
  DISFLUENCIES = { "uh", "um", "uhh", "uhm" },
  -- HOLD: classic press-and-hold F13 flow (paste)
  -- TOGGLE: Shift+F13 long-form flow (editor markdown)
  SHIFT_TOGGLE_ENABLED = true,
  OUTPUT = {
    HOLD = { mode = "paste",  format = "txt" },         -- F13 hold: always paste
    TOGGLE = { mode = "paste", format = "txt" },        -- F13 double-tap: always paste
    SHIFT_TOGGLE = { mode = "editor", format = "md" },  -- Shift+F13: always markdown editor
  },
  -- Double-tap F13 to toggle (in addition to Shift+F13)
  DOUBLE_TAP_TOGGLE = true,
  DOUBLE_TAP_WINDOW_MS = 300,

  -- Key bindings (configurable)
  KEYS = {
    HOLD = { mods = {}, key = "f13" },
    TOGGLE = { mods = {"shift"}, key = "f13" },
    INFO = { mods = {"cmd","alt","ctrl"}, key = "I" },
    REFINER_TEST = { mods = {"cmd","alt","ctrl"}, key = "R" },
    DIAGNOSTICS = { mods = {"cmd","alt","ctrl"}, key = "D" },
  },

  -- UX cues
  SOUND_ENABLED = true,           -- play short cues on arm/finish
  ARM_DELAY_MS = 700,             -- fallback arming delay before "speak now" cue (increased for reliability)
  WAVE_METER_MODE = "off",        -- disable broken wave meter ("inline", "monitor", or "off")

  -- Optional LLM refiner (requires VoxCompose CLI)
  -- When enabled for TOGGLE sessions, the transcript will be
  -- piped to the refiner CLI, which returns refined Markdown to save + open.
  LLM_REFINER = {
    ENABLED = false,  -- Set to true if you have VoxCompose installed
    -- Example configuration (adjust paths to match your installation):
    -- CMD = { "/usr/bin/java", "-jar", (os.getenv("HOME") or "") .. "/path/to/voxcompose.jar" },
    -- ARGS = { "--model", "llama3.1", "--timeout-ms", "8000" },
    CMD = {},  -- Set your command here
    ARGS = {},  -- Set your arguments here
    TIMEOUT_MS = 9000,
  },

  -- Optional punctuation restorer (deepmultilingualpunctuation)
  -- Restores punctuation and capitalization on raw ASR text.
  -- Enabled by default for TOGGLE (long-form) sessions only to avoid cold-start
  -- overhead during quick HOLD-to-paste.
  PUNCTUATOR = {
    ENABLED_FOR_TOGGLE = true,
    ENABLED_FOR_HOLD = false,
    -- Command to invoke; default uses repo-local scripts/utilities/punctuate.py via Python 3
    CMD = { "/usr/bin/env", "python3", (os.getenv("HOME") or "") .. "/code/voxcore/scripts/utilities/punctuate.py" },
    TIMEOUT_MS = 2500,  -- fail open (pass-through) after this many ms
  },

  -- Test fixture export (local, never committed)
  TEST_FIXTURE_EXPORT = {
    ENABLED = true,               -- when in TEST mode, export fixtures automatically
    MODE = "auto",                -- "auto" duration-based; "manual" = use Fn+1/2/3 override
    MICROTAP_MAX_SEC = 1.0,       -- <= this -> micro bucket
    SHORT_MAX_SEC = 10,
    MEDIUM_MAX_SEC = 30,
    DEST_DIR = nil,               -- default: <repo>/tests/fixtures/samples_current
    LINK_JSON = true,
    LINK_TXT = true,
    -- Complexity scoring
    TRICKY_TOKENS = {
      "json", "jira", "nosql", "symlink", "symlinks", "xdg", "avalara", "tax", "dedupe", "lead role", "paths",
      "dynamodb", "salesforce", "hyperdx", "postman", "oauth", "ffmpeg", "avfoundation", "base.en", "normalize", "loudnorm", "acompressor"
    },
    SCORE_WEIGHTS = { CHARS = 1.0, TRICKY = 6.0 },
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

  -- Audio device index (avfoundation): set to your preferred input
  -- Use Cmd+Alt+Ctrl+I to list devices
  -- IMPORTANT: Set to 1 for MacBook Pro Microphone to avoid webcam mic issues
  AUDIO_DEVICE_INDEX = 1,

  -- Reflow and post-processing toggles
  DISFLUENCY_BEGIN_STRIP = true,
  -- Common beginning fillers - keep minimal universal set
  BEGIN_DISFLUENCIES = { "um", "uh" },
  AUTO_CAPITALIZE_SENTENCES = true,
  DEDUPE_IMMEDIATE_REPEATS = true,
  DROP_LOWCONF_SEGMENTS = true,
  LOWCONF_NO_SPEECH_PROB = 0.5,
  LOWCONF_AVG_LOGPROB = -1.0,
  -- Dictionary replacements are now loaded from external files
  -- To use custom corrections:
  -- 1. Create ~/.config/ptt-dictation/corrections.lua
  -- 2. Add your personal corrections there
  -- 3. Or wait for VoxCompose integration for automatic learning
  DICTIONARY_REPLACE = nil,  -- Will auto-load from external sources
  PASTE_TRAILING_NEWLINE = false,
  ENSURE_TRAILING_PUNCT = false,

  -- Logging
  LOG_ENABLED = true,               -- append JSONL logs per transcription event
  LOG_DIR = nil,                    -- default: NOTES_DIR/tx_logs (set in code)
}

