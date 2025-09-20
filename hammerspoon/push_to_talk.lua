-- ~/.hammerspoon/push_to_talk.lua
-- Press-and-hold the PTT key (default Hyper+Space) to record; release to stop, transcribe (offline), copy to clipboard, and paste at cursor.
-- Storage: ~/Documents/VoiceNotes/YYYY-MM-DD_HH-MM-SS.wav and .txt
-- Dependencies: ffmpeg (brew) and Whisper CLI installed via pipx (~/.local/bin/whisper)

local M = {}

local log = hs.logger.new("push_to_talk", "info")
local json = require("hs.json")


-- Optional external config
-- Enhanced config loader: prefer user config (~/.hammerspoon/ptt_config.lua),
-- then fall back to repo-local hammerspoon/ptt_config.lua (alongside this file).
local cfg, cfg_path_used, cfg_loaded = {}, nil, false
local function loadConfig()
  local ok, t = pcall(require, "ptt_config")
  if ok and type(t) == "table" then
    cfg = t
    cfg_loaded = true
    cfg_path_used = "require:ptt_config"
    return
  end
  -- XDG: prefer ~/.config/voxcore/ptt_config.lua or $XDG_CONFIG_HOME
  local function loadXdg()
    local xdg = os.getenv("XDG_CONFIG_HOME")
    local paths = {}
    if xdg and xdg ~= "" then
      table.insert(paths, xdg .. "/voxcore/ptt_config.lua")
    end
    table.insert(paths, (os.getenv("HOME") or "") .. "/.config/voxcore/ptt_config.lua")
    for _,p in ipairs(paths) do
      if p and hs.fs.attributes(p) then
        local okx, tx = pcall(dofile, p)
        if okx and type(tx) == "table" then
          cfg = tx; cfg_loaded = true; cfg_path_used = p; return true
        end
      end
    end
    return false
  end
  if loadXdg() then return end
  -- Fallback: load repo-local config next to this file
  local src = debug.getinfo(1, "S").source or ""
  local selfPath = src:match("^@(.*)$")
  if selfPath then
    local dir = selfPath:match("^(.*)/[^/]+$")
    local cand = dir and (dir .. "/ptt_config.lua") or nil
    if cand and hs.fs.attributes(cand) then
      local ok2, t2 = pcall(dofile, cand)
      if ok2 and type(t2) == "table" then
        cfg = t2
        cfg_loaded = true
        cfg_path_used = cand
        return
      end
    end
  end
  cfg = {}
  cfg_loaded = false
  cfg_path_used = nil
end
loadConfig()

-- Logger level compatibility (avoid warnings across Hammerspoon versions)
local function setLogLevelCompat(lg, levelStr)
  -- Try string first
  local ok = pcall(function() lg:setLogLevel(levelStr) end)
  if ok then return end
  -- Fallback numeric mapping
  local map = { debug = 4, info = 3, warning = 2, error = 1 }
  pcall(function() lg:setLogLevel(map[levelStr] or 3) end)
end

-- Helper functions needed early
local function dirname(p)
  return p and p:match("^(.*)/[^/]+$") or nil
end

local function repoRoot()
  local src = debug.getinfo(1, "S").source or ""
  local selfPath = src:match("^@(.*)$")
  if not selfPath then return nil end
  local dir = dirname(selfPath) -- .../hammerspoon
  return dir and dir:match("^(.*)/hammerspoon$") or nil
end

-- Global test mode (shared with your other modules)
local function isTestMode()
  return hs.settings.get("fn_test_mode") == true
end
local function setTestMode(v)
  hs.settings.set("fn_test_mode", v and true or false)
  setLogLevelCompat(log, v and "debug" or "info")
  local state = v and "TEST (dry-run)" or "LIVE"
  hs.alert.show("Fn mode: " .. state)
  log.i("Fn GLOBAL mode => " .. state)
  -- Initialize a new test fixture batch id when entering TEST mode
  if v then
    local rr = repoRoot()
    local shortSha = nil
    if rr and rr ~= "" then
      local cmd = string.format([[git -C %q rev-parse --short HEAD 2>/dev/null]], rr)
      local out = hs.execute(cmd) or ""
      out = out:gsub("%s+$", "")
      if out ~= "" then shortSha = out end
    end
    local bid = os.date("%Y%m%d-%H%M") .. (shortSha and ("_" .. shortSha) or "")
    hs.settings.set("ptt_fixture_batch_id", bid)
    log.i("Test fixture batch id set: " .. bid)
  else
    -- Leaving test mode does not clear batch id, so you can keep exporting into the same batch if you toggle back soon
  end
end

-- Config
local HOME = os.getenv("HOME") or ""
local NOTES_DIR = (cfg.NOTES_DIR and tostring(cfg.NOTES_DIR)) or (HOME .. "/Documents/VoiceNotes")
local FFMPEG = "/opt/homebrew/bin/ffmpeg"         -- absolute path for reliability

-- Auto-detect fastest whisper implementation
local function detectWhisper()
  -- Prefer whisper-cli (new name) or whisper-cpp (old name) - both are fast C++ implementations
  if hs.fs.attributes("/opt/homebrew/bin/whisper-cli") then
    log.i("Detected whisper-cli (fast C++ implementation)")
    return "whisper-cpp", "/opt/homebrew/bin/whisper-cli"
  elseif hs.fs.attributes("/opt/homebrew/bin/whisper-cpp") then
    log.i("Detected whisper-cpp (fast C++ implementation)")
    return "whisper-cpp", "/opt/homebrew/bin/whisper-cpp"
  elseif hs.fs.attributes("/usr/local/bin/whisper-cpp") then
    log.i("Detected whisper-cpp at /usr/local/bin")
    return "whisper-cpp", "/usr/local/bin/whisper-cpp"
  elseif hs.fs.attributes(HOME .. "/.local/bin/whisper") then
    log.i("Detected openai-whisper (Python implementation - slower)")
    return "openai-whisper", HOME .. "/.local/bin/whisper"
  else
    log.e("No whisper implementation found!")
    return nil, nil
  end
end

local WHISPER_IMPL, WHISPER = detectWhisper()
if not WHISPER then
  hs.alert.show("No whisper implementation found! Install whisper-cpp or openai-whisper")
end

-- Wave meter mode: 'inline' (default; parse ffmpeg stderr), 'monitor' (second ffmpeg), or 'off'
local WAVE_METER_MODE = cfg.WAVE_METER_MODE or "inline"
-- Sounds (start/finish/error). Default off.
local SOUND_ENABLED = (cfg.SOUND_ENABLED == true)

-- Logging configuration (defaults; can be overridden via ptt_config)
local LOG_DIR = (cfg.LOG_DIR and tostring(cfg.LOG_DIR)) or (NOTES_DIR .. "/tx_logs")
local LOG_ENABLED = (cfg.LOG_ENABLED ~= false)

-- Model configuration from ptt_config (with fallback)
local MODEL = cfg.WHISPER_MODEL or "base.en"         -- configurable model (default: base.en for compatibility)
local MODEL_BY_DURATION = cfg.MODEL_BY_DURATION or {}
local MODEL_SHORT = MODEL_BY_DURATION.MODEL_SHORT or MODEL
local MODEL_LONG = MODEL_BY_DURATION.MODEL_LONG or MODEL
local SHORT_SWITCH_SEC = tonumber(MODEL_BY_DURATION.SHORT_SEC) or 12.0
local USE_DYNAMIC_MODEL = (MODEL_BY_DURATION.ENABLED == true)

local LANG = "en"
local HOLD_THRESHOLD_MS = 150                       -- ignore ultra-short taps
local ARM_DELAY_MS = tonumber(cfg.ARM_DELAY_MS) or 700 -- fallback arming delay before "speak now" cue
local AUDIO_DEVICE_INDEX = (type(cfg.AUDIO_DEVICE_INDEX) == "number" and cfg.AUDIO_DEVICE_INDEX) or 1 -- avfoundation audio index (":1" for MacBook Pro Microphone)
local BUILTIN_SCREEN_PATTERN = "Built%-in"          -- choose the MacBook's built-in display by default

-- Transcript reflow options
local REFLOW_MODE = "gap"                           -- "gap" (use segment time gaps) or "singleline" (collapse single newlines)
local GAP_NEWLINE_SEC = cfg.GAP_NEWLINE_SEC or 1.75 -- newline if sentence end or gap >= this
local GAP_DOUBLE_NEWLINE_SEC = cfg.GAP_DOUBLE_NEWLINE_SEC or 2.50 -- paragraph break

-- Post-processing toggles
local DISFLUENCY_BEGIN_STRIP = (cfg.DISFLUENCY_BEGIN_STRIP ~= false)
local BEGIN_DISFLUENCIES = cfg.BEGIN_DISFLUENCIES or { "so", "um", "uh", "like", "you know", "okay", "yeah", "well" }
local AUTO_CAPITALIZE_SENTENCES = (cfg.AUTO_CAPITALIZE_SENTENCES ~= false)
local DEDUPE_IMMEDIATE_REPEATS = (cfg.DEDUPE_IMMEDIATE_REPEATS ~= false)
local DROP_LOWCONF_SEGMENTS = (cfg.DROP_LOWCONF_SEGMENTS ~= false)
local LOWCONF_NO_SPEECH_PROB = tonumber(cfg.LOWCONF_NO_SPEECH_PROB) or 0.5
local LOWCONF_AVG_LOGPROB = tonumber(cfg.LOWCONF_AVG_LOGPROB) or -1.0
-- Load external dictionary plugin (e.g., from VoxCompose or user config)
local function loadExternalDictionary()
  -- Try multiple possible sources in order of preference
  local sources = {
    -- User's personal dictionary
    HOME .. "/.config/ptt-dictation/corrections.lua",
    -- VoxCompose learned corrections (if available)
    HOME .. "/.config/voxcompose/corrections.lua",
    -- System-wide shared corrections
    "/usr/local/share/ptt-dictation/corrections.lua"
  }
  
  for _, path in ipairs(sources) do
    if hs.fs.attributes(path) then
      local ok, dict = pcall(dofile, path)
      if ok and type(dict) == "table" then
        log.i("Loaded dictionary from: " .. path)
        return dict
      end
    end
  end
  
  -- If no external dictionary found, return empty table
  return {}
