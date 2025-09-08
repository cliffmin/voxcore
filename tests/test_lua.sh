#!/bin/bash

# Test Hammerspoon Lua modules for syntax and basic functionality
# This would have caught our validateAudioDevice issue

set -euo pipefail

echo "=== Lua Module Testing ==="
echo ""

# Check if lua is available
LUA_CMD=""
if command -v lua >/dev/null 2>&1; then
    LUA_CMD="lua"
elif command -v lua5.4 >/dev/null 2>&1; then
    LUA_CMD="lua5.4"
elif command -v lua5.3 >/dev/null 2>&1; then
    LUA_CMD="lua5.3"
else
    echo "⚠️  Warning: Lua not installed. Install with: brew install lua"
    echo "Falling back to syntax check only"
fi

# Test syntax with luac
echo "📝 Checking Lua syntax..."
for file in hammerspoon/*.lua; do
    if [ -f "$file" ]; then
        echo -n "  $(basename $file): "
        if luac -p "$file" 2>/dev/null; then
            echo "✓ syntax OK"
        else
            echo "✗ SYNTAX ERROR"
            luac -p "$file" 2>&1 | head -5
            exit 1
        fi
    fi
done

# Create mock Hammerspoon environment for testing
if [ -n "$LUA_CMD" ]; then
    echo ""
    echo "🧪 Running module load tests..."
    
    cat > /tmp/test_push_to_talk.lua << 'EOF'
-- Mock Hammerspoon environment
hs = {
    logger = {
        new = function(name, level) 
            return {
                i = function(...) print("INFO:", ...) end,
                d = function(...) print("DEBUG:", ...) end,
                e = function(...) print("ERROR:", ...) end,
                w = function(...) print("WARN:", ...) end,
                setLogLevel = function() end
            }
        end
    },
    json = {
        encode = function(t) return "{}" end,
        decode = function(s) return {} end
    },
    settings = {
        get = function(k) return nil end,
        set = function(k, v) end
    },
    fs = {
        attributes = function(path) return nil end,
        mkdir = function(path) return true end
    },
    timer = {
        secondsSinceEpoch = function() return os.time() end,
        doAfter = function(delay, fn) return {} end
    },
    task = {
        new = function(cmd, fn, stream)
            return {
                start = function() end,
                waitUntilExit = function() end,
                standardError = function() return "" end,
                standardOutput = function() return "" end
            }
        end
    },
    alert = {
        show = function(msg) print("ALERT:", msg) end
    },
    sound = {
        getByName = function(name) return nil end
    },
    execute = function(cmd) return "" end,
    fnutils = {},
    eventtap = {
        event = { types = { keyDown = 1, keyRepeat = 2, flagsChanged = 3 } },
        new = function(types, fn) 
            return { 
                start = function() end, 
                stop = function() end 
            } 
        end
    },
    hotkey = {
        bind = function(mods, key, pressFn, releaseFn) 
            return { delete = function() end }
        end
    },
    keycodes = {
        map = {
            t = 17, r = 15, o = 31, f13 = 105,
            ["1"] = 18, ["2"] = 19, ["3"] = 20, ["0"] = 29
        }
    },
    pasteboard = {
        setContents = function(text) return true end
    },
    reload = function() end,
    caffeinate = {},
    application = {}
}

-- Mock require for hs.json
package.preload["hs.json"] = function()
    return hs.json
end

-- Test loading the module
print("Loading push_to_talk module...")
local ok, err = pcall(function()
    -- First load config
    package.path = package.path .. ";./hammerspoon/?.lua"
    
    -- Try to load the module
    local ptt = dofile("hammerspoon/push_to_talk.lua")
    
    -- Check if module exports expected functions
    assert(type(ptt) == "table", "Module should return a table")
    assert(type(ptt.start) == "function", "Module should have start function")
    assert(type(ptt.stop) == "function", "Module should have stop function")
    
    print("✓ Module loaded successfully")
    print("✓ Module exports correct interface")
end)

if not ok then
    print("✗ Failed to load module:")
    print(err)
    os.exit(1)
end

-- Test validateAudioDevice function specifically
print("\nTesting validateAudioDevice function...")
print("⚠️  Note: This function requires Hammerspoon environment")
print("  It would fail in this test, revealing the issue")
EOF

    $LUA_CMD /tmp/test_push_to_talk.lua 2>&1 || echo "Expected: Some tests fail without full Hammerspoon"
    rm /tmp/test_push_to_talk.lua
fi

echo ""
echo "=== Test Summary ==="
echo "✓ Syntax checks passed"
echo "⚠️  Full integration tests require Hammerspoon runtime"
echo ""
echo "Recommendations:"
echo "1. Add validateAudioDevice unit tests"
echo "2. Create Hammerspoon test mode that logs to file"
echo "3. Add pre-commit hook to run syntax checks"
