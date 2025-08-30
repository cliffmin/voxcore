-- ~/.hammerspoon/push_to_talk.lua
-- Press-and-hold F13 to record; release to stop, transcribe (offline), copy to clipboard, and paste at cursor.
-- Storage: ~/Documents/VoiceNotes/YYYY-MM-DD_HH-MM-SS.wav and .txt
-- Dependencies: ffmpeg (brew) and Whisper CLI installed via pipx (~/.local/bin/whisper)

local M = {}

local log = hs.logger.new("push_to_talk", "info")
local json = require("hs.json")

-- Optional external config
local cfg_ok, cfg = pcall(require, "ptt_config")
if not cfg_ok then cfg = {} end

-- Logger level compatibility (avoid warnings across Hammerspoon versions)
local function setLogLevelCompat(lg, levelStr)
  -- Try string first
  local ok = pcall(function() lg:setLogLevel(levelStr) end)
  if ok then return end
  -- Fallback numeric mapping
  local map = { debug = 4, info = 3, warning = 2, error = 1 }
  pcall(function() lg:setLogLevel(map[levelStr] or 3) end)
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
end

-- Config
local HOME = os.getenv("HOME") or ""
local NOTES_DIR = HOME .. "/Documents/VoiceNotes"
local FFMPEG = "/opt/homebrew/bin/ffmpeg"         -- absolute path for reliability
local WHISPER = HOME .. "/.local/bin/whisper"      -- pipx-installed whisper CLI

-- Logging configuration (defaults; can be overridden via ptt_config)
local LOG_DIR = (cfg.LOG_DIR and tostring(cfg.LOG_DIR)) or (NOTES_DIR .. "/tx_logs")
local LOG_ENABLED = (cfg.LOG_ENABLED ~= false)
local MODEL = "base.en"                             -- faster local model (English)
local LANG = "en"
local HOLD_THRESHOLD_MS = 150                       -- ignore ultra-short taps
local AUDIO_DEVICE_INDEX = 0                        -- avfoundation audio index (":0" by default)
local BUILTIN_SCREEN_PATTERN = "Built%-in"          -- choose the MacBook's built-in display by default

-- Transcript reflow options
local REFLOW_MODE = "gap"                           -- "gap" (use segment time gaps) or "singleline" (collapse single newlines)
local GAP_NEWLINE_SEC = cfg.GAP_NEWLINE_SEC or 1.75 -- newline if sentence end or gap >= this
local GAP_DOUBLE_NEWLINE_SEC = cfg.GAP_DOUBLE_NEWLINE_SEC or 2.50 -- paragraph break

-- Accuracy/perf tuning
local BEAM_SIZE = 3                                  -- beam search width (speed/accuracy balance)
local BEAM_SIZE_LONG = 3                             -- same for long audio
local WHISPER_DEVICE = "cpu"                        -- set to "mps" on Apple Silicon if available (auto-detected)
local VENV_PY = HOME .. "/.local/pipx/venvs/openai-whisper/bin/python"  -- python in pipx venv
local MODEL_FAST = "base.en"                          -- keep base for long audio as well
local LONG_AUDIO_SEC = 1e9                           -- effectively disable model switching
local PREPROCESS_MIN_SEC = 12.0                      -- preprocess only if reasonably long
local TIMEOUT_MS = 15000                             -- 15s timeout for faster fail on hangs

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

-- Debug buffers
local ffStdoutBuf, ffStderrBuf = {}, {}
local whStdoutBuf, whStderrBuf = {}, {}

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

local function logEvent(kind, data)
  if not LOG_ENABLED then return end
  -- Ensure log directory exists
  ensureDir(LOG_DIR)
  local daily = string.format("%s/tx-%s.jsonl", LOG_DIR, os.date("%Y-%m-%d"))
  local payload = {
    ts = isoNow(),
    kind = kind,
    app = "macos-ptt-dictation",
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

local function rstrip(s)
  return (s or ""):gsub("%s+$", "")
end

-- Reflow: join Whisper segments into readable text.
-- Newline only at sentence end or sufficiently large gaps; otherwise prefer spaces.
local function reflowFromSegments(segments)
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
  
  -- Strip common disfluencies as standalone words (edges or punctuation-bound)
  local function stripDisfluencies(s)
    local words = cfg.DISFLUENCIES or {}
    for _, w in ipairs(words) do
      -- beginning of string or whitespace before + optional punctuation after
      s = s:gsub("(^%s*" .. w .. ")([%s,%.%!%?])", "%2")
      s = s:gsub("([%s])" .. w .. "([%s,%.%!%?])", "%1%2")
    end
    -- normalize spaces again
    s = s:gsub("%s+([,%.!%?;:])", "%1"):gsub("[ \t]+", " ")
    return s
  end
  joined = stripDisfluencies(joined)
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
  indicator = hs.canvas.new({x = x, y = y, w = size, h = size}):level(hs.canvas.windowLevels.overlay)
  local baseColor = (state == "transcribing") and { red = 1, green = 0.6, blue = 0 } or { red = 1, green = 0, blue = 0 }
  local alpha = (state == "transcribing") and 0.85 or 0.90
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
  }
  log.i(table.concat(info, "\n"))
  listDevices()
  hs.alert.show("push_to_talk info logged")
