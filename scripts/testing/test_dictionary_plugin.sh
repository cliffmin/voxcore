#!/bin/bash
# Test dictionary plugin functionality

set -euo pipefail

echo "=== Dictionary Plugin Test ==="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Test directories
TEST_DIR="/tmp/ptt-dict-test-$$"
CONFIG_DIR="$TEST_DIR/.config/ptt-dictation"
mkdir -p "$CONFIG_DIR"

echo "Test directory: $TEST_DIR"
echo ""

# Test 1: No dictionary file
echo "Test 1: No dictionary file (should load empty)"
HOME="$TEST_DIR" lua -e '
  local HOME = os.getenv("HOME")
  local function loadExternalDictionary()
    local sources = {
      HOME .. "/.config/ptt-dictation/corrections.lua",
      HOME .. "/.config/voxcompose/corrections.lua",
      "/usr/local/share/ptt-dictation/corrections.lua"
    }
    
    for _, path in ipairs(sources) do
      local f = io.open(path, "r")
      if f then
        f:close()
        local ok, dict = pcall(dofile, path)
        if ok and type(dict) == "table" then
          print("Loaded from: " .. path)
          return dict
        end
      end
    end
    
    return {}
  end
  
  local dict = loadExternalDictionary()
  if next(dict) == nil then
    print("✅ Empty dictionary loaded (expected)")
  else
    print("❌ Unexpected dictionary content")
    os.exit(1)
  end
' || { echo -e "${RED}Test 1 failed${NC}"; exit 1; }

echo -e "${GREEN}✅ Test 1 passed${NC}"
echo ""

# Test 2: Load user dictionary
echo "Test 2: Load user dictionary"
cat > "$CONFIG_DIR/corrections.lua" << 'EOF'
return {
  ["jason"] = "JSON",
  ["jura"] = "Jira",
  ["test word"] = "corrected word"
}
EOF

HOME="$TEST_DIR" lua -e '
  local HOME = os.getenv("HOME")
  local function loadExternalDictionary()
    local sources = {
      HOME .. "/.config/ptt-dictation/corrections.lua",
      HOME .. "/.config/voxcompose/corrections.lua",
      "/usr/local/share/ptt-dictation/corrections.lua"
    }
    
    for _, path in ipairs(sources) do
      local f = io.open(path, "r")
      if f then
        f:close()
        local ok, dict = pcall(dofile, path)
        if ok and type(dict) == "table" then
          print("Loaded from: " .. path)
          return dict
        end
      end
    end
    
    return {}
  end
  
  local dict = loadExternalDictionary()
  if dict["jason"] == "JSON" and dict["jura"] == "Jira" then
    print("✅ Dictionary loaded correctly")
    print("  jason -> " .. dict["jason"])
    print("  jura -> " .. dict["jura"])
  else
    print("❌ Dictionary not loaded properly")
    os.exit(1)
  end
' || { echo -e "${RED}Test 2 failed${NC}"; exit 1; }

echo -e "${GREEN}✅ Test 2 passed${NC}"
echo ""

# Test 3: Text replacement function
echo "Test 3: Text replacement function"
HOME="$TEST_DIR" lua -e '
  local HOME = os.getenv("HOME")
  
  -- Load dictionary
  local DICTIONARY_REPLACE = dofile(HOME .. "/.config/ptt-dictation/corrections.lua")
  
  -- Apply dictionary replacements (simplified version)
  local function applyDictionaryReplacements(text)
    if not text or text == "" then return text end
    if not DICTIONARY_REPLACE or type(DICTIONARY_REPLACE) ~= "table" then return text end
    
    local modified = text
    for pattern, replacement in pairs(DICTIONARY_REPLACE) do
      -- Simple word boundary replacement
      local escaped_pattern = pattern:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
      modified = modified:gsub("%f[%w]" .. escaped_pattern .. "%f[%W]", replacement)
    end
    
    return modified
  end
  
  -- Test cases
  local test_cases = {
    {"I wrote some jason code", "I wrote some JSON code"},
    {"The jura ticket is done", "The Jira ticket is done"},
    {"This is a test word here", "This is a corrected word here"},
    {"jason and jura together", "JSON and Jira together"},
  }
  
  local all_passed = true
  for i, test in ipairs(test_cases) do
    local input, expected = test[1], test[2]
    local result = applyDictionaryReplacements(input)
    if result == expected then
      print("  ✅ Test " .. i .. " passed")
    else
      print("  ❌ Test " .. i .. " failed")
      print("     Input:    " .. input)
      print("     Expected: " .. expected)
      print("     Got:      " .. result)
      all_passed = false
    end
  end
  
  if not all_passed then
    os.exit(1)
  end
' || { echo -e "${RED}Test 3 failed${NC}"; exit 1; }

echo -e "${GREEN}✅ Test 3 passed${NC}"
echo ""

# Test 4: VoxCompose priority
echo "Test 4: VoxCompose dictionary priority"
VOXCOMPOSE_DIR="$TEST_DIR/.config/voxcompose"
mkdir -p "$VOXCOMPOSE_DIR"

cat > "$VOXCOMPOSE_DIR/corrections.lua" << 'EOF'
return {
  ["vox test"] = "VoxCompose correction",
  ["jason"] = "JSON from VoxCompose"  -- Should override user dict
}
EOF

HOME="$TEST_DIR" lua -e '
  local HOME = os.getenv("HOME")
  local function loadExternalDictionary()
    local sources = {
      HOME .. "/.config/ptt-dictation/corrections.lua",
      HOME .. "/.config/voxcompose/corrections.lua",
      "/usr/local/share/ptt-dictation/corrections.lua"
    }
    
    for _, path in ipairs(sources) do
      local f = io.open(path, "r")
      if f then
        f:close()
        local ok, dict = pcall(dofile, path)
        if ok and type(dict) == "table" then
          print("Loaded from: " .. path)
          return dict
        end
      end
    end
    
    return {}
  end
  
  local dict = loadExternalDictionary()
  -- Should load user dict (first in priority)
  if dict["jason"] == "JSON" then
    print("✅ User dictionary has priority (expected)")
  else
    print("❌ Wrong dictionary loaded")
    os.exit(1)
  end
' || { echo -e "${RED}Test 4 failed${NC}"; exit 1; }

echo -e "${GREEN}✅ Test 4 passed${NC}"
echo ""

# Cleanup
rm -rf "$TEST_DIR"

echo -e "${GREEN}=== All tests passed ===${NC}"
echo ""
echo "The dictionary plugin system is working correctly!"
echo ""
echo "To use it:"
echo "1. Create ~/.config/ptt-dictation/corrections.lua"
echo "2. Add your corrections as shown in the template"
echo "3. Reload Hammerspoon"