end

local DICTIONARY_REPLACE = cfg.DICTIONARY_REPLACE or loadExternalDictionary()
local PASTE_TRAILING_NEWLINE = (cfg.PASTE_TRAILING_NEWLINE == true)
local ENSURE_TRAILING_PUNCT = (cfg.ENSURE_TRAILING_PUNCT == true)

-- Accuracy/perf tuning
local BEAM_SIZE = 3                                  -- beam search width (speed/accuracy balance)
local BEAM_SIZE_LONG = 3                             -- same for long audio
local WHISPER_DEVICE = "cpu"                        -- set to "mps" on Apple Silicon if available (auto-detected)
local VENV_PY = HOME .. "/.local/pipx/venvs/openai-whisper/bin/python"  -- python in pipx venv

-- Try to auto-detect Apple Silicon + MPS support in the pipx whisper env
local function detectMPS()
  -- Quick arch check
  local arch = hs.execute([[uname -m]]) or ""
  arch = arch:gsub("%s+", "")
  if arch ~= "arm64" then return false end
  -- Ask pipx whisper python if MPS is available
  local cmd = string.format([["%s" - <<'PY'
try:
    import torch
    print('1' if getattr(torch.backends, 'mps', None) and torch.backends.mps.is_available() else '0')
except Exception:
    print('0')
PY
]], VENV_PY)
  local out = hs.execute(cmd) or "0"
  out = out:gsub("%s+", "")
  return out == "1"
end

if detectMPS() then
  WHISPER_DEVICE = "mps"
end
local LONG_AUDIO_SEC = 1e9                           -- not used now; switching on short instead
local PREPROCESS_MIN_SEC = 12.0                      -- preprocess only if reasonably long
local TIMEOUT_MS = tonumber(cfg.TIMEOUT_MS) or 120000 -- 2 minutes transcription timeout

-- State
local keyTap
local flagTap
local fnHeld = false
local recording = false
local ffTask = nil
local whisperTask = nil
local whisperTimeoutTimer = nil
local indicator = nil
local blinkTimer = nil
local startMs = 0
local heldMs = 0
local wavPath = nil
local txtPath = nil
local sessionDir = nil

-- Session mode: "hold" (default) or "toggle" (default Shift+Hyper+Space)
local sessionKind = "hold"
local ignoreHoldThreshold = false
local isShiftToggle = false  -- Track if Shift+F13 was used

-- Double-tap configuration (toggle on double-tap)
local DOUBLE_TAP_ENABLED = true
local DOUBLE_TAP_WINDOW_MS = 300

-- F13 press/hold state for distinguishing hold vs tap/double-tap
local f13DownAt = nil
local holdStartTimer = nil
local lastTapMs = nil

-- Live level indicator state
local levelIndicator = nil
local levelTimer = nil
local levelTask = nil
local levelVal = 0.0    -- instantaneous [0..1]
local levelEma = 0.0    -- smoothed [0..1]
local levelT = 0.0      -- time for fallback animation
local levelUseFallback = false
local recordPeak = 0.0  -- max level seen during recording

-- Arming state (to avoid cutting off initial words): dot brightens when ready, optional beep
local recordArmed = false
local armTimer = nil

-- Debug buffers
local ffStdoutBuf, ffStderrBuf = {}, {}
local whStdoutBuf, whStderrBuf = {}, {}

-- Reflow metrics for logging
local reflowStats = { total_segments = 0, dropped_segments = 0 }

-- Test fixture export state
local testFixtureNextCategory = nil

-- Utils
local function nowMs()
  return hs.timer.secondsSinceEpoch() * 1000
end

local function ensureDir(path)
  local ok = hs.fs.mkdir(path)
  if not ok then -- already exists
  end
end

local function playSound(name)
  local s = hs.sound.getByName(name)
  if s then pcall(function() s:play() end) end
end

local function truncateMiddle(s, maxLen)
  if not s then return "" end
  maxLen = maxLen or 2000
  if #s <= maxLen then return s end
  local head = math.floor(maxLen/2)
  local tail = maxLen - head
  return s:sub(1, head) .. "\n...[truncated]...\n" .. s:sub(-tail)
end

local function isoNow()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

-- [DEPRECATED] Text post-processing now handled by Java processor
-- Keeping minimal functions for backward compatibility

local function ensureTrailingPunct(s)
  if not ENSURE_TRAILING_PUNCT then return s end
  if s:match("[%.%!%?]%s*$") then return s end
  return s .. "."
end

local function addTrailingNewline(s)
  if not PASTE_TRAILING_NEWLINE then return s end
  if s:sub(-1) == "\n" then return s end
  return s .. "\n"
end

-- Apply dictionary-based text replacements
local function applyDictionaryReplacements(text)
  if not text or text == "" then return text end
  if not DICTIONARY_REPLACE or type(DICTIONARY_REPLACE) ~= "table" then return text end
  
  local modified = text
  for pattern, replacement in pairs(DICTIONARY_REPLACE) do
    -- Use word boundaries for more accurate replacements
    -- Escape special regex characters in the pattern
    local escaped_pattern = pattern:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    -- Apply case-insensitive replacement with word boundaries
    modified = modified:gsub("(%W)" .. escaped_pattern .. "(%W)", "%1" .. replacement .. "%2")
    modified = modified:gsub("^" .. escaped_pattern .. "(%W)", replacement .. "%1")
    modified = modified:gsub("(%W)" .. escaped_pattern .. "$", "%1" .. replacement)
    modified = modified:gsub("^" .. escaped_pattern .. "$", replacement)
  end
  
  if modified ~= text then
    log.d("Dictionary replacements applied")
  end
  return modified
end

-- Apply Java post-processor if available
local function applyJavaPostProcessor(text)
  if not text or text == "" then return text end
  
  -- Try to find the Java processor JAR in multiple locations
  local function findPostProcessor()
    -- 1. Check config for explicit path
    if cfg.POST_PROCESSOR_JAR and hs.fs.attributes(cfg.POST_PROCESSOR_JAR) then
      return cfg.POST_PROCESSOR_JAR
    end
    
    -- 2. Check relative to Hammerspoon config
    local hsConfigDir = hs.configdir
    local relativeToConfig = hsConfigDir .. "/../whisper-post-processor/dist/whisper-post.jar"
    if hs.fs.attributes(relativeToConfig) then
      return relativeToConfig
    end
    
    -- 3. Check in ~/.local/bin (standard user binary location)
    local userBin = HOME .. "/.local/bin/whisper-post.jar"
    if hs.fs.attributes(userBin) then
      return userBin
    end
    
    -- 4. Check if installed via homebrew or in PATH
    local inPath = hs.execute("which whisper-post 2>/dev/null")
    if inPath and #inPath > 0 then
      return inPath:gsub("%s+$", "") -- trim whitespace
    end
    
    -- 5. Check /usr/local/bin
    local usrLocal = "/usr/local/bin/whisper-post.jar"
    if hs.fs.attributes(usrLocal) then
      return usrLocal
    end
    
    -- 6. Check /opt/homebrew/bin (Apple Silicon homebrew location)
    local optHomebrew = "/opt/homebrew/bin/whisper-post.jar"
    if hs.fs.attributes(optHomebrew) then
      return optHomebrew
    end
    
    return nil
  end
  
  local jarPath = findPostProcessor()
  
  -- Check if JAR/executable was found
  if not jarPath then
    -- Only log once to avoid spam
    if not _postProcessorWarned then
      log.d("Java post-processor not found. Install it or set POST_PROCESSOR_JAR in config")
      _postProcessorWarned = true
    end
    return text
  end
  
  -- Create temp file for input (safer than piping for large text)
  local tmpInput = os.tmpname()
  local f = io.open(tmpInput, "w")
  if not f then return text end
  f:write(text)
  f:close()
  
  -- Run processor (handle both JAR and executable script)
  local cmd
  if jarPath:match("%.jar$") then
    cmd = string.format("java -jar %q -f %q 2>/dev/null", jarPath, tmpInput)
  else
    -- Assume it's an executable script/binary
    cmd = string.format("%q -f %q 2>/dev/null", jarPath, tmpInput)
  end
  local output = hs.execute(cmd)
  
  -- Clean up temp file
  os.remove(tmpInput)
  
  if output and #output > 0 then
    -- Remove trailing newline if added by processor
    output = output:gsub("\n+$", "")
    log.d("Java post-processor applied successfully")
    return output
  else
    log.d("Java post-processor failed, returning original text")
    return text
  end
end
local function ordinal(n)
  n = tonumber(n) or 0
  local v = n % 100
  if v >= 11 and v <= 13 then return tostring(n) .. "th" end
  local last = n % 10
  if last == 1 then return tostring(n) .. "st"
  elseif last == 2 then return tostring(n) .. "nd"
  elseif last == 3 then return tostring(n) .. "rd"
  else return tostring(n) .. "th" end
end

local function humanTimestampName()
  local t = os.date("*t") -- local time
  local months = { "Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec" }
  local mon = months[t.month] or tostring(t.month)
  local hour12 = t.hour % 12
  if hour12 == 0 then hour12 = 12 end
  local ampm = (t.hour < 12) and "AM" or "PM"
  -- Format: YYYY-Mon-DD_HH.MM.SS_AM
  return string.format("%04d-%s-%02d_%02d.%02d.%02d_%s", t.year, mon, t.day, hour12, t.min, t.sec, ampm)
end

local function appendJSONL(path, obj)
  local ok, encoded = pcall(function() return json.encode(obj) end)
  if not ok then return false end
  local f = io.open(path, "a")
  if not f then return false end
  f:write(encoded)
  f:write("\n")
  f:close()
  return true
end

-- Unified failure finalizer with user-friendly messages and logging
local function finalizeFailure(kind, msg, opts)
  opts = opts or {}
  if opts.deleteWav and wavPath and hs.fs.attributes(wavPath) then pcall(function() os.remove(wavPath) end) end
  updateIndicator("off")
  stopBlink()
  local payload = {
    wav = wavPath,
    session_kind = sessionKind,
    held_ms = heldMs,
    peak_level = recordPeak,
  }
  for k, v in pairs(opts.extra or {}) do payload[k] = v end
  logEvent(kind, payload)
  if msg and #msg > 0 then hs.alert.show(msg) end
