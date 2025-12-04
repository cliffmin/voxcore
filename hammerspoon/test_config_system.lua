-- Functional tests for config system (Phase 1.2 Step 1)
-- Run in Hammerspoon console: dofile(hs.configdir .. "/test_config_system.lua")

local log = hs.logger.new("test_config_system", "info")

-- Test results
local passed = 0
local failed = 0

local function assert_true(condition, msg)
  if condition then
    passed = passed + 1
    log.i("✓ " .. msg)
  else
    failed = failed + 1
    log.e("✗ " .. msg)
  end
end

local function assert_equal(actual, expected, msg)
  if actual == expected then
    passed = passed + 1
    log.i("✓ " .. msg)
  else
    failed = failed + 1
    log.e(string.format("✗ %s - Expected: '%s', Got: '%s'", msg, expected, actual))
  end
end

-- Import the functions from push_to_talk.lua
-- We need to extract and test them standalone
local HOME = os.getenv("HOME") or ""
local USER = os.getenv("USER") or ""

-- Path expansion utility (copied from push_to_talk.lua)
local function expandPath(path)
  if not path or path == "" then return path end

  -- Expand ~ to user home directory
  local HOME = os.getenv("HOME") or ""
  path = path:gsub("^~", HOME)

  -- Expand environment variables ($VAR or ${VAR})
  path = path:gsub("%$(%w+)", function(var)
    return os.getenv(var) or ("$" .. var)
  end)
  path = path:gsub("%${([^}]+)}", function(var)
    return os.getenv(var) or ("${" .. var .. "}")
  end)

  return path
end

-- Validate and create directory if needed (simplified for testing)
local function ensureDirectory(path, name)
  if not path or path == "" then
    return false
  end

  local expanded = expandPath(path)

  -- Check if directory exists
  local attrs = hs.fs.attributes(expanded)
  if not attrs then
    -- Try to create it
    local ok, err = hs.execute(string.format("mkdir -p %q", expanded))
    if not ok then
      return false
    end
    attrs = hs.fs.attributes(expanded)
  end

  if attrs and attrs.mode == "directory" then
    -- Test writability
    local testFile = expanded .. "/.voxcore_write_test"
    local f = io.open(testFile, "w")
    if f then
      f:write("test")
      f:close()
      os.remove(testFile)
      return expanded
    else
      return false
    end
  else
    return false
  end
end

-- Test 1: Tilde expansion
local function test_tilde_expansion()
  log.i("=== Test 1: Tilde Expansion ===")

  local result = expandPath("~/Documents/VoiceNotes")
  local expected = HOME .. "/Documents/VoiceNotes"
  assert_equal(result, expected, "Tilde expansion: ~/Documents/VoiceNotes")

  result = expandPath("~/test")
  expected = HOME .. "/test"
  assert_equal(result, expected, "Tilde expansion: ~/test")

  result = expandPath("~/.config/voxcore")
  expected = HOME .. "/.config/voxcore"
  assert_equal(result, expected, "Tilde expansion: ~/.config/voxcore")
end

-- Test 2: Environment variable expansion
local function test_env_var_expansion()
  log.i("=== Test 2: Environment Variable Expansion ===")

  local result = expandPath("$HOME/Documents")
  local expected = HOME .. "/Documents"
  assert_equal(result, expected, "Env var expansion: $HOME/Documents")

  result = expandPath("${HOME}/Documents")
  expected = HOME .. "/Documents"
  assert_equal(result, expected, "Env var expansion: ${HOME}/Documents")

  result = expandPath("/Users/$USER/Documents")
  expected = "/Users/" .. USER .. "/Documents"
  assert_equal(result, expected, "Env var expansion: /Users/$USER/Documents")

  -- Test unknown variable (should remain unchanged)
  result = expandPath("$UNKNOWN_VAR/test")
  expected = "$UNKNOWN_VAR/test"
  assert_equal(result, expected, "Unknown env var remains unchanged")
end

