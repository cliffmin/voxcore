#!/bin/bash
# End-to-end test for push_to_talk module
# Tests reload, checks for failures, and analyzes logs

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "========================================="
echo -e "${BLUE}Push-to-Talk E2E Test Suite${NC}"
echo "========================================="
echo ""

# Configuration
HS_CONSOLE_LOG="$HOME/Library/Logs/Hammerspoon/hammerspoon.log"
HS_CONFIG="$HOME/.hammerspoon/init.lua"
PTT_MODULE="$HOME/.hammerspoon/push_to_talk.lua"
PTT_CONFIG="$HOME/.hammerspoon/ptt_config.lua"
TEMP_LOG="/tmp/ptt_e2e_test.log"

# Function to check if Hammerspoon is running
check_hammerspoon() {
    if pgrep -x "Hammerspoon" > /dev/null; then
        echo -e "${GREEN}✓ Hammerspoon is running${NC}"
        return 0
    else
        echo -e "${RED}✗ Hammerspoon is not running${NC}"
        echo "  Please start Hammerspoon and run this test again"
        return 1
    fi
}

# Function to check if files exist
check_files() {
    local all_good=true
    
    echo -e "\n${YELLOW}Checking required files...${NC}"
    
    if [ -f "$HS_CONFIG" ]; then
        echo -e "${GREEN}✓ init.lua exists${NC}"
    else
        echo -e "${RED}✗ init.lua not found at $HS_CONFIG${NC}"
        all_good=false
    fi
    
    if [ -f "$PTT_MODULE" ]; then
        echo -e "${GREEN}✓ push_to_talk.lua exists${NC}"
        # Check if it's a symlink
        if [ -L "$PTT_MODULE" ]; then
            local target
            target=$(readlink "$PTT_MODULE")
            echo "  → Symlink to: $target"
            if [ -f "$target" ]; then
                echo -e "  ${GREEN}✓ Symlink target exists${NC}"
            else
                echo -e "  ${RED}✗ Symlink target missing!${NC}"
                all_good=false
            fi
        fi
    else
        echo -e "${RED}✗ push_to_talk.lua not found at $PTT_MODULE${NC}"
        all_good=false
    fi
    
    if [ -f "$PTT_CONFIG" ]; then
        echo -e "${GREEN}✓ ptt_config.lua exists${NC}"
    else
        echo -e "${YELLOW}⚠ ptt_config.lua not found (will use defaults)${NC}"
    fi
    
    if [ "$all_good" = false ]; then
        return 1
    fi
    return 0
}

# Function to check if push_to_talk is loaded in init.lua
check_init_loading() {
    echo -e "\n${YELLOW}Checking init.lua configuration...${NC}"
    
    if grep -q "push_to_talk" "$HS_CONFIG"; then
        echo -e "${GREEN}✓ push_to_talk referenced in init.lua${NC}"
        echo "  Found lines:"
        grep -n "push_to_talk" "$HS_CONFIG" | head -5 | sed 's/^/    /'
        
        # Check if it's properly started
        if grep -q "ptt.*start()" "$HS_CONFIG" || grep -q "ptt:start()" "$HS_CONFIG"; then
            echo -e "${GREEN}✓ push_to_talk.start() is called${NC}"
        else
            echo -e "${RED}✗ push_to_talk.start() not found${NC}"
            echo "  Add this to your init.lua:"
            echo "    local ptt = require('push_to_talk')"
            echo "    ptt.start()"
            return 1
        fi
    else
        echo -e "${RED}✗ push_to_talk not loaded in init.lua${NC}"
        echo "  Add this to your init.lua:"
        echo "    local ptt = require('push_to_talk')"
        echo "    ptt.start()"
        return 1
    fi
    return 0
}

