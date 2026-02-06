-- ~/.hammerspoon/push_to_talk_v2.lua (Thin Wrapper)
-- Press Cmd+Alt+Ctrl+Space to record; release to transcribe and paste
-- Dependencies: voxcore CLI (brew install voxcore), ffmpeg (brew install ffmpeg)

local M = {}
local log = hs.logger.new("voxcore", "info")

------------------
-- CONFIG LOADING
------------------

local cfg = {}
local function loadConfig()
  -- Try ptt_config.lua via require first
  local ok, t = pcall(require, "ptt_config")
  if ok and type(t) == "table" then
    cfg = t
    return
  end

  -- Try XDG config paths
  local xdg = os.getenv("XDG_CONFIG_HOME")
  local paths = {}
  if xdg and xdg ~= "" then
    table.insert(paths, xdg .. "/voxcore/ptt_config.lua")
  end
  table.insert(paths, (os.getenv("HOME") or "") .. "/.config/voxcore/ptt_config.lua")

  for _, p in ipairs(paths) do
    if p and hs.fs.attributes(p) then
      local okx, tx = pcall(dofile, p)
      if okx and type(tx) == "table" then
        cfg = tx
        return
      end
    end
  end

  -- Fallback to empty config
  cfg = {}
end
loadConfig()

------------------
-- PATH UTILITIES
------------------

local function expandPath(path)
  if not path or path == "" then return path end
  local HOME = os.getenv("HOME") or ""
  path = path:gsub("^~", HOME)
  path = path:gsub("%$(%w+)", function(var) return os.getenv(var) or ("$" .. var) end)
  path = path:gsub("%${([^}]+)}", function(var) return os.getenv(var) or ("${" .. var .. "}") end)
  return path
end

local function ensureDir(path)
  local expanded = expandPath(path)
  if not hs.fs.attributes(expanded) then
    hs.execute(string.format("mkdir -p %q", expanded))
  end
  return expanded
end

------------------
-- CONFIGURATION
------------------

local NOTES_DIR = ensureDir(expandPath(cfg.NOTES_DIR or "~/Documents/VoiceNotes"))
local AUDIO_DEVICE_INDEX = cfg.AUDIO_DEVICE_INDEX  -- nil means auto-detect
local AUDIO_DEVICE_NAME = cfg.AUDIO_DEVICE_NAME or "MacBook Pro Microphone"  -- Preferred device by name
local SOUND_ENABLED = (cfg.SOUND_ENABLED ~= false)
local VOXCORE_CLI = cfg.VOXCORE_CLI or "/opt/homebrew/bin/voxcore"
local VOXCOMPOSE_CLI = cfg.VOXCOMPOSE_CLI or "/opt/homebrew/bin/voxcompose"
local VOCABULARY_FILE = expandPath(cfg.VOCABULARY_FILE or "~/.config/voxcompose/vocabulary.txt")
local LOG_DIR = ensureDir(NOTES_DIR .. "/tx_logs")
local LOG_ENABLED = (cfg.LOG_ENABLED ~= false)

-- Model selection: automatically pick model based on recording duration
local DYNAMIC_MODEL = (cfg.DYNAMIC_MODEL ~= false)  -- default: true
local MODEL_THRESHOLD_SEC = cfg.MODEL_THRESHOLD_SEC or 21
local SHORT_MODEL = cfg.SHORT_MODEL or "base.en"
local LONG_MODEL = cfg.LONG_MODEL or "medium.en"

-- Debug mode: passes --debug to VoxCore CLI for verbose output
local DEBUG_MODE = (cfg.DEBUG_MODE == true)  -- default: false

------------------
-- DEVICE DETECTION
------------------

