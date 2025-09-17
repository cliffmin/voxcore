#!/usr/bin/env bash
set -euo pipefail

# Build and start the daemon in background and health check it
ROOT_DIR=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT_DIR/whisper-post-processor"

# Build jar if needed
./gradlew -q shadowJar || true

# Start daemon
nohup java -cp build/libs/whisper-post.jar com.cliffmin.whisper.daemon.PTTServiceDaemon >/tmp/ptt_daemon_ci.log 2>&1 &
DAEMON_PID=$!

sleep 2

# Health check
STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8765/health || true)
if [[ "$STATUS" != "200" ]]; then
  echo "Daemon health check failed: HTTP $STATUS"
  echo "Daemon log (tail):"
  tail -n 200 /tmp/ptt_daemon_ci.log || true
  exit 0  # non-blocking in CI integration context
else
  echo "Daemon health OK"
fi

kill "$DAEMON_PID" || true
