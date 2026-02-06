#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

echo "==> VoxCore Install"

# ---- Dependencies (Homebrew) ----
if command -v brew >/dev/null 2>&1; then
  echo "Checking Homebrew dependencies..."
  for pkg in ffmpeg whisper-cpp openjdk@17; do
    if ! brew list --formula "$pkg" &>/dev/null; then
      echo "  Installing $pkg..."
      brew install "$pkg"
    fi
  done
  if ! brew list --cask hammerspoon &>/dev/null; then
    echo "  Installing Hammerspoon..."
    brew install --cask hammerspoon
  fi
else
  echo "WARNING: Homebrew not found. Install manually: ffmpeg, whisper-cpp, openjdk@17, Hammerspoon"
fi

# ---- Build Java post-processor ----
if [ -f "$REPO_DIR/whisper-post-processor/gradlew" ]; then
  echo "Building Java post-processor..."
  cd "$REPO_DIR/whisper-post-processor" && ./gradlew --no-daemon -q shadowJar
  echo "  Built whisper-post.jar"
fi

# ---- Hammerspoon integration ----
mkdir -p "$HOME/.hammerspoon"

# Symlink Lua files
for lua_file in push_to_talk_v2.lua whisper_wrapper.lua; do
  if [ -f "$REPO_DIR/hammerspoon/$lua_file" ]; then
    ln -sf "$REPO_DIR/hammerspoon/$lua_file" "$HOME/.hammerspoon/$lua_file"
    echo "  Linked $lua_file"
  fi
done

# Remove old v1 symlink if present
rm -f "$HOME/.hammerspoon/push_to_talk.lua"

# Create config if it doesn't exist
if [ ! -f "$HOME/.hammerspoon/ptt_config.lua" ]; then
  if [ -f "$REPO_DIR/hammerspoon/ptt_config.lua.sample" ]; then
    cp "$REPO_DIR/hammerspoon/ptt_config.lua.sample" "$HOME/.hammerspoon/ptt_config.lua"
    echo "  Created config: ~/.hammerspoon/ptt_config.lua"
  fi
else
  echo "  Config exists: ~/.hammerspoon/ptt_config.lua (not overwritten)"
fi

echo ""
echo "Done! Next steps:"
echo "  1. Reload Hammerspoon (menu -> Reload Config, or Cmd+Opt+Ctrl+R)"
echo "  2. Grant Microphone + Accessibility permissions to Hammerspoon"
echo "  3. Test: Hold Cmd+Alt+Ctrl+Space to record, release to transcribe"
echo ""
echo "Optional: Install VoxCompose for ML-powered refinement"
echo "  brew install voxcompose"
