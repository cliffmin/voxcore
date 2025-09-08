#!/usr/bin/env zsh
set -Eeuo pipefail
IFS=$'\n\t'

# Ensure Ollama runs on login. Prefer brew services; fallback to LaunchAgent.

CMD="ollama"
OLLAMA_PATH="$(command -v ollama || true)"
if [[ -z "$OLLAMA_PATH" ]]; then
  echo "ERR: 'ollama' not found in PATH. Install it first (e.g., brew install ollama or from https://ollama.com)." >&2
  exit 2
fi

# Try brew services if available
if command -v brew >/dev/null 2>&1; then
  if brew services info ollama >/dev/null 2>&1; then
    echo "==> Starting ollama via brew services"
    brew services start ollama || true
  fi
fi

# If port not reachable, install LaunchAgent for current user
if ! curl -sS --max-time 0.6 http://127.0.0.1:11434/api/tags >/dev/null; then
  echo "==> Configuring LaunchAgent for Ollama"
  AGENTS="$HOME/Library/LaunchAgents"
  mkdir -p "$AGENTS"
  LABEL="dev.cliffmin.ollama.serve"
  PLIST="$AGENTS/${LABEL}.plist"
  cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${OLLAMA_PATH}</string>
    <string>serve</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>${HOME}/Library/Logs/ollama.out.log</string>
  <key>StandardErrorPath</key><string>${HOME}/Library/Logs/ollama.err.log</string>
</dict>
</plist>
PL
  # unload if already loaded, then load
  /bin/launchctl bootout "gui/$(id -u)" "$PLIST" >/dev/null 2>&1 || true
  /bin/launchctl bootstrap "gui/$(id -u)" "$PLIST"
  /bin/launchctl enable "gui/$(id -u)/${LABEL}" || true
fi

# Verify
if curl -sS --max-time 1 http://127.0.0.1:11434/api/tags >/dev/null; then
  echo "OK: Ollama is reachable at http://127.0.0.1:11434"
  exit 0
else
  echo "WARN: Ollama not reachable yet; check logs in ~/Library/Logs/ollama.*.log" >&2
  exit 1
fi
