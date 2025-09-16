#!/usr/bin/env hs
-- Query refiner capabilities to determine activation rules
-- This allows plugins like VoxCompose to dictate their own thresholds

local json = require("hs.json")

-- Query refiner for its capabilities
local function queryRefinerCapabilities(refinerCmd)
  if not refinerCmd or #refinerCmd == 0 then
    return nil
  end
  
  -- Build command with --capabilities flag
  local args = {}
  for i = 2, #refinerCmd do
    table.insert(args, refinerCmd[i])
  end
  table.insert(args, "--capabilities")
  
  -- Execute and capture output
  local task = hs.task.new(refinerCmd[1], nil, args)
  task:start()
  task:waitUntilExit()
  
  local stdout = task:standardOutput()
  if not stdout or stdout == "" then
    -- Fallback to defaults if refiner doesn't support capabilities
    return nil
  end
  
  -- Parse JSON response
  local ok, capabilities = pcall(json.decode, stdout)
  if not ok then
    return nil
  end
  
  return capabilities
end

-- Update config based on refiner capabilities
local function applyRefinerCapabilities(cfg)
  local refinerCfg = cfg.LLM_REFINER or {}
  
  if not refinerCfg.ENABLED then
    return cfg
  end
  
  -- Query capabilities
  local capabilities = queryRefinerCapabilities(refinerCfg.CMD)
  
  if capabilities then
    -- Apply duration thresholds from refiner
    if capabilities.activation and capabilities.activation.long_form then
      local threshold = capabilities.activation.long_form.min_duration
      if threshold and type(threshold) == "number" then
        -- Override MODEL_BY_DURATION threshold with refiner's preference
        if cfg.MODEL_BY_DURATION then
          cfg.MODEL_BY_DURATION.SHORT_SEC = threshold
          print(string.format("Refiner requests %ds threshold for long-form", threshold))
        end
      end
    end
    
    -- Apply model preferences
    if capabilities.preferences and capabilities.preferences.whisper_model then
      local model = capabilities.preferences.whisper_model
      cfg.WHISPER_MODEL = model
      print(string.format("Refiner prefers Whisper model: %s", model))
    end
    
    -- Store capabilities for reference
    cfg.REFINER_CAPABILITIES = capabilities
  end
  
  return cfg
end

return {
  queryRefinerCapabilities = queryRefinerCapabilities,
  applyRefinerCapabilities = applyRefinerCapabilities
}