-- Test 3: Mixed expansion
local function test_mixed_expansion()
  log.i("=== Test 3: Mixed Expansion ===")

  local result = expandPath("~/Documents/$USER")
  local expected = HOME .. "/Documents/" .. USER
  assert_equal(result, expected, "Mixed expansion: ~/Documents/$USER")

  result = expandPath("~/${USER}/test")
  expected = HOME .. "/" .. USER .. "/test"
  assert_equal(result, expected, "Mixed expansion: ~/${USER}/test")
end

-- Test 4: Absolute paths (no expansion needed)
local function test_absolute_paths()
  log.i("=== Test 4: Absolute Paths ===")

  local result = expandPath("/Users/test/Documents")
  local expected = "/Users/test/Documents"
  assert_equal(result, expected, "Absolute path unchanged")

  result = expandPath("/tmp/test")
  expected = "/tmp/test"
  assert_equal(result, expected, "Absolute path unchanged: /tmp/test")
end

-- Test 5: Edge cases
local function test_edge_cases()
  log.i("=== Test 5: Edge Cases ===")

  local result = expandPath("")
  assert_equal(result, "", "Empty string returns empty")

  result = expandPath(nil)
  assert_equal(result, nil, "nil returns nil")
end

-- Test 6: Directory creation and validation
local function test_directory_operations()
  log.i("=== Test 6: Directory Creation & Validation ===")

  -- Create a test directory in /tmp
  local testDir = "/tmp/voxcore_test_" .. os.time()

  -- Directory shouldn't exist yet
  local attrs = hs.fs.attributes(testDir)
  assert_true(attrs == nil, "Test directory doesn't exist initially")

  -- ensureDirectory should create it
  local result = ensureDirectory(testDir, "TEST_DIR")
  assert_true(result == testDir, "ensureDirectory creates and returns path")

  -- Verify it exists now
  attrs = hs.fs.attributes(testDir)
  assert_true(attrs ~= nil and attrs.mode == "directory", "Directory was created")

  -- Verify it's writable
  local testFile = testDir .. "/test.txt"
  local f = io.open(testFile, "w")
  assert_true(f ~= nil, "Directory is writable")
  if f then
    f:write("test")
    f:close()
  end

  -- Clean up
  os.remove(testFile)
  hs.execute("rmdir " .. testDir)

  log.i("Test cleanup: removed " .. testDir)
end

-- Test 7: Directory validation with tilde expansion
local function test_directory_with_expansion()
  log.i("=== Test 7: Directory with Tilde Expansion ===")

  -- Test with existing directory (should already exist)
  local result = ensureDirectory("~/Documents", "HOME_DOCUMENTS")
  local expected = HOME .. "/Documents"
  assert_true(result == expected, "Tilde expansion works in ensureDirectory")

  -- Test with env var expansion
  result = ensureDirectory("$HOME/Documents", "HOME_DOCUMENTS_VAR")
  assert_true(result == expected, "Env var expansion works in ensureDirectory")
end

-- Test 8: Invalid paths
local function test_invalid_paths()
  log.i("=== Test 8: Invalid Paths ===")

  local result = ensureDirectory("", "EMPTY")
  assert_true(result == false, "Empty path returns false")

  result = ensureDirectory(nil, "NIL")
  assert_true(result == false, "nil path returns false")

  -- Test path that can't be created (no permissions)
  result = ensureDirectory("/root/voxcore_test_noperm", "NO_PERM")
  assert_true(result == false, "Path without permissions returns false")
end

-- Run all tests
local function runTests()
  log.i("========================================")
  log.i("  Config System Functional Tests")
  log.i("  (Phase 1.2 Step 1)")
  log.i("========================================")

  test_tilde_expansion()
  test_env_var_expansion()
  test_mixed_expansion()
  test_absolute_paths()
  test_edge_cases()
  test_directory_operations()
  test_directory_with_expansion()
  test_invalid_paths()

  log.i("========================================")
  log.i(string.format("  Results: %d passed, %d failed", passed, failed))
  log.i("========================================")

  if failed == 0 then
    hs.alert.show("✓ All config tests passed", 2)
    return true
  else
    hs.alert.show(string.format("✗ %d config tests failed", failed), 3)
    return false
  end
end

-- Run tests
return runTests()