end

local function logEvent(kind, data)
  if not LOG_ENABLED then return end
  -- Ensure log directory exists
  ensureDir(LOG_DIR)
  local daily = string.format("%s/tx-%s.jsonl", LOG_DIR, os.date("%Y-%m-%d"))
  local payload = {
    ts = isoNow(),
    kind = kind,
    app = "voxcore",
    model = MODEL,
    device = WHISPER_DEVICE,
    beam_size = BEAM_SIZE,
    lang = LANG,
    config = {
      reflow_mode = REFLOW_MODE,
      gap_newline_sec = GAP_NEWLINE_SEC,
      gap_double_newline_sec = GAP_DOUBLE_NEWLINE_SEC,
      preprocess_min_sec = PREPROCESS_MIN_SEC,
      timeout_ms = TIMEOUT_MS,
      disfluencies = cfg.DISFLUENCIES,
      initial_prompt_len = (cfg.INITIAL_PROMPT and #cfg.INITIAL_PROMPT or 0),
    }
  }
  if data then
    for k, v in pairs(data) do payload[k] = v end
  end
  appendJSONL(daily, payload)
end

-- File helpers
local function readAll(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local d = f:read("*a")
  f:close()
  return d
end

local function writeAll(path, content)
  local f = io.open(path, "w")
  if not f then return false end
  f:write(content or "")
  f:close()
  return true
end

local function basename(p)
  return p and p:match("([^/]+)$") or nil
end

local function categorizeDuration(sec)
  local tcfg = cfg.TEST_FIXTURE_EXPORT or {}
  local micro = tonumber(tcfg.MICROTAP_MAX_SEC) or 1.0
  local smax = tonumber(tcfg.SHORT_MAX_SEC) or 10
  local mmax = tonumber(tcfg.MEDIUM_MAX_SEC) or 30
  if sec <= micro then return "micro" end
  if sec <= smax then return "short" end
  if sec <= mmax then return "medium" end
  return "long"
end

local function exportTestFixture(category, audioPath, jsonPath, txtPath)
  local tcfg = cfg.TEST_FIXTURE_EXPORT or {}
  local rr = repoRoot() or ""
  local root = (type(tcfg.DEST_DIR) == "string" and #tcfg.DEST_DIR>0) and tcfg.DEST_DIR or (rr .. "/tests/fixtures/samples_current")
  if not rr or rr == "" then return end
  ensureDir(root)
  -- Batch subfolder based on current batch id (or generate lightweight one if missing)
  local bid = hs.settings.get("ptt_fixture_batch_id")
  if not bid or bid == "" then
    local cmd = string.format([[git -C %q rev-parse --short HEAD 2>/dev/null]], rr)
    local out = hs.execute(cmd) or ""; out = out:gsub("%s+$", "")
    bid = os.date("%Y%m%d-%H%M") .. ((out ~= "" and ("_"..out)) or "")
    hs.settings.set("ptt_fixture_batch_id", bid)
  end
  local batchDir = string.format("%s/batches/%s", root, bid)
  local dest = string.format("%s/%s", batchDir, category or "uncat")
  ensureDir(batchDir)
  ensureDir(dest)

  -- Write batch metadata once
  local metaPath = batchDir .. "/metadata.json"
  if not hs.fs.attributes(metaPath) then
    local git = { }
    local shortSha = hs.execute(string.format([[git -C %q rev-parse --short HEAD 2>/dev/null]], rr)) or ""
    local fullSha = hs.execute(string.format([[git -C %q rev-parse HEAD 2>/dev/null]], rr)) or ""
    local branch = hs.execute(string.format([[git -C %q rev-parse --abbrev-ref HEAD 2>/dev/null]], rr)) or ""
    local function trim(s) return (s or ""):gsub("%s+$", "") end
    git.short = trim(shortSha)
    git.full = trim(fullSha)
    git.branch = trim(branch)

    local meta = {
      batch_id = bid,
      ts = isoNow(),
      repo_root = rr,
      git = git,
      config = {
        gap_newline_sec = GAP_NEWLINE_SEC,
        gap_double_newline_sec = GAP_DOUBLE_NEWLINE_SEC,
        preprocess_min_sec = PREPROCESS_MIN_SEC,
        timeout_ms = TIMEOUT_MS,
        disfluencies = cfg.DISFLUENCIES,
        initial_prompt_len = (cfg.INITIAL_PROMPT and #cfg.INITIAL_PROMPT or 0),
      }
    }
    writeAll(metaPath, json.encode(meta))
  end

  local function ln_s(src)
    if src and hs.fs.attributes(src) then
      local dst = string.format("%s/%s", dest, basename(src))
      hs.execute(string.format([[ln -sf %q %q]], src, dst))
    end
  end
  ln_s(audioPath)
  if (tcfg.LINK_JSON ~= false) then ln_s(jsonPath) end
  if (tcfg.LINK_TXT ~= false) then ln_s(txtPath) end

  -- Compute complexity score and write sidecar fixture.json
  local chars = 0
  local tricky = 0
  local txt = (txtPath and readAll(txtPath)) or ""
  if txt and #txt > 0 then
    chars = #txt
    local tokens = tcfg.TRICKY_TOKENS or {}
    local ltxt = string.lower(txt)
    for _, tok in ipairs(tokens) do
      local patt = tostring(tok):gsub("[^%w]+"," ")
      patt = patt:lower()
      if patt ~= "" then
        local _, n = ltxt:gsub(patt, "")
        tricky = tricky + (n or 0)
      end
    end
  end
  local w = tcfg.SCORE_WEIGHTS or { CHARS = 1.0, TRICKY = 6.0 }
  local score = (w.CHARS or 1.0) * chars + (w.TRICKY or 6.0) * tricky
  local fix = {
    category = category,
    duration_sec = (jsonPath and (function()
      local j = readAll(jsonPath)
      local ok, o = pcall(function() return json.decode(j) end)
      if ok and o and o.segments and #o.segments>0 then
        local last = o.segments[#o.segments]
        return tonumber(last["end"] or last.e or 0)
      end
      return nil
    end)()) or nil,
    transcript_chars = chars,
    tricky_matches = tricky,
    score = score,
    batch_id = hs.settings.get("ptt_fixture_batch_id"),
  }
  local side = dest .. "/fixture.json"
  writeAll(side, json.encode(fix))

  logEvent("test_fixture_export", { category = category, dest_dir = dest, audio = audioPath, json = jsonPath, txt = txtPath, score = score, tricky = tricky, transcript_chars = chars })
end

local function rstrip(s)
  return (s or ""):gsub("%s+$", "")
end

-- Reflow: join Whisper segments into readable text.
-- Newline only at sentence end or sufficiently large gaps; otherwise prefer spaces.
local function reflowFromSegments(segments)
  -- Optionally filter low-confidence/no-speech segments first
  local totalCount = #(segments or {})
  local filtered = {}
  for _, seg in ipairs(segments or {}) do
    local keep = true
    if DROP_LOWCONF_SEGMENTS then
      local nsp = tonumber(seg.no_speech_prob)
      local alp = tonumber(seg.avg_logprob)
      if (nsp and nsp >= LOWCONF_NO_SPEECH_PROB) or (alp and alp <= LOWCONF_AVG_LOGPROB) then
        keep = false
      end
    end
    if keep then table.insert(filtered, seg) end
  end
  segments = filtered
  reflowStats.total_segments = totalCount
  reflowStats.dropped_segments = math.max(0, totalCount - #filtered)
  if not segments or #segments == 0 then return "" end
  local out = {}
  local lastEnd = nil
  for i, seg in ipairs(segments) do
    local txt = tostring(seg.text or "")
    txt = txt:gsub("^%s+", "") -- trim leading spaces that segments often carry
    if lastEnd ~= nil and seg.start then
      local gap = (seg.start or 0) - (lastEnd or 0)
      local prev = (#out > 0) and out[#out] or ""
      local lastChar = prev:sub(-1)
      local sentenceEnd = lastChar and lastChar:match("[%.%!%?]")
      if gap >= GAP_DOUBLE_NEWLINE_SEC then
        table.insert(out, "\n\n")
      elseif sentenceEnd or gap >= GAP_NEWLINE_SEC then
        table.insert(out, "\n")
      else
        if #out > 0 and lastChar and not lastChar:match("%s") and not txt:match("^[,%.!%?;:]" ) then
          table.insert(out, " ")
        end
      end
    end
    table.insert(out, txt)
    lastEnd = seg["end"] or seg.e or seg.t1 or seg.offset_to or seg.start -- best-effort
  end
  local joined = table.concat(out)
  -- Normalize spaces around punctuation
  joined = joined:gsub("%s+([,%.!%?;:])", "%1")
  joined = joined:gsub("%s+\n", "\n")
  joined = joined:gsub("\n%s+", "\n")
  -- Collapse 3+ newlines into 2
  joined = joined:gsub("\n\n+", "\n\n")

  -- Java processor handles structural text cleaning
  joined = applyJavaPostProcessor(joined)
  -- Apply dictionary replacements after Java processing
  joined = applyDictionaryReplacements(joined)
  return rstrip(joined)
end

-- Simple fallback reflow for plain .txt: collapse single newlines to spaces, keep blank lines
local function reflowPlainText(txt)
  if not txt then return "" end
  txt = txt:gsub("\r\n", "\n")
  -- Replace single newlines that are not part of a blank line with a space
  -- Strategy: temporarily mark double newlines, then collapse singles, then restore
  txt = txt:gsub("\n\n", "<P>\n")
  txt = txt:gsub("\n", " ")
  txt = txt:gsub("<P>\n", "\n\n")
  -- Normalize spacing
  txt = txt:gsub("%s+([,%.!%?;:])", "%1")
  -- Collapse runs of spaces/tabs
  txt = txt:gsub("[ \t]+", " ")
  -- Remove trailing spaces before newlines
  txt = txt:gsub("[ \t]+\n", "\n")
  -- Apply Java processor for consistency
  txt = applyJavaPostProcessor(txt)
  -- Apply dictionary replacements after Java processing
  txt = applyDictionaryReplacements(txt)
  return rstrip(txt)
end

-- Minimal on-screen indicator (small dot at top center)
-- States: "recording" (red), "transcribing" (orange)
local function builtinScreen()
  local scrs = hs.screen.allScreens()
  for _, s in ipairs(scrs) do
    local nm = s:name() or ""
    if nm:match(BUILTIN_SCREEN_PATTERN) then return s end
  end
  -- Fallbacks: primary, then main
  return hs.screen.primaryScreen() or hs.screen.mainScreen()
end

local function stopBlink()
  if blinkTimer then
    blinkTimer:stop()
    blinkTimer = nil
  end
end

local function updateIndicator(state)
  local scr = builtinScreen():frame()
  local size = 16
  local x = math.floor(scr.x + scr.w / 2 - size / 2)
  local y = scr.y + 10
  -- Recreate on each update to ensure it appears on the chosen screen
  if indicator then pcall(function() indicator:delete() end) end
  indicator = nil
  stopBlink()
  if state == "off" then return end
  indicator = hs.canvas.new({x = x, y = y, w = size, h = size})
  local lvl = (hs.canvas.windowLevels and hs.canvas.windowLevels.overlay) or ((hs.drawing and hs.drawing.windowLevels and hs.drawing.windowLevels.modalPanel) or nil)
  if lvl then pcall(function() indicator:level(lvl) end) end
  local baseColor
  local alpha
  if state == "transcribing" then
    baseColor = { red = 1, green = 0.6, blue = 0 }
    alpha = 0.85
  elseif state == "recording_dim" then
    baseColor = { red = 1, green = 0, blue = 0 }
    alpha = 0.55
  else
    baseColor = { red = 1, green = 0, blue = 0 }
    alpha = 0.90
  end
  indicator:appendElements({
    id = "dot",
    type = "circle",
    action = "fill",
    fillColor = { red = baseColor.red, green = baseColor.green, blue = baseColor.blue, alpha = alpha },
    strokeColor = { red = 1, green = 1, blue = 1, alpha = 0.9 },
    strokeWidth = 1.5,
    radius = size / 2
  })
  indicator:show()

  if state == "transcribing" then
    -- Smooth fade in/out blink
    local dir = -1 -- start fading out
    blinkTimer = hs.timer.doEvery(0.06, function()
      if not indicator then return end
      local c = indicator["dot"].fillColor
      local a = c.alpha or 0.85
      a = a + dir * 0.06
      if a <= 0.35 then a = 0.35; dir = 1 end
      if a >= 0.95 then a = 0.95; dir = -1 end
      indicator["dot"].fillColor = { red = baseColor.red, green = baseColor.green, blue = baseColor.blue, alpha = a }
    end)
  end
end

-- Live audio/wave indicator helpers
local function mapDbToLevel(db)
  if not db then return 0.0 end
  if db > 0 then db = 0 end
  if db < -60 then db = -60 end
  return (db + 60) / 60 -- -60..0 -> 0..1
end

local function showLevelIndicator()
  -- Create a bar-wave indicator near top-center
  if levelIndicator then pcall(function() levelIndicator:delete() end) end
  local scr = builtinScreen():frame()
  local W, H = math.floor(scr.w * 0.28), 44
  local x = math.floor(scr.x + scr.w / 2 - W / 2)
  local y = scr.y + 28
  levelIndicator = hs.canvas.new({x=x, y=y, w=W, h=H}):level(hs.canvas.windowLevels.overlay)
  levelIndicator:appendElements({
    id="bg", type="rectangle", action="fill", roundedRectRadii = {xRadius=8, yRadius=8},
    fillColor={red=0,green=0,blue=0,alpha=0.25}, strokeColor={red=1,green=1,blue=1,alpha=0.15}, strokeWidth=1
  })
  local bars = 28
  local pad = 2
  local bw = math.floor((W - (bars+1)*pad) / bars)
  for i=1,bars do
    local bx = pad + (i-1)*(bw+pad)
    levelIndicator:appendElements({
      id = "bar"..i, type="rectangle", action="fill",
      frame = { x=bx, y=H/2, w=bw, h=2 },
      fillColor={red=1,green=0,blue=0,alpha=0.85},
      strokeColor={red=1,green=1,blue=1,alpha=0.0}, strokeWidth=0
    })
  end
  levelIndicator:show()

  if levelTimer then levelTimer:stop(); levelTimer=nil end
  levelTimer = hs.timer.doEvery(1/60, function()
    -- Smooth to EMA
    local alpha = 0.25
    levelEma = levelEma + alpha * (levelVal - levelEma)
    levelT = levelT + 0.10
    local amp = levelUseFallback and (0.35 + 0.25*math.sin(levelT)) or levelEma
    -- Update bars as a symmetrical wave
    if levelIndicator then
      local H = levelIndicator:frame().h
      local bars = 28
      for i=1,bars do
        local phase = (i - (bars/2)) / (bars/2)
        local localAmp = amp * (0.25 + 0.75*(1 - math.abs(phase)))
        local h = math.max(2, math.floor(localAmp * (H - 8)))
        local y = math.floor(H/2 - h/2)
        local id = "bar"..i
        levelIndicator[id].frame = { x=levelIndicator[id].frame.x, y=y, w=levelIndicator[id].frame.w, h=h }
      end
    end
  end)
end

local function hideLevelIndicator()
  if levelTimer then levelTimer:stop(); levelTimer=nil end
  if levelIndicator then pcall(function() levelIndicator:delete() end); levelIndicator=nil end
  levelVal, levelEma, levelT = 0,0,0
end

local function startLevelMonitor()
  levelUseFallback = false
  levelVal, levelEma = 0,0
  -- Attempt an ffmpeg astats-based monitor (may fail if device is exclusive)
  local deviceSpec = ":" .. tostring(AUDIO_DEVICE_INDEX)
  local args = { "-hide_banner", "-loglevel", "error", "-f", "avfoundation", "-thread_queue_size", "1024", "-i", deviceSpec, "-af", "astats=metadata=1:reset=0.2", "-f", "null", "-" }
  if isTestMode() then
    -- In test mode, just fallback animate
    levelUseFallback = true
    return
  end
  local errBuf = {}
  levelTask = hs.task.new(FFMPEG, function(code, so, se)
    if tonumber(code) ~= 0 then
      -- Likely device busy; use fallback animation
      levelUseFallback = true
    end
    levelTask = nil
  end, function(task, so, se)
    if se and #se > 0 then
      -- Parse RMS_level from stderr lines like: "RMS_level: -23.1 dB"
      local line = se
      local db = line:match("RMS_level:%s*([%-%d%.]+)%s*dB")
      if db then
        local val = mapDbToLevel(tonumber(db))
        if val and val==val then
          levelVal = val
          if val > recordPeak then recordPeak = val end
        end
      end
      table.insert(errBuf, se)
    end
    return true
  end, args)
  -- If PATH issues occur, still okay; we handle on exit
  pcall(function() levelTask:start() end)
end

local function stopLevelMonitor()
  levelUseFallback = false
  if levelTask then
    pcall(function() levelTask:sendSignal(2) end)
    pcall(function() levelTask:terminate() end)
    levelTask = nil
  end
end

-- Detect best device for Whisper (mps on Apple Silicon if available)
local function detectWhisperDevice()
  -- Temporarily force CPU for stability; PyTorch MPS on 3.13 can be flaky with Whisper
  WHISPER_DEVICE = "cpu"
  log.i("Whisper device=cpu (MPS disabled)")
end

-- Preprocess audio (normalize + light compression); calls cb(ok, outPath)
local function preprocessAudio(inPath, cb)
  local outPath = inPath:gsub("%.wav$", ".norm.wav")
  local filters = "loudnorm=I=-16:TP=-1.5:LRA=11,acompressor=threshold=-18dB:ratio=2:attack=5:release=50"
  if isTestMode() then
    log.d("[TEST] Would preprocess: ffmpeg -y -i " .. inPath .. " -af '" .. filters .. "' -ac 1 -ar 16000 -sample_fmt s16 -vn " .. outPath)
    cb(true, inPath)
    return
  end
  local args = {"-y", "-i", inPath, "-af", filters, "-ac", "1", "-ar", "16000", "-sample_fmt", "s16", "-vn", outPath}
  local t = hs.task.new(FFMPEG, function(code, so, se)
    if tonumber(code) == 0 and hs.fs.attributes(outPath) then
      cb(true, outPath)
    else
      log.w("Preprocess failed; using raw audio")
      cb(false, inPath)
    end
  end, function(task, so, se) return true end, args)
  t:start()
end

local function listDevices()
  if not hs.fs.attributes(FFMPEG) then
    log.e("ffmpeg not found at " .. tostring(FFMPEG))
    return
  end
  local args = {"-f", "avfoundation", "-list_devices", "true", "-i", ""}
  local errBuf = {}
  local t = hs.task.new(FFMPEG, function(code, so, se)
    -- avfoundation prints devices to stderr; summarize succinctly
    local txt = table.concat(errBuf)
    local header = txt:match("AVFoundation video devices:.-\n(.-)AVFoundation audio devices:") or ""
    local audio = txt:match("AVFoundation audio devices:%s*(.-)$") or ""
    log.i("[devices] audio:\n" .. (audio ~= "" and audio or txt))
  end, function(task, so, se)
    if se and #se > 0 then table.insert(errBuf, se) end
    return true
  end, args)
  t:start()
end

local function showInfo()
  local info = {
    "push_to_talk diagnostics:",
    "  testMode=" .. tostring(isTestMode()),
    "  FFMPEG=" .. tostring(FFMPEG) .. " exists=" .. tostring(hs.fs.attributes(FFMPEG) ~= nil),
    "  WHISPER=" .. tostring(WHISPER) .. " exists=" .. tostring(hs.fs.attributes(WHISPER) ~= nil),
    "  NOTES_DIR=" .. NOTES_DIR,
    "  AUDIO_DEVICE=" .. tostring(":" .. AUDIO_DEVICE_INDEX),
    "  MODEL=" .. MODEL .. " LANG=" .. LANG,
    "  ptt_config_loaded=" .. tostring(cfg_loaded),
    "  ptt_config_path=" .. tostring(cfg_path_used or "n/a"),
  }
  log.i(table.concat(info, "\n"))
  listDevices()
  hs.alert.show("push_to_talk info logged")
end

-- Comprehensive diagnostic function
local function runDiagnostics()
  local results = {}
  
  -- Check ffmpeg
  local ffmpegOk = hs.fs.attributes(FFMPEG) ~= nil
  table.insert(results, (ffmpegOk and "✅" or "❌") .. " FFmpeg: " .. (ffmpegOk and "Found" or "MISSING at " .. FFMPEG))
  
  -- Check whisper
  local whisperOk = hs.fs.attributes(WHISPER) ~= nil
  table.insert(results, (whisperOk and "✅" or "❌") .. " Whisper: " .. (whisperOk and "Found" or "MISSING at " .. WHISPER))
  
  -- List audio devices
  table.insert(results, "")
  table.insert(results, "🎤 Audio Devices:")
  
  if ffmpegOk then
    local task = hs.task.new(FFMPEG, nil, { "-hide_banner", "-f", "avfoundation", "-list_devices", "true", "-i", "" })
    task:start()
    task:waitUntilExit()
    local stderr = task:standardError() or ""
    
    local audioDevices = {}
    local inAudioSection = false
    for line in stderr:gmatch("[^\r\n]+") do
      if line:match("AVFoundation audio devices:") then
        inAudioSection = true
      elseif inAudioSection then
        local index, name = line:match("%[AVFoundation[^%]]*%]%s*%[(%d+)%]%s*(.+)")
        if index and name then
          local idx = tonumber(index)
          audioDevices[idx] = name
          local marker = (idx == AUDIO_DEVICE_INDEX) and " ← CURRENT" or ""
          table.insert(results, string.format("  [%d] %s%s", idx, name, marker))
        end
      end
    end
    
    if not audioDevices[AUDIO_DEVICE_INDEX] then
      table.insert(results, "")
      table.insert(results, "⚠️ WARNING: No device at index " .. AUDIO_DEVICE_INDEX)
      table.insert(results, "Update AUDIO_DEVICE_INDEX in ptt_config.lua")
    end
  else
    table.insert(results, "  Cannot list - ffmpeg missing")
  end
  
  table.insert(results, "")
  table.insert(results, "Press Cmd+Alt+Ctrl+I for full info")
  
  -- Show results
  local msg = table.concat(results, "\n")
  hs.alert.show(msg, {textSize = 12, textFont = "Menlo"}, 5)
  
  -- Also log to console
  log.i("Diagnostics:\n" .. msg)
end

-- Resolve refiner argv based on config or auto-detection
local function _which(bin)
  local out = hs.execute(string.format([[bash -lc 'command -v %q 2>/dev/null']], bin)) or ""
  out = (out or ""):gsub("%s+$", "")
  if out == "" then return nil end
  return out
end
local function resolveRefinerArgv()
  local refCfg = cfg.LLM_REFINER or {}
  local argv = {}
  local cmd = refCfg.CMD or {}
  if type(cmd) == "table" and #cmd > 0 then
    for _,p in ipairs(cmd) do table.insert(argv, p) end
  else
    -- Auto-detect voxcompose in PATH
    local v = _which("voxcompose")
    if v then table.insert(argv, v) end
  end
  for _,a in ipairs(refCfg.ARGS or {}) do table.insert(argv, a) end
  return argv
end

-- Run a self-test of the LLM refiner (no audio involved)
local function refineSelfTest()
  local refCfg = cfg.LLM_REFINER or {}
  if not refCfg.ENABLED then
    hs.alert.show("LLM refine disabled in ptt_config.lua")
    return
  end
  local argv = resolveRefinerArgv()
  if type(argv) ~= "table" or #argv == 0 then
    hs.alert.show("LLM refiner not found: install 'voxcompose' or set LLM_REFINER.CMD")
    return
  end
  log.i("Running refine self-test via VoxCompose…")
  local sample = [[Draft test note: demonstrate Markdown structure with a heading and bullet list.
- item one
- item two]]
  local outBuf, errBuf = {}, {}
  local t0 = nowMs()
  local t = hs.task.new(argv[1], function(rc, so, se)
    local ms = nowMs() - t0
    local out = table.concat(outBuf)
    local ok = (tonumber(rc) == 0 and out and out:gsub("%s+", "") ~= "")
    logEvent("refine_probe", {
      ok = ok,
      rc = rc,
      ms = ms,
      cmd = argv[1],
      out_chars = #(out or ""),
      sample = (out or ""):sub(1, 200)
    })
    hs.alert.show(ok and "LLM refine self-test OK" or "LLM refine self-test failed (see logs)")
  end, function(task, so, se)
    if so and #so>0 then table.insert(outBuf, so) end
    if se and #se>0 then table.insert(errBuf, se) end
    return true
  end, {table.unpack(argv, 2)})
  t:setInput(true)
  t:start()
  t:write(sample)
  if t.closeInput then t:closeInput() end
end


-- ffmpeg management
local function startRecording()
  if recording then return end
  
  ensureDir(NOTES_DIR)

  local baseName = humanTimestampName()
  sessionDir = string.format("%s/%s", NOTES_DIR, baseName)
  ensureDir(sessionDir)
  local base = string.format("%s/%s", sessionDir, baseName)
  wavPath = base .. ".wav"
  txtPath = base .. ".txt"

  local deviceSpec = ":" .. tostring(AUDIO_DEVICE_INDEX)

  -- Build ffmpeg args: audio-only, default input, 16k mono s16le WAV
  local loglevel = (isTestMode() and "info" or ((WAVE_METER_MODE == "inline") and "info" or "error"))
  local args = {
    "-hide_banner",
    "-loglevel", loglevel,
    "-nostats",
    "-y",
    "-f", "avfoundation",
    "-thread_queue_size", "1024",
    "-i", deviceSpec,
    "-ac", "1",
    "-ar", "16000",
    "-sample_fmt", "s16",
  }
  if WAVE_METER_MODE == "inline" then
    table.insert(args, "-af"); table.insert(args, "astats=metadata=1:reset=0.2")
  end
  table.insert(args, "-vn")
  table.insert(args, wavPath)

  if isTestMode() then
    local basePath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    local envPath = basePath .. ":" .. (os.getenv("PATH") or "")
    log.d("[TEST] Would start ffmpeg: " .. FFMPEG .. " " .. table.concat(args, " "))
    log.d("[TEST] PATH=" .. envPath)
    log.d("[TEST] Would write WAV to: " .. wavPath .. " (device " .. deviceSpec .. ")")
    return
  end

  ffStdoutBuf, ffStderrBuf = {}, {}

  -- Arming: start with dim indicator; brighten and optional beep once ready
  recordArmed = false
  updateIndicator("recording_dim")
  if armTimer then armTimer:stop(); armTimer=nil end
  armTimer = hs.timer.doAfter((ARM_DELAY_MS or 200)/1000, function()
    if not recordArmed then
      -- On fallback, brighten dot only (no beep), to avoid misleading cue
      updateIndicator("recording")
      log.d("Armed via fallback timer (no beep)")
    end
  end)

local function onFFExit(code, stdout, stderr)
  if armTimer then armTimer:stop(); armTimer=nil end
    if isTestMode() then
      log.d(string.format("[TEST] ffmpeg exit code=%s", tostring(code)))
    end
    
    -- Check if ffmpeg failed
    if tonumber(code) ~= 0 and tonumber(code) ~= 255 then  -- 255 is normal for interrupted
      local errMsg = table.concat(ffStderrBuf)
      log.e("FFmpeg exited with code " .. tostring(code) .. ": " .. errMsg)
      
      -- Check for common errors
      if errMsg:match("Device not found") or errMsg:match("Input/output error") then
        hs.alert.show(string.format("🎤 Device %d not available\n\nPress Cmd+Alt+Ctrl+D to see devices", AUDIO_DEVICE_INDEX), {textSize = 14}, 4)
      elseif errMsg:match("Permission denied") then
        hs.alert.show("🎤 Microphone permission denied\n\nCheck System Settings > Privacy", {textSize = 14}, 4)
      else
        hs.alert.show("🎤 Recording error\n\nCheck Console for details", {textSize = 14}, 3)
      end
      
      updateIndicator("off")
      recording = false
      return
    end
    
    -- Switch to transcribing indicator
    updateIndicator("transcribing")
    recording = false
    -- Timing probe: recording stop
    if startMs then
      logEvent("record_stop", { rec_ms = (nowMs() - startMs), held_ms = heldMs })
    end

    -- Track early-condition reasons without aborting output
    local fallbackReason = nil

    -- Ignore micro-taps unless in toggle mode
    if (not ignoreHoldThreshold) and heldMs < HOLD_THRESHOLD_MS then
      log.i("Hold below threshold; proceeding anyway (will insert fallback text)")
      fallbackReason = "too_short"
      -- continue to attempt transcription; fallback will be inserted if none
    end

    -- Validate WAV exists and non-trivial size
    local attr = wavPath and hs.fs.attributes(wavPath)
    if not attr or (attr.size or 0) < 8000 then -- ~0.5s of 16kHz mono s16
      log.e("Audio not captured; wav too small: size=" .. tostring(attr and attr.size))
      fallbackReason = fallbackReason or "no_audio"
      -- continue; transcription may fail → we'll insert a fallback message
    end

    -- Concise: report duration and size
    local bytes = attr.size or 0
    local dur = math.max(0, (bytes - 44) / 32000) -- 16kHz * 2 bytes * 1 ch
    log.i(string.format("REC done: %.2fs, %d KiB", dur, math.floor(bytes/1024)))

    -- "No voice" detection: for clips >= 1s with very low peak level
    if (dur >= 1.0) and (recordPeak < 0.08) then
      fallbackReason = fallbackReason or "no_voice"
      -- continue; transcription may still produce something; else fallback text
    end

    -- Decide model/beam and whether to preprocess based on duration
    local chosenModel = MODEL
    local chosenBeam = BEAM_SIZE
    local doPre = dur >= PREPROCESS_MIN_SEC
    
    -- Use dynamic model selection if enabled
    if USE_DYNAMIC_MODEL and dur and dur > 0 then
      if dur <= SHORT_SWITCH_SEC then
        chosenModel = MODEL_SHORT
        log.d(string.format("Using short model %s for %.1fs clip", chosenModel, dur))
      else
        chosenModel = MODEL_LONG
        log.d(string.format("Using long model %s for %.1fs clip", chosenModel, dur))
      end
    end

    -- Kick off transcription
    local function startTranscribe()
      if not WHISPER or not hs.fs.attributes(WHISPER) then
        finalizeFailure("missing_cli", "Whisper CLI not found. Install whisper-cpp (brew install whisper-cpp) or openai-whisper (pipx install openai-whisper)", { extra = { missing = WHISPER or "none detected" } })
        return
      end

local function runWhisper(audioPath)
        local wargs
        
        if WHISPER_IMPL == "whisper-cpp" then
          -- whisper-cpp args (C++ implementation, much faster)
          local modelName = chosenModel:gsub("%.en$", "")
          local modelPath = "/opt/homebrew/share/whisper-cpp/ggml-" .. modelName .. ".bin"
          
          wargs = {
            "-m", modelPath,
            "-l", "en",
            "-oj",  -- output JSON
            "-of", audioPath:gsub("%.wav$", ""),  -- output file base
            "--beam-size", tostring(chosenBeam),
            "-t", "4",  -- threads
            "-p", "1",  -- processors
          }
          
          if cfg and cfg.INITIAL_PROMPT and #cfg.INITIAL_PROMPT > 0 then
            table.insert(wargs, "--prompt")
            table.insert(wargs, cfg.INITIAL_PROMPT)
          end
          
          -- whisper-cpp expects the audio file as a positional argument, not with -f
          table.insert(wargs, audioPath)
        else
          -- openai-whisper args (Python implementation)
          local fp16Arg = (WHISPER_DEVICE == "mps") and "True" or "False"
          wargs = {
            audioPath,
            "--model", chosenModel,
            "--language", LANG,
            "--output_format", "json",
            "--output_dir", sessionDir,
            "--beam_size", tostring(chosenBeam),
            "--device", WHISPER_DEVICE,
            "--fp16", fp16Arg,
            "--verbose", "False",
            "--temperature", "0",
            "--condition_on_previous_text", "False",
          }
          if cfg and cfg.INITIAL_PROMPT and #cfg.INITIAL_PROMPT > 0 then
            table.insert(wargs, "--initial_prompt")
            table.insert(wargs, cfg.INITIAL_PROMPT)
          end
        end

        if isTestMode() then
          local basePath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
          local envPath = basePath .. ":" .. (os.getenv("PATH") or "")
          log.d("[TEST] Would run whisper: " .. WHISPER .. " " .. table.concat(wargs, " "))
          log.d("[TEST] PATH=" .. envPath)
          return
        end

        whStdoutBuf, whStderrBuf = {}, {}
        local txStart = nowMs()
        -- Timing probe: transcription start delta from key-down
        if f13DownAt then
          logEvent("tx_start", { delta_ms = (txStart - f13DownAt) })
        end
        local testNow = isTestMode()

        whisperTask = hs.task.new(WHISPER, function(wcode, wout, werr)
          if whisperTimeoutTimer then pcall(function() whisperTimeoutTimer:stop() end); whisperTimeoutTimer = nil end
          local wsOut = table.concat(whStdoutBuf)
          local wsErr = table.concat(whStderrBuf)
          local ms = nowMs() - txStart
          -- Concise normal log
          if tonumber(wcode) ~= 0 then
            local wsErrStr = (table.concat(whStderrBuf)):gsub("%s+$","")
            log.e(string.format("TX failed: code=%s, %.0fms, stderr=%s", tostring(wcode), ms, truncateMiddle(wsErrStr, 2000)))
            -- Log error event
            logEvent("error", {
              wav = wavPath,
              duration_sec = dur,
              wav_bytes = bytes,
              preprocess_used = doPre,
              audio_used = audioPath,
              tx_ms = ms,
              tx_code = wcode,
              stderr = truncateMiddle(wsErrStr, 1000),
            })
          else
            log.i(string.format("TX done: code=%s, %.0fms", tostring(wcode), ms))
          end
  -- Build reflowed transcript from JSON (preferred), else fallback to .txt
          local baseNoExt = audioPath:gsub("%.wav$", "")
          local jsonPath = baseNoExt .. ".json"
          local transcript = nil
          if hs.fs.attributes(jsonPath) then
            local jtxt = readAll(jsonPath)
            local ok, parsed = pcall(function() return json.decode(jtxt) end)
            if ok and parsed then
              -- Handle both whisper-cpp (transcription array) and openai-whisper (segments array) formats
              local segments = parsed.segments or parsed.transcription
              if segments then
                if REFLOW_MODE == "gap" then
                  transcript = reflowFromSegments(segments)
                end
              end
              -- Fallback to full text if available
              if (not transcript) or transcript == "" then
                if parsed.text then
                  transcript = tostring(parsed.text)
                elseif segments then
                  -- Build text from segments if no full text field
                  local parts = {}
                  for _, seg in ipairs(segments) do
                    if seg.text then table.insert(parts, seg.text) end
                  end
                  transcript = table.concat(parts, " "):gsub("%s+", " "):gsub("^%s+", "")
                end
              end
            end
          end
          if (not transcript or transcript == "") then
            -- Fallback to whisper .txt
            local cand = {
              baseNoExt .. ".txt",
              baseNoExt .. ".en.txt",
              baseNoExt .. ".english.txt",
            }
            for _, p in ipairs(cand) do
              if hs.fs.attributes(p) then
                local raw = readAll(p)
                if raw and #raw > 0 then
                  transcript = reflowPlainText(raw)
                  txtPath = p
                  break
                end
              end
            end
          end
          if not transcript or transcript:gsub("%s+", "") == "" then
            local reason = fallbackReason or "no_transcript"
            local fallbackText = ""
            if reason == "too_short" then
              fallbackText = "[No transcript: recording too short]"
            elseif reason == "no_audio" then
              fallbackText = "[No transcript: no audio captured]"
            elseif reason == "no_voice" then
              fallbackText = "[No transcript: no voice detected]"
            else
              fallbackText = "[No transcript available]"
            end
            -- Insert fallback text according to session routing
            finishWithText(fallbackText, { reason = reason })
            return
          end
          -- Write our reflowed transcript to the standard .txt path (use normalized base if used)
          local outTxt = baseNoExt .. ".txt"
          writeAll(outTxt, transcript)
          txtPath = outTxt

          -- Optionally restore punctuation/casing before downstream processors
          local punctuateMs = nil
          -- Deprecated punctuator removed; Java PunctuationProcessor handles punctuation. No-op.
          local function applyPunctuatorIfEnabled(text)
            return text
          end


          -- Decide output behavior per session kind
          local DEFAULT_OUTPUT = {
            HOLD = { mode = "paste",  format = "txt" },
            TOGGLE = { mode = "editor", format = "md" },
            SHIFT_TOGGLE = { mode = "editor", format = "md" },
          }
          local outputCfg = (type(cfg.OUTPUT) == "table") and cfg.OUTPUT or DEFAULT_OUTPUT
          local modeCfg
          if isShiftToggle then
            -- Shift+F13 always uses SHIFT_TOGGLE output mode (markdown editor)
            modeCfg = outputCfg.SHIFT_TOGGLE or DEFAULT_OUTPUT.SHIFT_TOGGLE
          elseif sessionKind == "toggle" then
            -- Double-tap F13 uses TOGGLE mode
            modeCfg = outputCfg.TOGGLE or DEFAULT_OUTPUT.TOGGLE
          else
            -- Regular F13 hold uses HOLD mode
            modeCfg = outputCfg.HOLD or DEFAULT_OUTPUT.HOLD
          end

          local function doLogSuccess(finalText, extra)
            local baseNoExt = audioPath:gsub("%.wav$", "")
            local jsonPath = baseNoExt .. ".json"
            local payload = {
              wav = wavPath,
              duration_sec = dur,
              wav_bytes = bytes,
              preprocess_used = doPre,
              audio_used = audioPath,
              canonical_wav = audioPath,
              audio_processing_chain = audioProcessingChain,
              json_path = jsonPath,
              tx_ms = ms,
              tx_code = wcode,
              transcript_chars = #finalText,
              transcript = finalText,
              session_kind = sessionKind,
              output_mode = modeCfg.mode,
              output_format = modeCfg.format,
              reflow_total_segments = reflowStats.total_segments,
              reflow_dropped_segments = reflowStats.dropped_segments,
              punctuate_ms = punctuateMs,
            }
            if extra then for k,v in pairs(extra) do payload[k]=v end end
            logEvent("success", payload)

            -- Export test fixture when in test mode
            local tcfg = cfg.TEST_FIXTURE_EXPORT or {}
            if isTestMode() and tcfg.ENABLED ~= false then
              local category = testFixtureNextCategory
              if not category or (tcfg.MODE == "auto") then
                category = categorizeDuration(dur or 0)
              end
              -- txtPath is set earlier when we wrote out the transcript
              exportTestFixture(category, audioPath, jsonPath, txtPath)
              testFixtureNextCategory = nil
            end
          end

          local function slugify(s)
            s = tostring(s or "")
            -- Trim whitespace
            s = s:gsub("^%s+", ""):gsub("%s+$", "")
            -- Replace control characters (including newlines) with space
            s = s:gsub("[%z\1-\31]", " ")
            -- Normalize to lowercase
            s = s:lower()
            -- Keep alphanumerics, dashes and spaces; replace others with space
            s = s:gsub("[^%w%-%s]", " ")
            -- Collapse spaces to single dash
            s = s:gsub("%s+", "-")
            -- Collapse multiple dashes
            s = s:gsub("%-+", "-")
            -- Trim leading/trailing dashes
            s = s:gsub("^%-", ""):gsub("%-$", "")
            return (s == "" and "note") or s
          end

          local function saveAndOpenMarkdown(finalText)
            ensureDir(NOTES_DIR .. "/refined")
            local tsname = os.date("%Y-%m-%d_%H-%M")
            local firstLine = finalText:match("^([^\n]+)") or "note"
            local name = tsname .. "_" .. slugify(firstLine):sub(1,60) .. ".md"
            local mdPath = NOTES_DIR .. "/refined/" .. name
            writeAll(mdPath, finalText)
            -- Open with OS default handler for .md
            hs.execute(string.format([[open %q]], mdPath))
            if SOUND_ENABLED then playSound("Glass") end
            log.i(string.format("OPENED MD (%d chars): %s", #finalText, name))
            return mdPath
          end

          local function updateLearningSideEffect(text)
            -- Fire-and-forget: send text to VoxCompose learning hook if present
            local hook = HOME .. "/code/voxcompose/tools/learn_from_text.py"
            if (not text) or text == "" then return end
            if not hs.fs.attributes(hook) then return end
            local tmp = os.tmpname()
            writeAll(tmp, text)
            local bash = "/bin/bash"
            local cmd = string.format("cat %q | /usr/bin/env python3 %q >/dev/null 2>&1; rm -f %q", tmp, hook, tmp)
            pcall(function()
              local t = hs.task.new(bash, function() end, {"-lc", cmd})
              if t then t:start() end
            end)
          end

          local function finishWithText(finalText, extra)
            -- Update learning side-effect (non-blocking)
            updateLearningSideEffect(finalText)
            -- Optional terminal tweaks
            if ENSURE_TRAILING_PUNCT then finalText = ensureTrailingPunct(finalText) end
            if PASTE_TRAILING_NEWLINE then finalText = addTrailingNewline(finalText) end

            if sessionKind == "toggle" and modeCfg.mode == "editor" and (modeCfg.format == "md" or modeCfg.format == "markdown") then
              local mdPath = saveAndOpenMarkdown(finalText)
              local e = extra or {}
              e.output_path = mdPath
              doLogSuccess(finalText, e)
            else
              -- HOLD flow: paste
              hs.pasteboard.setContents(finalText)
              hs.timer.doAfter(0.02, function() hs.eventtap.keyStroke({"cmd"}, "v", 0) end)
              if SOUND_ENABLED then playSound("Glass") end
              log.i(string.format("PASTED %d chars", #finalText))
              doLogSuccess(finalText, extra)
            end
            updateIndicator("off")
            stopBlink()
          end

          -- Optionally refine for TOGGLE sessions
          local refCfg = cfg.LLM_REFINER or {}
          if sessionKind == "toggle" and refCfg.ENABLED then
            -- Check if Ollama is running (for local LLM refinement)
            local function ollamaAvailable()
              local out = hs.execute([[curl -sS --max-time 0.5 http://127.0.0.1:11434/api/tags 2>/dev/null]]) or ""
              return (out ~= nil and #out > 0)
            end
            if not ollamaAvailable() then
              hs.alert.show("Refine unavailable: Ollama not running")
              logEvent("refine_unavailable", { reason = "ollama_unreachable", wav = wavPath })
              finishWithText(transcript)
              return
            end
            local argv = resolveRefinerArgv()
            -- Sidecar path for refiner metrics
            local sidecarPath = sessionDir .. "/refine.json"
            table.insert(argv, "--sidecar"); table.insert(argv, sidecarPath)
            if #argv == 0 then finishWithText(transcript); return end
            local outBuf, errBuf = {}, {}
            local refineStart = nowMs()
            local refineTask
            refineTask = hs.task.new(argv[1], function(rc,so,se)
              local refined = table.concat(outBuf)
              if tonumber(rc) ~= 0 or refined:gsub("%s+","") == "" then refined = transcript end
              local rMs = nowMs() - refineStart
              -- Try to read sidecar for provider/model/metrics
              local extra = { }
              if hs.fs.attributes(sidecarPath) then
                local sctxt = readAll(sidecarPath)
                local okSC, sc = pcall(function() return json.decode(sctxt) end)
                if okSC and type(sc) == "table" then
                  extra.refine_ms = tonumber(sc.refine_ms) or rMs
                  extra.refine_provider = sc.provider
                  extra.refine_model = sc.model
                end
              end
              if not extra.refine_ms then extra.refine_ms = rMs end
              logEvent("refine", { cmd = argv[1], args = table.concat(argv, " "), rc = rc, ms = extra.refine_ms, out_chars = #refined, provider = extra.refine_provider, model = extra.refine_model })
              finishWithText(refined, extra)
            end, function(t, so, se)
              if so and #so>0 then table.insert(outBuf, so) end
              if se and #se>0 then table.insert(errBuf, se) end
              return true
            end, {table.unpack(argv, 2)})
            refineTask:setInput(true)
            -- Provide PATH and HOME in env
            pcall(function() refineTask:setEnvironment({ PATH = os.getenv("PATH"), HOME = HOME }) end)
            refineTask:start()
            refineTask:write(transcript)
            if refineTask.closeInput then refineTask:closeInput() end
            -- Optional timeout
            local to = tonumber(refCfg.TIMEOUT_MS or 0) or 0
            if to > 0 then
              hs.timer.doAfter(to/1000, function()
                if refineTask then pcall(function() refineTask:sendSignal(2) end); pcall(function() refineTask:terminate() end) end
              end)
            end
          else
            finishWithText(transcript)
          end
        end, function(task, stdOut, stdErr)
          if stdOut and #stdOut > 0 then table.insert(whStdoutBuf, stdOut) end
          if stdErr and #stdErr > 0 then table.insert(whStderrBuf, stdErr) end
          return true
        end, wargs)

        -- Ensure ffmpeg is visible inside the whisper (pipx) environment
        local basePath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        local envPath = basePath .. ":" .. (os.getenv("PATH") or "")
        pcall(function()
          whisperTask:setEnvironment({ PATH = envPath, HOME = HOME })
        end)

        whisperTask:start()
        -- Set a timeout to avoid hanging transcriptions
        if TIMEOUT_MS and TIMEOUT_MS > 0 then
          whisperTimeoutTimer = hs.timer.doAfter(TIMEOUT_MS/1000, function()
            local limitSec = math.floor((TIMEOUT_MS or 0)/1000)
            local bn = baseName or (wavPath and wavPath:match("([^/]+)%.wav$")) or "recording"
            local msg
            if dur and dur > limitSec then
              msg = string.format("'%s' is %.0fs long, exceeding the %ds transcription limit. Transcript not produced.", bn, dur, limitSec)
            else
              msg = string.format("Transcription timed out after %ds for '%s'. Transcript not produced.", limitSec, bn)
            end
            log.e(string.format("TX timeout after %dms (device=%s, model=%s, beam=%d): %s", TIMEOUT_MS, WHISPER_DEVICE, tostring(chosenModel), tonumber(chosenBeam) or -1, bn))
            hs.alert.show(msg)
            -- Log timeout event
            logEvent("timeout", {
              wav = wavPath,
              duration_sec = dur,
              wav_bytes = bytes,
              preprocess_used = doPre,
              tx_ms = TIMEOUT_MS,
              tx_code = -1,
              base_name = bn,
              reason = "timeout",
            })
            if whisperTask then
              local ok = pcall(function() whisperTask:sendSignal(2) end)
              if not ok then pcall(function() whisperTask:terminate() end) end
            end
            updateIndicator("off")
            stopBlink()
            if SOUND_ENABLED then playSound("Funk") end
          end)
        end
        -- In normal mode, we already showed transcribing; upon completion we'll turn it off
      end

      -- Preprocess then run whisper (only for longer clips)
      local audioProcessingChain = "raw"
      if doPre then
        preprocessAudio(wavPath, function(ok, usePath)
          local chosenAudio = usePath or wavPath
          if ok and usePath and usePath ~= wavPath then
            -- Normalization succeeded
            audioProcessingChain = "raw->norm"
            if cfg.CANONICALIZE_NORMALIZED_TO_WAV == true then
              -- Canonicalize: remove raw, rename normalized to original name
              if hs.fs.attributes(wavPath) then pcall(function() os.remove(wavPath) end) end
              local renamed = pcall(function() os.rename(usePath, wavPath) end)
              if renamed then
                chosenAudio = wavPath
              else
                -- Fallback: keep normalized path; optionally remove raw if configured
                chosenAudio = usePath
                if (cfg.PREPROCESS_KEEP_RAW ~= true) and hs.fs.attributes(wavPath) then pcall(function() os.remove(wavPath) end) end
              end
            else
              -- Keep normalized path; optionally remove raw
              if (cfg.PREPROCESS_KEEP_RAW ~= true) and hs.fs.attributes(wavPath) then pcall(function() os.remove(wavPath) end) end
              chosenAudio = usePath
            end
          else
            -- Normalization not used or failed
            audioProcessingChain = "raw"
          end
          runWhisper(chosenAudio)
        end)
      else
        runWhisper(wavPath)
      end
    end

    startTranscribe()
  end

  ffTask = hs.task.new(FFMPEG, onFFExit, function(task, stdOut, stdErr)
    if stdOut and #stdOut > 0 then table.insert(ffStdoutBuf, stdOut) end
    if stdErr and #stdErr > 0 then
      -- Inline wave meter: parse RMS level from stderr in real-time
      if WAVE_METER_MODE == "inline" then
        local db = stdErr:match("RMS_level:%s*([%-%d%.]+)%s*dB")
        if db then
          local val = mapDbToLevel(tonumber(db))
          if val and val==val then
            levelVal = val
            if val > recordPeak then recordPeak = val end
            if (not recordArmed) then
              recordArmed = true
              if armTimer then armTimer:stop(); armTimer=nil end
              if SOUND_ENABLED then playSound("Tink") end
              updateIndicator("recording")
              log.d("Armed via first RMS sample")
            end
          end
        end
      end
      table.insert(ffStderrBuf, stdErr)
    end
    return true
  end, args)


  local ok, err = pcall(function() ffTask:start() end)
  if not ok then
    -- User-friendly error with actionable hint
    local deviceMsg = string.format("🎤 Recording failed (device %d)\n\nPress Cmd+Alt+Ctrl+D to diagnose", AUDIO_DEVICE_INDEX)
    hs.alert.show(deviceMsg, {textSize = 14}, 4)
    
    -- Detailed error in console
    log.e("FFmpeg failed to start: " .. tostring(err))
    log.e("Device spec: " .. deviceSpec)
    log.e("FFmpeg path: " .. FFMPEG)
    
    -- Log event for tracking
    logEvent("ffmpeg_start_error", {
      error = tostring(err),
      device_index = AUDIO_DEVICE_INDEX,
      device_spec = deviceSpec,
      ffmpeg_path = FFMPEG
    })
    
    -- Clean up UI state
    updateIndicator("off")
    recording = false
    return
  end
  startMs = nowMs()
  -- Timing probe: how long from key-down to ffmpeg start
  if f13DownAt then
    logEvent("record_start", { t_ms = startMs, delta_ms = (startMs - f13DownAt) })
  end
  heldMs = 0
  recordPeak = 0.0
  recording = true
  recordPeak = 0.0
  -- UI: wave indicator + dot
  if WAVE_METER_MODE ~= "off" then
    showLevelIndicator()
    if WAVE_METER_MODE == "monitor" then
      startLevelMonitor()
    end
  end
  updateIndicator("recording")
  if SOUND_ENABLED then playSound("Pop") end
  log.i("Recording started: " .. wavPath .. " via device " .. deviceSpec .. ", session=" .. tostring(sessionKind))
end

local function stopRecording()
  if not recording then
    if isTestMode() then log.d("[TEST] stopRecording called while not recording") end
    return
  end
  heldMs = nowMs() - startMs
  
  -- Remember if this was a Shift+F13 session before resetting
  local wasShiftToggle = isShiftToggle
  if isTestMode() then
    log.d("[TEST] Would stop ffmpeg (heldMs=" .. tostring(heldMs) .. ") and transcribe")
    updateIndicator("off")
    stopBlink()
    if armTimer then armTimer:stop(); armTimer=nil end
    recording = false
    return
  end
  if ffTask then
    -- Stop level indicator/monitor immediately
    hideLevelIndicator()
    stopLevelMonitor()
    if armTimer then armTimer:stop(); armTimer=nil end
    -- Try sending 'q' via stdin for graceful finalize
    local wrote = pcall(function()
      ffTask:setInput(true)
      ffTask:write("q")
      if ffTask.closeInput then ffTask:closeInput() end
    end)
    if not wrote then
      -- Fallback to SIGINT, then terminate
      local ok = pcall(function() ffTask:sendSignal(2) end)
      if not ok then pcall(function() ffTask:terminate() end) end
    end
  end
end

-- Key handling: configurable PTT hotkeys (defaults: F13 hold, Shift+F13 toggle) and Fn+T test toggle
local f13Hotkey
local shiftF13Hotkey
local resolvedKeys = nil
local function startTaps()
  if keyTap then keyTap:stop() end
  if flagTap then flagTap:stop() end
  if f13Hotkey then f13Hotkey:delete() end
  if shiftF13Hotkey then shiftF13Hotkey:delete() end

  local function clearHoldTimer()
    if holdStartTimer then holdStartTimer:stop(); holdStartTimer = nil end
  end

  local function startHoldAfterThreshold()
    clearHoldTimer()
    if f13DownAt and (not recording) then
      sessionKind = "hold"
      ignoreHoldThreshold = false
      isShiftToggle = false  -- Regular F13 hold
      startRecording()
    end
  end

  local function toggleSession()
    if not recording then
      sessionKind = "toggle"; 
      ignoreHoldThreshold = true; 
      isShiftToggle = false;  -- Double-tap, not Shift+F13
      startRecording()
    else
      if sessionKind == "toggle" then stopRecording() end
    end
  end

  flagTap = hs.eventtap.new({ hs.eventtap.event.types.flagsChanged }, function(evt)
    local f = evt:getFlags()
    local wasHeld = fnHeld
    fnHeld = f.fn or false
    if wasHeld and not fnHeld then
      -- No state reset needed here
    end
    return false
  end)
  flagTap:start()

  keyTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyRepeat }, function(evt)
    local code = evt:getKeyCode()
    local et = evt:getType()

    -- Grouped Fn combos: T (toggle test), R (reload), O (open init.lua), 1/2/3 (fixture category override)
    if fnHeld and et == hs.eventtap.event.types.keyDown then
      if code == hs.keycodes.map.t then
        setTestMode(not isTestMode())
        return true
      elseif code == hs.keycodes.map.r then
        hs.reload()
        hs.alert.show("Hammerspoon reloaded")
        return true
      elseif code == hs.keycodes.map.o then
        local initPath = (os.getenv("HOME") or "") .. "/.hammerspoon/init.lua"
        if hs.fs.attributes(initPath) then
          hs.execute(string.format([[open -a "Visual Studio Code" %q]], initPath))
          hs.alert.show("Opened init.lua in VS Code")
        else
          hs.alert.show("init.lua not found at ~/.hammerspoon/init.lua")
        end
        return true
      elseif code == hs.keycodes.map["1"] then
        testFixtureNextCategory = "short"
        hs.alert.show("Test fixture: next=short")
        return true
      elseif code == hs.keycodes.map["2"] then
        testFixtureNextCategory = "medium"
        hs.alert.show("Test fixture: next=medium")
        return true
      elseif code == hs.keycodes.map["3"] then
        testFixtureNextCategory = "long"
        hs.alert.show("Test fixture: next=long")
        return true
      elseif code == hs.keycodes.map["0"] then
        testFixtureNextCategory = nil
        hs.alert.show("Test fixture: next=auto")
        return true
      end
    end

    return false
  end)
  keyTap:start()

  -- Resolve key bindings from config (with fallbacks)
  local function _keySpec(name, defMods, defKey)
    local kcfg = (cfg.KEYS or {})[name]
    local mods = (kcfg and kcfg.mods) or defMods
    local key = (kcfg and kcfg.key) or defKey
    return mods, key
  end
  local function _comboToString(mods, key)
    local m = mods or {}
    if #m == 0 then return key end
    return table.concat(m, "+") .. "+" .. key
  end

local holdMods, holdKey = _keySpec("HOLD", {"cmd","alt","ctrl"}, "space")
  local holdStr = _comboToString(holdMods, holdKey)

-- Primary: press/release callbacks for hold-to-talk (with double-tap toggle)
f13Hotkey = hs.hotkey.bind(holdMods, holdKey,
  function() -- pressed
    log.i("PTT pressed (" .. holdStr .. ")")
    f13DownAt = nowMs()
    -- Immediately start recording (pre-roll): don't wait for HOLD_THRESHOLD_MS
    sessionKind = "hold"
    ignoreHoldThreshold = false
    isShiftToggle = false
    startRecording()
    -- Timing probe
    logEvent("key_down", { t_ms = f13DownAt })
  end,
  function() -- released
    log.i("PTT released (" .. holdStr .. ")")
    local upMs = nowMs()
    local downMs = f13DownAt
    f13DownAt = nil
    clearHoldTimer()

    if recording and sessionKind == "hold" then
      -- Normal hold release ends recording
      stopRecording()
      return
    end

    -- If we reached here, we did not start hold recording (released before threshold)
    if DOUBLE_TAP_ENABLED then
      if lastTapMs and (upMs - lastTapMs) <= DOUBLE_TAP_WINDOW_MS then
        lastTapMs = nil
        log.i("PTT double-tap detected → toggle")
        toggleSession()
        return
      else
        lastTapMs = upMs
        -- Single tap: no-op (prevents accidental micro recordings)
        hs.timer.doAfter((DOUBLE_TAP_WINDOW_MS/1000), function() lastTapMs = nil end)
      end
    end

    -- Clean up any stuck UI state from accidental tap
    if indicator then
      updateIndicator("off")
      stopBlink()
    end
  end
)

  -- Toggle on press (configurable)
local toggleStr = "disabled"
  if (cfg.SHIFT_TOGGLE_ENABLED ~= false) then
    local toggleMods, toggleKey = _keySpec("TOGGLE", {"cmd","alt","ctrl","shift"}, "space")
    toggleStr = _comboToString(toggleMods, toggleKey)
    shiftF13Hotkey = hs.hotkey.bind(toggleMods, toggleKey,
      function() -- pressed
        log.i("Toggle pressed (" .. toggleStr .. ")")
        if not recording then
          sessionKind = "toggle"; 
          ignoreHoldThreshold = true; 
          isShiftToggle = true;  -- This is Shift+F13, use markdown
          startRecording()
        else
          if sessionKind == "toggle" then stopRecording() end
        end
      end,
      function() -- released (no-op)
      end
    )
  end

resolvedKeys = {
    hold = { mods = holdMods, key = holdKey, combo = holdStr },
    toggle = (cfg.SHIFT_TOGGLE_ENABLED ~= false) and (function()
      local m,k = _keySpec("TOGGLE", {"cmd","alt","ctrl","shift"}, "space")
      return { mods = m, key = k, combo = toggleStr }
    end)() or nil
  }
  log.i("push_to_talk: " .. holdStr .. " hold + " .. toggleStr .. " toggle armed (testMode=" .. tostring(isTestMode()) .. ")")

  -- Initialize logger level according to current mode
  do
    setLogLevelCompat(log, isTestMode() and "debug" or "info")
  end
end

function M.start()
  startTaps()
  detectWhisperDevice()
  -- Optional: bind diagnostic keys (configurable; defaults Cmd+Alt+Ctrl)
  local function _keySpec(name, defMods, defKey)
    local kcfg = (cfg.KEYS or {})[name]
    local mods = (kcfg and kcfg.mods) or defMods
    local key = (kcfg and kcfg.key) or defKey
    return mods, key
  end
  local infoMods, infoKey = _keySpec("INFO", {"cmd", "alt", "ctrl"}, "I")
  local refMods, refKey = _keySpec("REFINER_TEST", {"cmd", "alt", "ctrl"}, "R")
  local diagMods, diagKey = _keySpec("DIAGNOSTICS", {"cmd", "alt", "ctrl"}, "D")
  hs.hotkey.bind(infoMods, infoKey, function() showInfo() end)
  hs.hotkey.bind(refMods, refKey, function() refineSelfTest() end)
  hs.hotkey.bind(diagMods, diagKey, function() runDiagnostics() end)
end

function M.stop()
  if keyTap then keyTap:stop() end
  if flagTap then flagTap:stop() end
end

-- Test helper: expose resolved key combos for verification
function M._resolvedKeys()
  return resolvedKeys
end

-- Test hooks (for integration testing reflow)
function M._reflowFromSegments(segments)
  return reflowFromSegments(segments or {})
end
function M._reflowFromJson(jsonPath)
  local jtxt = readAll(jsonPath)
  if not jtxt then return "" end
  local ok, parsed = pcall(function() return json.decode(jtxt) end)
  if not ok or not parsed or not parsed.segments then return "" end
  return reflowFromSegments(parsed.segments)
end

return M