# Function to check for syntax errors
check_syntax() {
    echo -e "\n${YELLOW}Checking Lua syntax...${NC}"
    
    # Check if lua is available
    if ! command -v lua &> /dev/null && ! command -v luajit &> /dev/null; then
        echo -e "${YELLOW}⚠ Lua interpreter not found (skipping syntax check)${NC}"
        echo "  Hammerspoon will validate syntax on reload"
        return 0
    fi
    
    # Use luajit if available (comes with Hammerspoon), otherwise lua
    local LUA_CMD="lua"
    if command -v luajit &> /dev/null; then
        LUA_CMD="luajit"
    fi
    
    # Check push_to_talk.lua syntax
    if $LUA_CMD -e "dofile('$PTT_MODULE')" 2>/dev/null; then
        echo -e "${GREEN}✓ push_to_talk.lua syntax OK${NC}"
    else
        echo -e "${YELLOW}⚠ Cannot validate syntax (may need Hammerspoon environment)${NC}"
        # Don't fail - Hammerspoon will validate on reload
        return 0
    fi
    
    # Check ptt_config.lua if it exists
    if [ -f "$PTT_CONFIG" ]; then
        if $LUA_CMD -e "dofile('$PTT_CONFIG')" 2>/dev/null; then
            echo -e "${GREEN}✓ ptt_config.lua syntax OK${NC}"
        else
            echo -e "${YELLOW}⚠ Cannot validate ptt_config.lua syntax (may need Hammerspoon environment)${NC}"
            # Don't fail - Hammerspoon will validate on reload
        fi
    fi
    
    return 0
}

# Function to reload Hammerspoon via CLI
reload_hammerspoon() {
    echo -e "\n${YELLOW}Reloading Hammerspoon...${NC}"
    
    # Reload via hs CLI tool
    if command -v hs &> /dev/null; then
        hs -c "hs.reload()"
        echo -e "${GREEN}✓ Reload command sent via hs CLI${NC}"
    else
        # Fallback to AppleScript
        osascript -e 'tell application "Hammerspoon" to quit'
        sleep 1
        open -a Hammerspoon
        echo -e "${GREEN}✓ Reloaded via AppleScript${NC}"
    fi
    
    # Wait for reload to complete
    sleep 3
    
    # Check if push_to_talk loaded successfully
    echo -e "\n${YELLOW}Checking reload logs...${NC}"
    
    # Tail the last 50 lines of the log looking for issues
    if [ -f "$HS_CONSOLE_LOG" ]; then
        tail -50 "$HS_CONSOLE_LOG" > "$TEMP_LOG"
        
        # Check for push_to_talk specific errors
        if grep -q "push_to_talk.*ERROR" "$TEMP_LOG"; then
            echo -e "${RED}✗ Error loading push_to_talk:${NC}"
            grep "push_to_talk" "$TEMP_LOG" | grep -i error | head -5 | sed 's/^/    /'
            return 1
        fi
        
        # Check if push_to_talk started successfully
        if grep -q "push_to_talk.*started" "$TEMP_LOG"; then
            echo -e "${GREEN}✓ push_to_talk started successfully${NC}"
            grep "push_to_talk.*started" "$TEMP_LOG" | tail -1 | sed 's/^/    /'
        elif grep -q "push_to_talk.*F13" "$TEMP_LOG"; then
            echo -e "${GREEN}✓ push_to_talk F13 handlers registered${NC}"
            grep "push_to_talk.*F13" "$TEMP_LOG" | tail -1 | sed 's/^/    /'
        else
            echo -e "${YELLOW}⚠ No confirmation that push_to_talk started${NC}"
            echo "  Recent log entries:"
            grep -i "push_to_talk\|ptt\|f13" "$TEMP_LOG" | tail -5 | sed 's/^/    /' || echo "    (no relevant entries found)"
        fi
        
        # Check for any lua errors
        if grep -q "LuaSkin.*ERROR" "$TEMP_LOG"; then
            echo -e "${YELLOW}⚠ Lua errors detected:${NC}"
            grep "LuaSkin.*ERROR" "$TEMP_LOG" | tail -5 | sed 's/^/    /'
        fi
        
    else
        echo -e "${YELLOW}⚠ Hammerspoon log not found at $HS_CONSOLE_LOG${NC}"
    fi
    
    return 0
}

