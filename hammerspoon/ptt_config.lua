-- hammerspoon/ptt_config.lua
-- Tunables for macos-ptt-dictation

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
  
  -- Model selection by audio duration (optional advanced configuration)
  -- Set MODEL_BY_DURATION to use different models based on recording length
  MODEL_BY_DURATION = {
    ENABLED = false,               -- Set to true to enable dynamic model selection
    SHORT_SEC = 12.0,              -- Clips <= this use MODEL_SHORT
    MODEL_SHORT = "base.en",       -- Fast model for quick dictation
    MODEL_LONG = "medium.en",      -- Accurate model for longer content
  },
  
  -- Reflow thresholds (seconds)
  GAP_NEWLINE_SEC = 1.75,           -- insert newline at sentence end or if gap exceeds this
  GAP_DOUBLE_NEWLINE_SEC = 2.50,    -- paragraph break for larger gaps

  -- Disfluency list to strip as standalone words (not inside tokens)
  DISFLUENCIES = { "uh", "um", "uhh", "uhm" },
  -- HOLD: classic press-and-hold F13 flow (paste)
  -- TOGGLE: Shift+F13 long-form flow (editor markdown)
  SHIFT_TOGGLE_ENABLED = true,
  OUTPUT = {
    HOLD = { mode = "paste",  format = "txt" },
    TOGGLE = { mode = "editor", format = "md" },
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
  BEGIN_DISFLUENCIES = { "so", "um", "uh", "like", "you know", "okay", "yeah", "well" },
  AUTO_CAPITALIZE_SENTENCES = true,
  DEDUPE_IMMEDIATE_REPEATS = true,
  DROP_LOWCONF_SEGMENTS = true,
  LOWCONF_NO_SPEECH_PROB = 0.5,
  LOWCONF_AVG_LOGPROB = -1.0,
  DICTIONARY_REPLACE = {
    ["reposits"] = "repositories",
    ["camera positories"] = "repositories",
    ["github"] = "GitHub",
    -- Recurring mishears observed in transcripts
    ["withe"] = "with the",
    ["sim links"] = "symlinks",
    ["lincoln"] = "symlink",
    ["XDD"] = "XDG",
    ["Jura"] = "Jira",
    ["Jason"] = "JSON",
    ["no-sequel"] = "NoSQL",
    ["no sequel"] = "NoSQL",
    ["Abilare attacks"] = "Avalara tax",
    ["D-Doop"] = "dedupe",
    ["D Doop"] = "dedupe",
    ["retaster"] = "retest",
    ["complexity made metrics"] = "complexity metrics",
    ["deadly role"] = "lead role",
    ["pads"] = "paths",
  },
  PASTE_TRAILING_NEWLINE = false,
  ENSURE_TRAILING_PUNCT = false,

  -- Logging
  LOG_ENABLED = true,               -- append JSONL logs per transcription event
  LOG_DIR = nil,                    -- default: NOTES_DIR/tx_logs (set in code)
}

