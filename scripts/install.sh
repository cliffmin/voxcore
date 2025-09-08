#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TS="$(date +%Y%m%d-%H%M%S)"

# Ensure target directories
mkdir -p "$HOME/.hammerspoon"

# Dependencies
if command -v brew >/dev/null 2>&1; then
  brew bundle --file="$REPO_DIR/Brewfile"
fi

# Whisper CLI via pipx
if ! command -v pipx >/dev/null 2>&1; then
  python3 -m pip install --user pipx
  python3 -m pipx ensurepath || true
fi
# Install or reinstall openai-whisper in its own environment
pipx install --include-deps openai-whisper || pipx reinstall openai-whisper

# Link module into Hammerspoon (backup existing file once with timestamp)
if [ -e "$HOME/.hammerspoon/push_to_talk.lua" ] && [ ! -L "$HOME/.hammerspoon/push_to_talk.lua" ]; then
  mv "$HOME/.hammerspoon/push_to_talk.lua" "$HOME/.hammerspoon/push_to_talk.lua.bak-$TS"
fi
ln -sf "$REPO_DIR/hammerspoon/push_to_talk.lua" "$HOME/.hammerspoon/push_to_talk.lua"

echo "Install complete. Reload Hammerspoon and press F13 to test."