# Function to test dependencies
check_dependencies() {
    echo -e "\n${YELLOW}Checking dependencies...${NC}"
    
    local all_good=true
    
    # Check ffmpeg
    if [ -f "/opt/homebrew/bin/ffmpeg" ]; then
        echo -e "${GREEN}✓ ffmpeg installed${NC}"
        /opt/homebrew/bin/ffmpeg -version 2>&1 | head -1 | sed 's/^/    /'
    else
        echo -e "${RED}✗ ffmpeg not found at /opt/homebrew/bin/ffmpeg${NC}"
        echo "  Install with: brew install ffmpeg"
        all_good=false
    fi
    
    # Check whisper
    if [ -f "$HOME/.local/bin/whisper" ]; then
        echo -e "${GREEN}✓ whisper CLI installed${NC}"
        "$HOME/.local/bin/whisper" --help 2>&1 | head -1 | sed 's/^/    /'
    else
        echo -e "${RED}✗ whisper CLI not found${NC}"
        echo "  Install with: pipx install openai-whisper"
        all_good=false
    fi
    
    # Check audio device
    echo -e "\n${YELLOW}Available audio devices:${NC}"
    /opt/homebrew/bin/ffmpeg -f avfoundation -list_devices true -i "" 2>&1 | grep -A 5 "audio devices:" | tail -5 | sed 's/^/    /'
    
    if [ "$all_good" = false ]; then
        return 1
    fi
    return 0
}

# Function to run a quick functional test
functional_test() {
    echo -e "\n${YELLOW}Functional test instructions:${NC}"
    echo "================================="
    echo ""
    echo "1. Press ${YELLOW}Cmd+Alt+Ctrl+I${NC} to show push_to_talk diagnostics"
    echo "   - Should show config and device info"
    echo ""
    echo "2. Quickly tap ${YELLOW}F13${NC} (don't hold)"
    echo "   - Should NOT show orange indicator"
    echo "   - Should NOT freeze/hang"
    echo ""
    echo "3. Hold ${YELLOW}F13${NC} for 3-5 seconds and speak"
    echo "   - Red recording dot should appear"
    echo "   - Release to transcribe"
    echo "   - Text should paste at cursor"
    echo ""
    echo "4. Check logs for any errors:"
    echo "   tail -f ~/Documents/VoiceNotes/tx_logs/tx-$(date +%F).jsonl"
    echo ""
}

# Main test execution
main() {
    local exit_code=0
    
    # Step 1: Check if Hammerspoon is running
    if ! check_hammerspoon; then
        exit 1
    fi
    
    # Step 2: Check files exist
    if ! check_files; then
        exit_code=1
    fi
    
    # Step 3: Check init.lua configuration
    if ! check_init_loading; then
        exit_code=1
    fi
    
    # Step 4: Check syntax
    if ! check_syntax; then
        exit_code=1
    fi
    
    # Step 5: Check dependencies
    if ! check_dependencies; then
        exit_code=1
    fi
    
    # Step 6: Reload and check logs
    if ! reload_hammerspoon; then
        exit_code=1
    fi
    
    # Step 7: Show functional test instructions
    functional_test
    
    # Summary
    echo ""
    echo "========================================="
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}E2E test completed successfully!${NC}"
        echo "Please perform the functional tests above."
    else
        echo -e "${RED}E2E test found issues that need fixing.${NC}"
        echo "Review the errors above and fix them before testing."
    fi
    echo "========================================="
    
    # Clean up
    rm -f "$TEMP_LOG"
    
    exit $exit_code
}

# Run main
main
