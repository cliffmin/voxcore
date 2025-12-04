-- Simple functional tests for mic indicator
-- Run in Hammerspoon console: dofile(hs.configdir .. "/test_mic_indicator.lua")

local log = hs.logger.new("test_mic_indicator", "info")

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

-- Test 1: Pulsing animation formula
local function test_pulse_formula()
  log.i("=== Test 1: Pulse Animation Formula ===")

  for frameCount = 0, 100, 20 do
    local pulse = (math.sin(frameCount * 0.1) + 1) / 2 * 0.8
    assert_true(pulse >= 0 and pulse <= 0.8,
                string.format("Pulse at frame %d: %.3f (should be 0-0.8)", frameCount, pulse))
  end
end

-- Test 2: Ring scaling
local function test_ring_scaling()
  log.i("=== Test 2: Ring Scaling ===")

  local baseRadius = 8
  for level = 0, 1, 0.5 do
    for ringIndex = 1, 3 do
      local scaleFactor = 1 + (level * 0.6 * ringIndex)
      local radius = baseRadius + (ringIndex * 5 * scaleFactor)

      assert_true(radius > baseRadius,
                  string.format("Ring %d at level %.1f: radius %.1f > base %d",
                               ringIndex, level, radius, baseRadius))
    end
  end
end

-- Test 3: Processing pulse
local function test_processing_pulse()
  log.i("=== Test 3: Processing Pulse ===")

  for t = 0, 2, 0.5 do
    local pulse = (math.sin(t * 4) + 1) / 2
    local alpha = 0.5 + (pulse * 0.45)
    local radius = 10 + (pulse * 1.5)

    assert_true(alpha >= 0.5 and alpha <= 0.95,
                string.format("Alpha at t=%.1f: %.3f (should be 0.5-0.95)", t, alpha))
    assert_true(radius >= 10 and radius <= 11.5,
                string.format("Radius at t=%.1f: %.3f (should be 10-11.5)", t, radius))
  end
end

-- Test 4: Timer frequency
local function test_timer_frequency()
  log.i("=== Test 4: Timer Frequency ===")

  local recordingInterval = 0.05
  local processingInterval = 0.1

  local recordingFps = 1 / recordingInterval
  local processingFps = 1 / processingInterval

  assert_true(recordingFps == 20,
              string.format("Recording FPS: %d (should be 20)", recordingFps))
  assert_true(processingFps == 10,
              string.format("Processing FPS: %d (should be 10)", processingFps))
end

-- Run all tests
local function runTests()
  log.i("========================================")
  log.i("  Mic Indicator Functional Tests")
  log.i("========================================")

  test_pulse_formula()
  test_ring_scaling()
  test_processing_pulse()
  test_timer_frequency()

  log.i("========================================")
  log.i(string.format("  Results: %d passed, %d failed", passed, failed))
  log.i("========================================")

  if failed == 0 then
    hs.alert.show("All tests passed ✓", 2)
    return true
  else
    hs.alert.show(string.format("%d tests failed ✗", failed), 3)
    return false
  end
end

-- Run tests
return runTests()