-- Find audio device index by name pattern (handles iPhone Continuity shifts)
local function findAudioDeviceByName(pattern)
  local cmd = '/opt/homebrew/bin/ffmpeg -f avfoundation -list_devices true -i "" 2>&1'
  local output = hs.execute(cmd) or ""
  
  local inAudioSection = false
  for line in output:gmatch("[^\r\n]+") do
    if line:match("AVFoundation audio devices:") then
      inAudioSection = true
    elseif inAudioSection then
      local index, name = line:match("%[(%d+)%]%s*(.+)")
      if index and name and name:match(pattern) then
        log.i(string.format("Found audio device '%s' at index %s", name, index))
        return tonumber(index), name
      end
    end
  end
  return nil, nil
end

-- Resolve the audio device to use (by name first, then fallback to index)
local function resolveAudioDevice()
  -- If explicit index is set and no name preference, use index directly
  if AUDIO_DEVICE_INDEX and not cfg.AUDIO_DEVICE_NAME then
    return AUDIO_DEVICE_INDEX
  end
  
  -- Try to find by name pattern
  local index, name = findAudioDeviceByName(AUDIO_DEVICE_NAME)
  if index then
    return index
  end
  
  -- Fallback: try common built-in mic patterns
  local fallbackPatterns = {"MacBook Pro Microphone", "MacBook Air Microphone", "Built%-in Microphone"}
  for _, pattern in ipairs(fallbackPatterns) do
    index, name = findAudioDeviceByName(pattern)
    if index then
      log.w(string.format("Preferred device '%s' not found, using fallback '%s'", AUDIO_DEVICE_NAME, name))
      return index
    end
  end
  
  -- Last resort: use configured index or 0
  log.w("No matching audio device found, using index " .. tostring(AUDIO_DEVICE_INDEX or 0))
  return AUDIO_DEVICE_INDEX or 0
end

------------------
-- VOCABULARY
------------------

-- Refresh VoxCompose vocabulary (non-blocking background task)
-- Exports learned vocabulary to vocabulary.txt for Whisper prompt hints
local function refreshVocabulary()
  if not hs.fs.attributes(VOXCOMPOSE_CLI) then return end
  hs.task.new(VOXCOMPOSE_CLI, function(code, stdout, stderr)
    if tonumber(code) == 0 then
      log.i("Vocabulary refreshed from VoxCompose")
    else
      log.d("Vocabulary refresh skipped (no learned profile yet)")
    end
  end, {"--export-vocabulary"}):start()
end

------------------
-- STATE
------------------

local recording = false
local recordTask = nil
local wavPath = nil

------------------
-- UI HELPERS
------------------

local micCanvas = nil
local pulseTimer = nil
local ripples = {}

local function showMicIndicator(color)
  -- Ripple animation - expanding rings that fade out
  if pulseTimer then pulseTimer:stop() end
  ripples = {}
  local frameCount = 0

  pulseTimer = hs.timer.doEvery(0.05, function()
    if micCanvas then pcall(function() micCanvas:delete() end) end

    local screen = hs.screen.mainScreen()
    local frame = screen:frame()
    local size = 100
    local x = math.floor(frame.x + frame.w / 2 - size / 2)
    local y = frame.y + 80

    -- Spawn new ripple every 15 frames (~0.75s)
    frameCount = frameCount + 1
    if frameCount % 15 == 0 then
      table.insert(ripples, {radius = 8, alpha = 0.9})
    end

    -- Update and draw ripples
    micCanvas = hs.canvas.new({x = x, y = y, w = size, h = size})

    local activeRipples = {}
    for _, ripple in ipairs(ripples) do
      ripple.radius = ripple.radius + 1.2
      ripple.alpha = ripple.alpha - 0.025

      if ripple.alpha > 0 and ripple.radius < 45 then
        table.insert(activeRipples, ripple)
        local c = color or {red = 1, green = 0.3, blue = 0.3}
        micCanvas:appendElements({
          type = "circle",
          radius = ripple.radius,
          action = "stroke",
          strokeColor = {red = c.red, green = c.green, blue = c.blue, alpha = ripple.alpha},
          strokeWidth = 3
        })
      end
    end
    ripples = activeRipples

    -- Center mic indicator (solid circle)
    local c = color or {red = 1, green = 0.3, blue = 0.3}
    micCanvas:appendElements({
      type = "circle",
      radius = 7,
      action = "fill",
      fillColor = {red = c.red, green = c.green, blue = c.blue, alpha = 0.95}
    })

    micCanvas:show()
  end)
