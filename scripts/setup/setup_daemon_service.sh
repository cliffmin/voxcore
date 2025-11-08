#!/usr/bin/env bash
set -euo pipefail

# Setup PTT daemon as a LaunchAgent for automatic startup at login
# This provides audio padding and WebSocket API support

ROOT_DIR=$(cd "$(dirname "$0")/../.." && pwd)
LABEL="com.cliffmin.voxcore.daemon"
AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST="$AGENTS_DIR/${LABEL}.plist"

echo "==> Setting up VoxCore daemon service"

# Check if Java is available
if ! command -v java >/dev/null 2>&1; then
  echo "ERROR: Java not found. Please install Java 17+ first:" >&2
  echo "  brew install openjdk@17" >&2
  exit 1
fi

# Determine Java path (prefer openjdk@17 from Homebrew)
if [ -d "/opt/homebrew/opt/openjdk@17" ]; then
  JAVA_HOME="/opt/homebrew/opt/openjdk@17"
  JAVA_BIN="$JAVA_HOME/bin/java"
elif [ -d "/usr/local/opt/openjdk@17" ]; then
  JAVA_HOME="/usr/local/opt/openjdk@17"
  JAVA_BIN="$JAVA_HOME/bin/java"
else
  JAVA_BIN=$(command -v java)
fi

echo "Using Java: $JAVA_BIN"

# Build Java daemon if not already built
JAR_PATH="$ROOT_DIR/whisper-post-processor/build/libs/whisper-post.jar"
if [ ! -f "$JAR_PATH" ]; then
  echo "Building Java post-processor..."
  cd "$ROOT_DIR"
  make build-java || {
    echo "ERROR: Failed to build Java post-processor" >&2
    exit 1
  }
fi

# Check if daemon is already running
if curl -s --max-time 0.5 http://127.0.0.1:8765/health >/dev/null 2>&1; then
  echo "⚠️  PTT daemon is already running"
  echo ""
  echo "To restart the service:"
  echo "  launchctl bootout gui/$(id -u) $PLIST"
  echo "  launchctl bootstrap gui/$(id -u) $PLIST"
  exit 0
fi

# Create LaunchAgents directory if it doesn't exist
mkdir -p "$AGENTS_DIR"

# Create the plist file
echo "Creating LaunchAgent at: $PLIST"
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  
  <key>ProgramArguments</key>
  <array>
    <string>${JAVA_BIN}</string>
    <string>-cp</string>
    <string>${JAR_PATH}</string>
    <string>com.cliffmin.whisper.daemon.PTTServiceDaemon</string>
  </array>
  
  <key>RunAtLoad</key>
  <true/>
  
  <key>KeepAlive</key>
  <true/>
  
  <key>StandardOutPath</key>
  <string>${HOME}/Library/Logs/voxcore-daemon.out.log</string>
  
  <key>StandardErrorPath</key>
  <string>${HOME}/Library/Logs/voxcore-daemon.err.log</string>
  
  <key>WorkingDirectory</key>
  <string>${ROOT_DIR}</string>
  
  <key>EnvironmentVariables</key>
  <dict>
    <key>JAVA_HOME</key>
    <string>${JAVA_HOME:-/usr}</string>
  </dict>
</dict>
</plist>
PLIST

# Unload if already loaded (ignore errors)
echo "Unloading any existing service..."
/bin/launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true

# Load the LaunchAgent
echo "Loading LaunchAgent..."
/bin/launchctl bootstrap "gui/$(id -u)" "$PLIST"
/bin/launchctl enable "gui/$(id -u)/${LABEL}" || true

# Wait for daemon to start
echo "Waiting for daemon to start..."
for i in {1..15}; do
  if curl -s --max-time 0.5 http://127.0.0.1:8765/health >/dev/null 2>&1; then
    echo ""
    echo "✓ VoxCore daemon started successfully!"
    echo ""
    echo "Service Details:"
    echo "  Label:      ${LABEL}"
    echo "  Endpoint:   http://127.0.0.1:8765"
    echo "  Health:     http://127.0.0.1:8765/health"
    echo "  Logs:"
    echo "    stdout:   ~/Library/Logs/voxcore-daemon.out.log"
    echo "    stderr:   ~/Library/Logs/voxcore-daemon.err.log"
    echo ""
    echo "Management Commands:"
    echo "  Stop:       launchctl bootout gui/\$(id -u) $PLIST"
    echo "  Start:      launchctl bootstrap gui/\$(id -u) $PLIST"
    echo "  Status:     launchctl list | grep voxcore"
    echo ""
    echo "The daemon will now start automatically at login."
    exit 0
  fi
  sleep 0.5
done

echo ""
echo "⚠️  Daemon did not start within expected time"
echo "Check logs for errors:"
echo "  tail -50 ~/Library/Logs/voxcore-daemon.err.log"
exit 1
