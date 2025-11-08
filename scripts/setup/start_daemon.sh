#!/usr/bin/env bash
set -euo pipefail

# Start the PTT Java daemon for audio padding and processing
ROOT_DIR=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT_DIR/whisper-post-processor"

# Check if Java build exists
if [ ! -f "build/libs/whisper-post.jar" ]; then
  echo "Building Java processor first..."
  ./gradlew -q shadowJar || {
    echo "Failed to build Java processor. Run 'make build-java' first."
    exit 1
  }
fi

# Check if daemon is already running
if curl -s http://127.0.0.1:8765/health >/dev/null 2>&1; then
  echo "PTT daemon is already running"
  exit 0
fi

# Start daemon in background
echo "Starting PTT daemon..."
nohup java -cp build/libs/whisper-post.jar com.cliffmin.whisper.daemon.PTTServiceDaemon >/tmp/ptt_daemon.log 2>&1 &
DAEMON_PID=$!

# Wait for daemon to be ready
echo "Waiting for daemon to start..."
for i in {1..10}; do
  if curl -s http://127.0.0.1:8765/health >/dev/null 2>&1; then
    echo "✓ PTT daemon started successfully (PID: $DAEMON_PID)"
    echo "  Listening on: http://127.0.0.1:8765"
    echo "  Log file: /tmp/ptt_daemon.log"
    exit 0
  fi
  sleep 0.5
done

echo "Failed to start daemon. Check /tmp/ptt_daemon.log for errors"
tail -20 /tmp/ptt_daemon.log 2>/dev/null
exit 1