end

local function hideMicIndicator()
  if pulseTimer then pulseTimer:stop(); pulseTimer = nil end
  if micCanvas then micCanvas:delete(); micCanvas = nil end
end

local function playSound(name)
  if SOUND_ENABLED then
    hs.sound.getByName(name):play()
  end
end

------------------
-- CORE LOGIC
------------------

local function humanTimestamp()
  return os.date("%Y-%m-%d_%H-%M-%S")
end

local function isoNow()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function nowMs()
  return hs.timer.absoluteTime() / 1000000
end

-- Transaction logging (JSONL format)
local function appendJSONL(path, obj)
  local f = io.open(path, "a")
  if not f then return false end
  f:write(hs.json.encode(obj) .. "\n")
  f:close()
  return true
end

local function logEvent(kind, data)
  if not LOG_ENABLED then return end
  ensureDir(LOG_DIR)
  local daily = string.format("%s/tx-%s.jsonl", LOG_DIR, os.date("%Y-%m-%d"))
  local payload = {
    ts = isoNow(),
    kind = kind,
    app = "voxcore",
    version = "v0.7.0",
  }
  if data then
    for k, v in pairs(data) do payload[k] = v end
  end
  appendJSONL(daily, payload)
end

local function transcribeWithVoxCore(audioPath, model)
  -- VoxCore CLI loads vocabulary from config file (~/.config/voxcompose/vocabulary.txt)
  -- Capture stderr to error log file for debugging
  local errorLogPath = LOG_DIR .. "/voxcore_errors.log"
  local cmd = string.format("%s transcribe %q", VOXCORE_CLI, audioPath)
  if model then
    cmd = cmd .. string.format(" --model %s", model)
  end
  if DEBUG_MODE then
    cmd = cmd .. " --debug"
  end
  cmd = cmd .. string.format(" 2>> %q", errorLogPath)
  log.i(string.format("Executing: %s", cmd))

  local txStart = nowMs()
  local output, status = hs.execute(cmd)
  local txMs = math.floor(nowMs() - txStart)

  -- Get file size for logging
  local wavBytes = 0
  local wavAttrs = hs.fs.attributes(audioPath)
  if wavAttrs then wavBytes = wavAttrs.size or 0 end

  if not status then
    log.e(string.format("VoxCore CLI failed. Check %s for details", errorLogPath))
    log.e(string.format("Audio file saved: %s", audioPath))
    logEvent("error", {
      wav = audioPath,
      wav_bytes = wavBytes,
      tx_ms = txMs,
      error = "CLI execution failed",
    })
    return nil, "CLI execution failed"
  end

  -- Extract transcript (CLI outputs to stdout, trim whitespace)
  local transcript = output:match("^%s*(.-)%s*$")
  if not transcript or transcript == "" then
    log.e(string.format("Empty transcript. Raw output: %s", output or "nil"))
    log.e(string.format("Audio file saved: %s", audioPath))
    logEvent("error", {
      wav = audioPath,
      wav_bytes = wavBytes,
      tx_ms = txMs,
      error = "Empty transcript",
      raw_output = output or "nil",
    })
    return nil, "Empty transcript"
  end

  -- Log success
  logEvent("success", {
    wav = audioPath,
    wav_bytes = wavBytes,
    tx_ms = txMs,
    model = model,
    transcript_chars = #transcript,
    transcript = transcript,
  })

  return transcript
end

local function pasteText(text)
  hs.pasteboard.setContents(text)
  hs.eventtap.keyStroke({"cmd"}, "v")
  if SOUND_ENABLED then playSound("Tink") end
end

