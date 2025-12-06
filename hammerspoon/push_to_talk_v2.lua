-- ~/.hammerspoon/push_to_talk.lua (V2 - Thin Wrapper)
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
local AUDIO_DEVICE_INDEX = cfg.AUDIO_DEVICE_INDEX or 0
local SOUND_ENABLED = (cfg.SOUND_ENABLED ~= false)
local VOXCORE_CLI = cfg.VOXCORE_CLI or "/opt/homebrew/bin/voxcore"
local VOCABULARY_FILE = expandPath(cfg.VOCABULARY_FILE or "~/.config/voxcompose/vocabulary.txt")

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
local pulsePhase = 0

local function showMicIndicator(color)
  if micCanvas then micCanvas:delete() end

  local screen = hs.screen.mainScreen()
  local frame = screen:frame()
  local size = 80
  local x = frame.x + (frame.w - size) / 2
  local y = frame.y + 100

  micCanvas = hs.canvas.new{x = x, y = y, w = size, h = size}
  micCanvas:appendElements({
    type = "circle",
    action = "stroke",
    strokeColor = color or {red = 1, green = 0.3, blue = 0.3, alpha = 0.9},
    strokeWidth = 4,
    frame = {x = 5, y = 5, w = size - 10, h = size - 10}
  })
  micCanvas:show()

  -- Pulsing animation
  if pulseTimer then pulseTimer:stop() end
  pulseTimer = hs.timer.doEvery(0.05, function()
    pulsePhase = (pulsePhase + 0.1) % (2 * math.pi)
    local scale = 1 + 0.15 * math.sin(pulsePhase)
    local offset = (size * (1 - scale)) / 2
    micCanvas[1].frame = {x = offset, y = offset, w = size * scale - 10, h = size * scale - 10}
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

local function transcribeWithVoxCore(audioPath)
  local args = {"transcribe", audioPath}

  -- Add vocabulary if available
  if hs.fs.attributes(VOCABULARY_FILE) then
    table.insert(args, "--vocabulary")
    table.insert(args, VOCABULARY_FILE)
  end

  local output, status = hs.execute(string.format("%s %s 2>&1",
    VOXCORE_CLI, table.concat(args, " ")))

  if not status then
    log.e("VoxCore CLI failed")
    return nil, "CLI execution failed"
  end

  -- Extract transcript (CLI outputs to stdout)
  local transcript = output:match("^%s*(.-)%s*$")  -- trim whitespace
  if not transcript or transcript == "" then
    return nil, "Empty transcript"
  end

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

  local deviceSpec = ":" .. tostring(AUDIO_DEVICE_INDEX)
  local ffmpegArgs = {
    "-hide_banner", "-loglevel", "error",
    "-nostats", "-y",
    "-f", "avfoundation",
    "-i", deviceSpec,
    "-ac", "1", "-ar", "16000",
    "-sample_fmt", "s16",
    "-vn", wavPath
  }

  local onFFExit = function(code, stdout, stderr)
    hideMicIndicator()
    recording = false

    if tonumber(code) ~= 0 and tonumber(code) ~= 255 then
      log.e("Recording failed: " .. tostring(stderr))
      hs.alert.show("🎤 Recording error")
      return
    end

    -- Show processing indicator
    showMicIndicator({red = 1, green = 0.8, blue = 0, alpha = 0.9})

    -- Transcribe
    local transcript, err = transcribeWithVoxCore(wavPath)
    hideMicIndicator()

    if not transcript then
      log.e("Transcription failed: " .. tostring(err))
      hs.alert.show("❌ Transcription failed")
      return
    end

    log.i(string.format("Transcribed: %d chars", #transcript))

    -- Paste result
    pasteText(transcript)
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
  local mods = cfg.HOLD_MODS or {"cmd", "alt", "ctrl"}
  local key = cfg.HOLD_KEY or "space"

  hs.hotkey.bind(mods, key,
    function() startRecording() end,
    function() stopRecording() end
  )

  log.i(string.format("VoxCore ready: %s+%s", table.concat(mods, "+"), key))
end

setupHotkeys()

return M
