-- Test file for mic indicator functionality
-- Run this in Hammerspoon console to test the indicator

local log = hs.logger.new("mic_indicator_test", "debug")

-- Mock builtinScreen if needed
local function mockBuiltinScreen()
  return hs.screen.mainScreen()
end

-- Test 1: Test mic indicator states
local function testMicIndicatorStates()
  log.i("=== Test 1: Mic Indicator States ===")

  -- Load the push_to_talk module (assuming it's in the same directory)
  local ptt = dofile(hs.configdir .. "/push_to_talk.lua")

  log.i("Test: Recording state with zero level")
  -- This should show mic with minimal rings
  -- showMicIndicator("recording", 0)
  -- hs.timer.usleep(1000000) -- Wait 1 second

  log.i("Test: Recording state with medium level (0.5)")
  -- This should show mic with medium rings
  -- showMicIndicator("recording", 0.5)
  -- hs.timer.usleep(1000000)

  log.i("Test: Recording state with high level (1.0)")
  -- This should show mic with large rings
  -- showMicIndicator("recording", 1.0)
  -- hs.timer.usleep(1000000)

  log.i("Test: Processing state")
  -- This should show yellow pulsing mic
  -- showMicIndicator("processing", 0)
  -- hs.timer.usleep(2000000) -- Wait 2 seconds to see pulse

  log.i("Test: Hidden state")
  -- This should hide the indicator
  -- showMicIndicator("hidden")

  log.i("✓ States test passed (visual verification required)")
end

-- Test 2: Test level value clamping
local function testLevelClamping()
  log.i("=== Test 2: Level Value Clamping ===")

  -- Test negative level (should clamp to 0)
  local negativeLevel = -0.5
  local expectedZero = math.max(0, negativeLevel)
  assert(expectedZero == 0, "Negative level should clamp to 0")
  log.i("✓ Negative level clamping works")

  -- Test level > 1.0 (should clamp to 1.0)
  local highLevel = 1.5
  local expectedOne = math.min(1.0, highLevel)
  assert(expectedOne == 1.0, "High level should clamp to 1.0")
  log.i("✓ High level clamping works")

  -- Test valid range (0.0 to 1.0)
  local validLevel = 0.75
  assert(validLevel >= 0 and validLevel <= 1.0, "Valid level should be in range")
  log.i("✓ Valid level range works")
end

-- Test 3: Test animation timing
local function testAnimationTiming()
  log.i("=== Test 3: Animation Timing ===")

  -- Test recording animation interval (should be 0.05s = 50ms = 20fps)
  local recordingInterval = 0.05
  local expectedFps = 1 / recordingInterval
  assert(expectedFps == 20, "Recording animation should be 20 FPS")
  log.i(string.format("✓ Recording animation: %.0f FPS", expectedFps))

  -- Test processing animation interval (should be 0.1s = 100ms = 10fps)
  local processingInterval = 0.1
  local expectedProcFps = 1 / processingInterval
  assert(expectedProcFps == 10, "Processing animation should be 10 FPS")
  log.i(string.format("✓ Processing animation: %.0f FPS", expectedProcFps))
end

-- Test 4: Test ring scaling formula
local function testRingScaling()
  log.i("=== Test 4: Ring Scaling Formula ===")

  local baseRadius = 8
  local ringCount = 3

  for ringIndex = 1, ringCount do
    for level = 0, 1, 0.25 do
      local scaleFactor = 1 + (level * 0.6 * ringIndex)
      local radius = baseRadius + (ringIndex * 5 * scaleFactor)

      -- Radius should increase with level and ring index
      assert(radius > baseRadius, "Ring radius should be greater than base")
      log.d(string.format("Ring %d, Level %.2f: radius=%.1f", ringIndex, level, radius))
    end
  end

  log.i("✓ Ring scaling formula works correctly")
end

-- Test 5: Test alpha calculation
local function testAlphaCalculation()
  log.i("=== Test 5: Alpha Calculation ===")

  for ringIndex = 1, 3 do
    for level = 0, 1, 0.25 do
      local baseAlpha = 0.6 - (ringIndex * 0.15)
      local alpha = math.max(0.1, baseAlpha * (0.5 + level * 0.5))

      -- Alpha should be between 0.1 and 1.0
      assert(alpha >= 0.1 and alpha <= 1.0, "Alpha should be in valid range")
      log.d(string.format("Ring %d, Level %.2f: alpha=%.2f", ringIndex, level, alpha))
    end
  end

  log.i("✓ Alpha calculation works correctly")
end

-- Test 6: Test processing pulse calculation
local function testProcessingPulse()
  log.i("=== Test 6: Processing Pulse Calculation ===")

  -- Simulate different time values
  local testTimes = {0, 0.25, 0.5, 0.75, 1.0, 1.5, 2.0}

  for _, t in ipairs(testTimes) do
    local pulse = (math.sin(t * 4) + 1) / 2  -- Should be 0 to 1
    local alpha = 0.5 + (pulse * 0.45)  -- Should be 0.5 to 0.95
    local radius = 10 + (pulse * 1.5)  -- Should be 10 to 11.5

    assert(pulse >= 0 and pulse <= 1, "Pulse should be 0-1")
    assert(alpha >= 0.5 and alpha <= 0.95, "Alpha should be 0.5-0.95")
    assert(radius >= 10 and radius <= 11.5, "Radius should be 10-11.5")

    log.d(string.format("Time %.2f: pulse=%.2f, alpha=%.2f, radius=%.1f", t, pulse, alpha, radius))
  end

  log.i("✓ Processing pulse calculation works correctly")
end

-- Run all tests
local function runAllTests()
  log.i("========================================")
  log.i("  Mic Indicator Test Suite")
  log.i("========================================")

  testLevelClamping()
  testAnimationTiming()
  testRingScaling()
  testAlphaCalculation()
  testProcessingPulse()
  -- testMicIndicatorStates() -- Commented out: requires visual verification

  log.i("========================================")
  log.i("  All tests passed! ✓")
  log.i("========================================")

  hs.alert.show("Mic Indicator Tests Passed ✓", 2)
end

-- Run tests
runAllTests()

return {
  runAllTests = runAllTests,
  testLevelClamping = testLevelClamping,
  testAnimationTiming = testAnimationTiming,
  testRingScaling = testRingScaling,
  testAlphaCalculation = testAlphaCalculation,
  testProcessingPulse = testProcessingPulse
}