end

-- ffmpeg management
local function startRecording()
  if recording then return end
  ensureDir(NOTES_DIR)

  local ts = os.date("%Y-%m-%d_%H-%M-%S")
  local base = string.format("%s/%s", NOTES_DIR, ts)
  wavPath = base .. ".wav"
  txtPath = base .. ".txt"

  local deviceSpec = ":" .. tostring(AUDIO_DEVICE_INDEX)

  -- Build ffmpeg args: audio-only, default input, 16k mono s16le WAV
  local args = {
    "-hide_banner",
    (isTestMode() and "-loglevel" or "-loglevel"), (isTestMode() and "info" or "error"),
    "-nostats",
    "-y",
    "-f", "avfoundation",
    "-i", deviceSpec,
    "-ac", "1",
    "-ar", "16000",
    "-sample_fmt", "s16",
    "-vn",
    wavPath,
  }

  if isTestMode() then
    local basePath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    local envPath = basePath .. ":" .. (os.getenv("PATH") or "")
    log.d("[TEST] Would start ffmpeg: " .. FFMPEG .. " " .. table.concat(args, " "))
    log.d("[TEST] PATH=" .. envPath)
    log.d("[TEST] Would write WAV to: " .. wavPath .. " (device " .. deviceSpec .. ")")
    return
  end

  ffStdoutBuf, ffStderrBuf = {}, {}

local function onFFExit(code, stdout, stderr)
    if isTestMode() then
      log.d(string.format("[TEST] ffmpeg exit code=%s", tostring(code)))
    end
    -- Switch to transcribing indicator
    updateIndicator("transcribing")
    recording = false

    -- Ignore micro-taps
    if heldMs < HOLD_THRESHOLD_MS then
      log.i("Hold below threshold; discarding recording")
      if wavPath and hs.fs.attributes(wavPath) then pcall(function() os.remove(wavPath) end) end
      return
    end

    -- Validate WAV exists and non-trivial size
    local attr = wavPath and hs.fs.attributes(wavPath)
    if not attr or (attr.size or 0) < 8000 then -- ~0.5s of 16kHz mono s16
      log.e("Audio not captured; wav too small: size=" .. tostring(attr and attr.size))
      hs.alert.show("Audio not captured; check mic permission/device")
      playSound("Funk")
      return
    end

    -- Concise: report duration and size
    local bytes = attr.size or 0
    local dur = math.max(0, (bytes - 44) / 32000) -- 16kHz * 2 bytes * 1 ch
    log.i(string.format("REC done: %.2fs, %d KiB", dur, math.floor(bytes/1024)))

    -- Decide model/beam and whether to preprocess based on duration
    local chosenModel = MODEL
    local chosenBeam = BEAM_SIZE
    local doPre = dur >= PREPROCESS_MIN_SEC
    -- No model switch; base.en for all durations for speed

    -- Kick off transcription
    local function startTranscribe()
      if not hs.fs.attributes(WHISPER) then
        hs.alert.show("Whisper CLI not found at ~/.local/bin/whisper")
        return
      end

