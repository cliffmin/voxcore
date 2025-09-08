#!/bin/bash

# Smoke tests that MUST pass before any commit
# These would have caught our F13 issues

set -euo pipefail

echo "=== Push-to-Talk Smoke Tests ==="
echo ""

ERRORS=0

# Test 1: Lua syntax check
echo -n "1. Checking Lua syntax... "
if luac -p hammerspoon/push_to_talk.lua 2>/dev/null; then
    echo "✓ PASS"
else
    echo "✗ FAIL - Syntax error in push_to_talk.lua"
    luac -p hammerspoon/push_to_talk.lua 2>&1
    ((ERRORS++))
fi

# Test 2: Check function order (repoRoot must be defined before use)
echo -n "2. Checking function order... "
REPO_DEF_LINE=$(grep -n "^local function repoRoot" hammerspoon/push_to_talk.lua | cut -d: -f1)
REPO_USE_LINE=$(grep -n "repoRoot()" hammerspoon/push_to_talk.lua | head -1 | cut -d: -f1)
if [ "$REPO_DEF_LINE" -lt "$REPO_USE_LINE" ]; then
    echo "✓ PASS (repoRoot defined at line $REPO_DEF_LINE, used at line $REPO_USE_LINE)"
else
    echo "✗ FAIL - repoRoot used before definition"
    ((ERRORS++))
fi

# Test 3: Check for duplicate F13 bindings
echo -n "3. Checking for F13 conflicts... "
F13_COUNT=$(grep -c 'hotkey.bind.*"f13"' hammerspoon/push_to_talk.lua || echo "0")
if [ "$F13_COUNT" -eq "2" ]; then
    echo "✓ PASS (F13 and Shift+F13 bindings found)"
elif [ "$F13_COUNT" -gt "2" ]; then
    echo "✗ FAIL - Too many F13 bindings ($F13_COUNT found)"
    ((ERRORS++))
else
    echo "⚠ WARNING - Unexpected F13 binding count: $F13_COUNT"
fi

# Test 4: Check critical functions exist
echo -n "4. Checking required functions... "
REQUIRED_FUNCS=("M.start" "M.stop" "startRecording" "stopRecording" "validateAudioDevice")
MISSING=""
for func in "${REQUIRED_FUNCS[@]}"; do
    if ! grep -q "function $func\|$func = function" hammerspoon/push_to_talk.lua; then
        MISSING="$MISSING $func"
    fi
done
if [ -z "$MISSING" ]; then
    echo "✓ PASS"
else
    echo "✗ FAIL - Missing functions:$MISSING"
    ((ERRORS++))
fi

# Test 5: Check audio device validation
echo -n "5. Checking audio device setup... "
if grep -q "AUDIO_DEVICE_INDEX.*=.*1" hammerspoon/ptt_config.lua; then
    echo "✓ PASS (MacBook Pro Microphone configured)"
else
    echo "⚠ WARNING - Audio device may not be configured correctly"
fi

# Test 6: Check for debug code left in
echo -n "6. Checking for debug artifacts... "
DEBUG_COUNT=$(grep -c "TEMPORARILY\|TEST\|TODO\|FIXME\|XXX" hammerspoon/push_to_talk.lua || echo "0")
if [ "$DEBUG_COUNT" -eq "0" ]; then
    echo "✓ PASS"
else
    echo "⚠ WARNING - $DEBUG_COUNT debug comments found"
fi

# Test 7: Check module returns table
echo -n "7. Checking module structure... "
if grep -q "^return M" hammerspoon/push_to_talk.lua; then
    echo "✓ PASS"
else
    echo "✗ FAIL - Module doesn't return M table"
    ((ERRORS++))
fi

# Test 8: Check for common Lua errors
echo -n "8. Checking for common issues... "
ISSUES=""
if grep -q "dlog\." hammerspoon/push_to_talk.lua && ! grep -q "^local dlog" hammerspoon/push_to_talk.lua; then
    ISSUES="$ISSUES undefined-dlog"
fi
if grep -q "test_f13" ~/.hammerspoon/init.lua 2>/dev/null; then
    ISSUES="$ISSUES test-code-in-init"
fi
if [ -z "$ISSUES" ]; then
    echo "✓ PASS"
else
    echo "⚠ WARNING - Issues found: $ISSUES"
fi

echo ""
echo "=== Test Summary ==="
if [ "$ERRORS" -eq "0" ]; then
    echo "✅ All critical tests passed!"
    echo ""
    echo "Ready to commit."
else
    echo "❌ $ERRORS critical test(s) failed!"
    echo ""
    echo "Fix these issues before committing."
    exit 1
fi

echo ""
echo "Optional: Run full integration test with:"
echo "  1. Reload Hammerspoon (Fn+R)"
echo "  2. Press F13 to test recording"
echo "  3. Check ~/Documents/VoiceNotes for output"
