#!/usr/bin/env bash
# Test Hammerspoon push_to_talk_v2.lua integration

set -euo pipefail

echo "=== Hammerspoon Integration Test ==="
echo ""

# Check if Hammerspoon is running
if ! pgrep -q Hammerspoon; then
  echo "❌ Hammerspoon is not running"
  echo "   Start Hammerspoon and try again"
  exit 1
fi
echo "✅ Hammerspoon is running"

# Check if push_to_talk.lua is linked
if [ -L "$HOME/.hammerspoon/push_to_talk.lua" ]; then
  TARGET=$(readlink "$HOME/.hammerspoon/push_to_talk.lua")
  echo "✅ push_to_talk.lua is linked to: $TARGET"

  if [[ "$TARGET" == *"push_to_talk_v2.lua"* ]]; then
    echo "✅ Using v2 (CLI wrapper)"
  else
    echo "⚠️  Using old version (not v2)"
  fi
else
  echo "⚠️  push_to_talk.lua is not a symlink"
fi

# Check if voxcore CLI exists
if command -v voxcore >/dev/null 2>&1; then
  VOXCORE_PATH=$(which voxcore)
  echo "✅ voxcore CLI found at: $VOXCORE_PATH"

  # Test voxcore CLI
  voxcore --version 2>&1 | head -1 || echo "   (version command not available)"
else
  echo "❌ voxcore CLI not found in PATH"
  echo "   Install with: brew install voxcore"
  echo "   Or build from source: cd whisper-post-processor && ./gradlew voxcoreJar"
fi

# Check vocabulary file
VOCAB_FILE="$HOME/.config/voxcompose/vocabulary.txt"
if [ -f "$VOCAB_FILE" ]; then
  VOCAB_SIZE=$(wc -c < "$VOCAB_FILE")
  echo "✅ Vocabulary file exists: $VOCAB_FILE ($VOCAB_SIZE bytes)"

  if [ "$VOCAB_SIZE" -eq 0 ]; then
    echo "   ⚠️  Vocabulary file is empty"
    echo "   Export from VoxCompose: ./gradlew run --args='--export-vocabulary'"
  fi
else
  echo "⚠️  Vocabulary file not found: $VOCAB_FILE"
  echo "   Export from VoxCompose: ./gradlew run --args='--export-vocabulary'"
fi

# Check Hammerspoon console for errors
echo ""
echo "=== Manual Test Instructions ==="
echo ""
echo "1. Open a text editor (e.g., TextEdit, VS Code)"
echo "2. Press Hyper+Space (Cmd+Alt+Ctrl+Space)"
echo "3. Speak: 'Testing VoxCore CLI integration'"
echo "4. Release Hyper+Space"
echo "5. Verify text appears in the editor"
echo ""
echo "Expected behavior:"
echo "  - Red pulsing circle appears (recording)"
echo "  - Changes to orange (processing)"
echo "  - Text pastes into editor"
echo "  - 'Tink' sound plays"
echo ""
echo "Check Hammerspoon console for errors:"
echo "  Open Hammerspoon → Console (or Cmd+Shift+C)"
echo ""
echo "=== Hammerspoon Console Logs ==="
echo ""

# Try to get recent Hammerspoon logs
if [ -f "$HOME/Library/Logs/Hammerspoon/console.log" ]; then
  echo "Recent Hammerspoon logs:"
  tail -20 "$HOME/Library/Logs/Hammerspoon/console.log" | grep -i "voxcore\|push_to_talk\|error" || echo "(no recent voxcore-related logs)"
else
  echo "(Hammerspoon console log not found)"
fi

echo ""
echo "✅ Pre-flight checks complete"
echo "   Ready for manual testing!"
