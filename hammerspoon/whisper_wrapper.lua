-- hammerspoon/whisper_wrapper.lua
-- Smart whisper wrapper that auto-detects and uses the fastest available implementation

local M = {}

-- Helper to check if a command exists
local function commandExists(cmd)
  local handle = io.popen("command -v " .. cmd .. " 2>/dev/null")
  if handle then
    local result = handle:read("*a")
    handle:close()
    return result and result:gsub("%s+", "") ~= ""
  end
  return false
end

-- Helper to check if a file exists
local function fileExists(path)
  return hs.fs.attributes(path) ~= nil
end

-- Find whisper-cpp model path
local function findWhisperCppModel(modelName)
  local baseName = modelName:gsub("%.en$", "")
  local candidates = {
    "/opt/homebrew/share/whisper-cpp/ggml-" .. baseName .. ".bin",
    os.getenv("HOME") .. "/.local/share/whisper-cpp/ggml-" .. baseName .. ".bin",
    "/usr/local/share/whisper-cpp/ggml-" .. baseName .. ".bin",
  }
  
  for _, path in ipairs(candidates) do
    if fileExists(path) then
      return path
    end
  end
  
  return nil
end

-- Detect best available whisper implementation
function M.detectBestWhisper(cfg)
  local impl = cfg and cfg.WHISPER_IMPL
  
  -- If explicitly configured, use that
  if impl == "whisper-cpp" then
    if commandExists("whisper-cpp") then
      return "whisper-cpp", "/opt/homebrew/bin/whisper-cpp"
    else
      hs.alert.show("whisper-cpp not found! Install with: brew install whisper-cpp")
      return nil, nil
    end
  elseif impl == "openai-whisper" then
    local paths = {
      os.getenv("HOME") .. "/.local/bin/whisper",
      "/usr/local/bin/openai-whisper",
      "/opt/homebrew/bin/openai-whisper",
    }
    for _, path in ipairs(paths) do
      if fileExists(path) then
        return "openai-whisper", path
      end
    end
    if commandExists("openai-whisper") then
      return "openai-whisper", "openai-whisper"
    end
    hs.alert.show("openai-whisper not found! Install with: pipx install openai-whisper")
    return nil, nil
  end
  
  -- Auto-detect: prefer whisper-cpp for speed
  if commandExists("whisper-cpp") then
    -- Check if model exists
    local testModel = findWhisperCppModel(cfg and cfg.WHISPER_MODEL or "base.en")
    if testModel then
      return "whisper-cpp", "/opt/homebrew/bin/whisper-cpp"
    end
  end
  
  -- Fallback to openai-whisper
  local pyPaths = {
    os.getenv("HOME") .. "/.local/bin/whisper",
    "/usr/local/bin/openai-whisper",
  }
  for _, path in ipairs(pyPaths) do
    if fileExists(path) then
      return "openai-whisper", path
    end
  end
  
  -- No whisper found
  return nil, nil
end

-- Build whisper arguments based on implementation
function M.buildWhisperArgs(impl, cfg, audioPath, sessionDir)
  local model = cfg.WHISPER_MODEL or "base.en"
  local beam = cfg.BEAM_SIZE or 3
  local prompt = cfg.INITIAL_PROMPT or ""
  local device = cfg.WHISPER_DEVICE or "cpu"
  
  if impl == "whisper-cpp" then
    -- whisper-cpp arguments (fast C++ implementation)
    local modelPath = findWhisperCppModel(model)
    if not modelPath then
      hs.alert.show("Model " .. model .. " not found for whisper-cpp!")
      return nil
    end
    
    local args = {
      "-m", modelPath,
      "-l", "en",
      "-oj",  -- output JSON
      "-of", audioPath:gsub("%.wav$", ""),  -- output file base
      "--beam-size", tostring(beam),
      "-t", "4",  -- threads
      "-p", "1",  -- processors
    }
    
    -- Add prompt if provided
    if prompt and #prompt > 0 then
      table.insert(args, "--prompt")
      table.insert(args, prompt)
    end
    
    -- Add audio file
    table.insert(args, "-f")
    table.insert(args, audioPath)
    
    return args
    
  elseif impl == "openai-whisper" then
    -- openai-whisper arguments (Python implementation)
    local args = {
      audioPath,
      "--model", model,
      "--language", "en",
      "--output_format", "json",
      "--output_dir", sessionDir,
      "--beam_size", tostring(beam),
      "--device", device,
      "--fp16", (device == "mps") and "True" or "False",
      "--verbose", "False",
      "--temperature", "0",
      "--condition_on_previous_text", "False",
    }
    
    if prompt and #prompt > 0 then
      table.insert(args, "--initial_prompt")
      table.insert(args, prompt)
    end
    
    return args
  end
  
  return nil
end

-- Get expected transcription time (rough estimate)
function M.estimateTranscriptionTime(impl, model, durationSec)
  if impl == "whisper-cpp" then
    -- whisper-cpp is typically 5-10x faster
    if model:match("base") then
      return durationSec * 0.15  -- ~15% of audio duration
    elseif model:match("small") then
      return durationSec * 0.25
    elseif model:match("medium") then
      return durationSec * 0.4
    else
      return durationSec * 0.6
    end
  else
    -- openai-whisper (Python) is slower
    if model:match("base") then
      return durationSec * 0.8
    elseif model:match("small") then
      return durationSec * 1.2
    elseif model:match("medium") then
      return durationSec * 1.5
    else
      return durationSec * 2.0
    end
  end
end

return M
