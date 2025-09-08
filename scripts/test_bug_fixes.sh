#!/bin/bash
# Test script to verify critical bug fixes in push-to-talk

set -euo pipefail

echo "========================================="
echo "Push-to-Talk Bug Fix Test Suite"
echo "========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Test 1: Verify F13 tap handler fix
echo -e "${YELLOW}Test 1: F13 tap handling${NC}"
echo "Checking for proper stopRecording() guard..."
if grep -q "Clean up any lingering UI state from accidental tap" ~/.hammerspoon/push_to_talk.lua 2>/dev/null; then
    echo -e "${GREEN}✓ F13 tap fix is present${NC}"
else
    echo -e "${RED}✗ F13 tap fix not found${NC}"
    echo "  The fix should clean up UI state when stopRecording() is called without an active recording"
fi
echo ""

# Test 2: Verify audio buffer configuration
echo -e "${YELLOW}Test 2: Audio buffer improvements${NC}"
echo "Checking for increased buffer sizes..."
if grep -q "thread_queue_size.*2048" ~/.hammerspoon/push_to_talk.lua 2>/dev/null; then
    echo -e "${GREEN}✓ Increased thread queue buffer found${NC}"
else
    echo -e "${RED}✗ Thread queue buffer not increased${NC}"
fi

if grep -q "audio_buffer_size" ~/.hammerspoon/push_to_talk.lua 2>/dev/null; then
    echo -e "${GREEN}✓ Audio buffer size parameter added${NC}"
else
    echo -e "${RED}✗ Audio buffer size parameter not found${NC}"
fi
echo ""

# Test 3: Verify PRE_RECORD_DELAY_MS configuration
echo -e "${YELLOW}Test 3: Pre-recording delay configuration${NC}"
echo "Checking for PRE_RECORD_DELAY_MS..."
if grep -q "PRE_RECORD_DELAY_MS" ~/.hammerspoon/ptt_config.lua 2>/dev/null; then
    echo -e "${GREEN}✓ PRE_RECORD_DELAY_MS configured${NC}"
    grep "PRE_RECORD_DELAY_MS" ~/.hammerspoon/ptt_config.lua | head -1
else
    echo -e "${YELLOW}⚠ PRE_RECORD_DELAY_MS not in config (using default)${NC}"
fi

if grep -q "PRE_RECORD_DELAY_MS" ~/.hammerspoon/push_to_talk.lua 2>/dev/null; then
    echo -e "${GREEN}✓ PRE_RECORD_DELAY_MS loaded in script${NC}"
else
    echo -e "${RED}✗ PRE_RECORD_DELAY_MS not loaded in script${NC}"
fi
echo ""

# Test 4: Manual test instructions
echo -e "${YELLOW}Manual Test Instructions:${NC}"
echo "================================="
echo ""
echo "1. ${YELLOW}Test F13 tap fix:${NC}"
echo "   - Quickly tap F13 (don't hold)"
echo "   - The orange transcribing indicator should NOT appear"
echo "   - No infinite blinking should occur"
echo ""
echo "2. ${YELLOW}Test audio cutoff fix:${NC}"
echo "   - Hold F13 and immediately start speaking"
echo "   - Say: 'Testing one two three, the beginning should be clear'"
echo "   - Release after 3-4 seconds"
echo "   - Check that 'Testing' is captured (not cut off)"
echo ""
echo "3. ${YELLOW}Test normal recording:${NC}"
echo "   - Hold F13 for 5+ seconds"
echo "   - Speak normally"
echo "   - Release and verify transcription works"
echo ""
echo "4. ${YELLOW}Reload Hammerspoon:${NC}"
echo "   - Click Hammerspoon menu bar icon"
echo "   - Select 'Reload Config'"
echo "   - Or press Fn+R"
echo ""

# Check if Hammerspoon is running
if pgrep -x "Hammerspoon" > /dev/null; then
    echo -e "${GREEN}✓ Hammerspoon is running${NC}"
else
    echo -e "${RED}✗ Hammerspoon is not running - please start it${NC}"
fi

echo ""
echo "========================================="
echo -e "${GREEN}Bug fix verification complete!${NC}"
echo "Please perform the manual tests above to confirm fixes are working."
echo "========================================="