local function startRecording()
  if recording then return end

  local baseName = humanTimestamp()
  local sessionDir = string.format("%s/%s", NOTES_DIR, baseName)
  ensureDir(sessionDir)

  wavPath = string.format("%s/%s.wav", sessionDir, baseName)

  -- Resolve device by name (handles iPhone Continuity appearing/shifting indices)
  local deviceIndex = resolveAudioDevice()
  local deviceSpec = ":" .. tostring(deviceIndex)
  local ffmpegArgs = {
    "-hide_banner", "-loglevel", "error",
    "-nostats", "-y",
    "-f", "avfoundation",
    "-i", deviceSpec,
    "-ac", "1", "-ar", "16000",
    "-sample_fmt", "s16",
    "-vn", wavPath
  }

  local recordStart = nowMs()
  local onFFExit = function(code, stdout, stderr)
    hideMicIndicator()
    recording = false
    local recordMs = math.floor(nowMs() - recordStart)

    if tonumber(code) ~= 0 and tonumber(code) ~= 255 then
      log.e("Recording failed: " .. tostring(stderr))
      hs.alert.show("🎤 Recording error")
      logEvent("recording_error", {
        wav = wavPath,
        code = tonumber(code),
        stderr = tostring(stderr),
        record_ms = recordMs,
      })
      return
    end

    -- Get audio duration (approximate from recording time)
    local durationSec = recordMs / 1000.0

    -- Select model based on duration (base.en is faster, medium.en is more accurate)
    local model = nil
    if DYNAMIC_MODEL then
      if durationSec < MODEL_THRESHOLD_SEC then
        model = SHORT_MODEL
      else
        model = LONG_MODEL
      end
      log.i(string.format("Audio %.1fs -> model: %s (threshold: %ds)", durationSec, model, MODEL_THRESHOLD_SEC))
    end

    -- Show processing indicator
    showMicIndicator({red = 1, green = 0.8, blue = 0, alpha = 0.9})

    -- Transcribe
    local transcript, err = transcribeWithVoxCore(wavPath, model)
    hideMicIndicator()

    if not transcript then
      log.e("Transcription failed: " .. tostring(err))
      hs.alert.show("❌ Transcription failed")
      return
    end

    log.i(string.format("Transcribed: %d chars in %.1fs (model: %s)", #transcript, durationSec, model or "default"))

    -- Paste result
    pasteText(transcript)

    -- Refresh vocabulary in background for next transcription
    refreshVocabulary()
  end

  recordTask = hs.task.new("/opt/homebrew/bin/ffmpeg", onFFExit, ffmpegArgs)
  recordTask:start()
  recording = true

  showMicIndicator({red = 1, green = 0.3, blue = 0.3, alpha = 0.9})
  playSound("Hero")
  log.i("Recording started")
end

local function stopRecording()
  if not recording or not recordTask then return end

  recordTask:terminate()
  log.i("Recording stopped")
end

------------------
-- HOTKEY BINDING
------------------

local function setupHotkeys()
  -- Support both old and new config formats
  local mods, key

  if cfg.KEYS and cfg.KEYS.HOLD then
    -- New format: KEYS = { HOLD = { mods = {}, key = "f13" } }
    mods = cfg.KEYS.HOLD.mods or {}
    key = cfg.KEYS.HOLD.key or "space"
  else
    -- Old format: HOLD_MODS = {"cmd", "alt", "ctrl"}, HOLD_KEY = "space"
    mods = cfg.HOLD_MODS or {"cmd", "alt", "ctrl"}
    key = cfg.HOLD_KEY or "space"
  end

  hs.hotkey.bind(mods, key,
    function() startRecording() end,
    function() stopRecording() end
  )

  local modsStr = #mods > 0 and table.concat(mods, "+") .. "+" or ""
  log.i(string.format("VoxCore ready: %s%s", modsStr, key))
end

setupHotkeys()

-- Initial vocabulary refresh on load
refreshVocabulary()

return M