local function runWhisper(audioPath)
        local fp16Arg = (WHISPER_DEVICE == "mps") and "True" or "False"
        local wargs = {
          audioPath,
          "--model", chosenModel,
          "--language", LANG,
          "--output_format", "json",
          "--output_dir", NOTES_DIR,
          "--beam_size", tostring(chosenBeam),
          "--device", WHISPER_DEVICE,
          "--fp16", fp16Arg,
          "--verbose", "False",
          "--temperature", "0",
        }
        if cfg and cfg.INITIAL_PROMPT and #cfg.INITIAL_PROMPT > 0 then
          table.insert(wargs, "--initial_prompt")
          table.insert(wargs, cfg.INITIAL_PROMPT)
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
            if ok and parsed and parsed.segments then
              if REFLOW_MODE == "gap" then
                transcript = reflowFromSegments(parsed.segments)
              end
              if (not transcript) or transcript == "" then
                transcript = tostring(parsed.text or "")
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
            hs.alert.show("No transcript produced")
            playSound("Funk")
            -- Log empty transcript event
            logEvent("no_transcript", {
              wav = wavPath,
              duration_sec = dur,
              wav_bytes = bytes,
              preprocess_used = doPre,
              audio_used = audioPath,
              tx_ms = ms,
              tx_code = wcode,
            })
            return
          end
          -- Write our reflowed transcript to the standard .txt path (use normalized base if used)
          local outTxt = baseNoExt .. ".txt"
          writeAll(outTxt, transcript)
          txtPath = outTxt

          hs.pasteboard.setContents(transcript)
          hs.timer.doAfter(0.02, function()
            hs.eventtap.keyStroke({"cmd"}, "v", 0)
          end)
          playSound("Glass")
          log.i(string.format("PASTED %d chars", #transcript))

          -- Log success event (must match pasted transcript)
          local baseNoExt = audioPath:gsub("%.wav$", "")
          local jsonPath = baseNoExt .. ".json"
          logEvent("success", {
            wav = wavPath,
            duration_sec = dur,
            wav_bytes = bytes,
            preprocess_used = doPre,
            audio_used = audioPath,
            json_path = jsonPath,
            tx_ms = ms,
            tx_code = wcode,
            transcript_chars = #transcript,
            transcript = transcript,
          })

          updateIndicator("off")
          stopBlink()
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
            log.e(string.format("TX timeout after %dms (device=%s, model=%s, beam=%d)", TIMEOUT_MS, WHISPER_DEVICE, tostring(chosenModel), tonumber(chosenBeam) or -1))
            -- Log timeout event
            logEvent("timeout", {
              wav = wavPath,
              duration_sec = dur,
              wav_bytes = bytes,
              preprocess_used = doPre,
              tx_ms = TIMEOUT_MS,
              tx_code = -1,
            })
            if whisperTask then
              local ok = pcall(function() whisperTask:sendSignal(2) end)
              if not ok then pcall(function() whisperTask:terminate() end) end
            end
            updateIndicator("off")
            stopBlink()
            playSound("Funk")
          end)
        end
        -- In normal mode, we already showed transcribing; upon completion we'll turn it off
      end

      -- Preprocess then run whisper (only for longer clips)
      if doPre then
        preprocessAudio(wavPath, function(ok, usePath)
          runWhisper(usePath or wavPath)
        end)
      else
        runWhisper(wavPath)
      end
    end

    startTranscribe()
  end

  ffTask = hs.task.new(FFMPEG, onFFExit, function(task, stdOut, stdErr)
    if stdOut and #stdOut > 0 then table.insert(ffStdoutBuf, stdOut) end
    if stdErr and #stdErr > 0 then table.insert(ffStderrBuf, stdErr) end
    return true
  end, args)


  local ok, err = pcall(function() ffTask:start() end)
  if not ok then
    hs.alert.show("Failed to start ffmpeg: " .. tostring(err))
    return
  end
  startMs = nowMs()
  heldMs = 0
  recording = true
  updateIndicator("recording")
  playSound("Pop")
  log.i("Recording started: " .. wavPath .. " via device " .. deviceSpec)
end

local function stopRecording()
  if not recording then
    if isTestMode() then log.d("[TEST] stopRecording called while not recording") end
    return
  end
  heldMs = nowMs() - startMs
  if isTestMode() then
    log.d("[TEST] Would stop ffmpeg (heldMs=" .. tostring(heldMs) .. ") and transcribe")
    updateIndicator("off")
    stopBlink()
    recording = false
    return
  end
  if ffTask then
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

-- Key handling: Press-and-hold F13 and Fn+T test toggle
local f13Hotkey
local function startTaps()
  if keyTap then keyTap:stop() end
  if flagTap then flagTap:stop() end
  if f13Hotkey then f13Hotkey:delete() end

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

    -- Fn+T: toggle GLOBAL test/live mode
    if fnHeld and code == hs.keycodes.map.t and evt:getType() == hs.eventtap.event.types.keyDown then
      setTestMode(not isTestMode())
      return true
    end

    return false
  end)
  keyTap:start()

  -- Primary: use hs.hotkey for F13 with press/release callbacks
  f13Hotkey = hs.hotkey.bind({}, "f13",
    function() -- pressed
      log.i("F13 pressed")
      if not recording then startRecording() end
    end,
    function() -- released
      log.i("F13 released")
      if recording or isTestMode() then stopRecording() end
    end
  )

  log.i("push_to_talk: F13 press-and-hold armed (testMode=" .. tostring(isTestMode()) .. ")")

  -- Initialize logger level according to current mode
  do
    setLogLevelCompat(log, isTestMode() and "debug" or "info")
  end
end

function M.start()
  startTaps()
  detectWhisperDevice()
  -- Optional: bind an info key (matches style of other modules using Cmd+Alt+Ctrl+I)
  hs.hotkey.bind({"cmd", "alt", "ctrl"}, "I", function() showInfo() end)
end

function M.stop()
  if keyTap then keyTap:stop() end
  if flagTap then flagTap:stop() end
end

return M

