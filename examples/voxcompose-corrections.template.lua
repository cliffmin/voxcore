-- VoxCompose Dictionary Integration Template
-- This file demonstrates how to load corrections from VoxCompose's learned dictionary
-- Copy to ~/.config/voxcompose/corrections.lua for automatic integration

local json = require("json") -- Assumes a JSON library is available
local HOME = os.getenv("HOME") or ""

-- Load VoxCompose's learned corrections JSON file
local function loadVoxComposeCorrections()
  local path = HOME .. "/.config/voxcompose/learned_corrections.json"
  local file = io.open(path, "r")
  if not file then
    return {}
  end
  
  local content = file:read("*all")
  file:close()
  
  local ok, data = pcall(json.decode, content)
  if not ok or not data or not data.corrections then
    return {}
  end
  
  -- Convert VoxCompose format to simple Lua table
  local corrections = {}
  for misheard, correction in pairs(data.corrections) do
    -- Only include high-confidence corrections
    if correction.confidence and correction.confidence > 0.8 then
      corrections[misheard] = correction.to
    end
  end
  
  return corrections
end

-- Merge with any static corrections you want to always apply
local staticCorrections = {
  -- Add any corrections that should always be applied
  -- regardless of what VoxCompose has learned
}

-- Load and merge corrections
local voxCorrections = loadVoxComposeCorrections()
local merged = {}

-- Add static corrections first
for k, v in pairs(staticCorrections) do
  merged[k] = v
end

-- Add VoxCompose corrections (may override static ones)
for k, v in pairs(voxCorrections) do
  merged[k] = v
end

return merged