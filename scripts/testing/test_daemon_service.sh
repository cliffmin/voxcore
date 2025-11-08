#!/usr/bin/env bash
set -euo pipefail

# Test script for daemon service setup
# Validates that setup_daemon_service.sh works correctly

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
SETUP_SCRIPT="$ROOT_DIR/scripts/setup/setup_daemon_service.sh"
LABEL="com.cliffmin.voxcore.daemon"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"

echo "==> Testing VoxCore Daemon Service Setup"
echo ""

# Test 1: Check script exists and is executable
echo "Test 1: Verify setup script exists and is executable"
if [ ! -f "$SETUP_SCRIPT" ]; then
  echo "✗ FAIL: Setup script not found at $SETUP_SCRIPT"
  exit 1
fi

if [ ! -x "$SETUP_SCRIPT" ]; then
  echo "✗ FAIL: Setup script is not executable"
  exit 1
fi
echo "✓ PASS: Setup script exists and is executable"
echo ""

# Test 2: Check Java availability
echo "Test 2: Verify Java is available"
if ! command -v java >/dev/null 2>&1; then
  echo "✗ SKIP: Java not found (required for daemon)"
  exit 0
fi
echo "✓ PASS: Java found at $(command -v java)"
echo ""

# Test 3: Verify Java build exists or can be built
echo "Test 3: Verify Java daemon build"
JAR_PATH="$ROOT_DIR/whisper-post-processor/build/libs/whisper-post.jar"
if [ ! -f "$JAR_PATH" ]; then
  echo "  Building Java post-processor..."
  cd "$ROOT_DIR"
  if ! make build-java >/dev/null 2>&1; then
    echo "✗ FAIL: Could not build Java post-processor"
    exit 1
  fi
fi
echo "✓ PASS: Java daemon JAR exists"
echo ""

# Test 4: Check if daemon is already running (cleanup if needed)
echo "Test 4: Check daemon status"
DAEMON_WAS_RUNNING=0
if curl -s --max-time 0.5 http://127.0.0.1:8765/health >/dev/null 2>&1; then
  echo "  Daemon already running, will skip setup test"
  DAEMON_WAS_RUNNING=1
fi

if [ -f "$PLIST" ]; then
  echo "  LaunchAgent plist exists: $PLIST"
  echo "  To test fresh install, first remove it:"
  echo "    launchctl bootout gui/\$(id -u) $PLIST"
  echo "    rm $PLIST"
fi
echo "✓ PASS: Pre-setup state checked"
echo ""

# Test 5: Dry-run validation (check script structure)
echo "Test 5: Validate script structure"
if ! grep -q "PTT daemon" "$SETUP_SCRIPT"; then
  echo "✗ FAIL: Script doesn't contain expected content"
  exit 1
fi

if ! grep -q "launchctl bootstrap" "$SETUP_SCRIPT"; then
  echo "✗ FAIL: Script doesn't contain launchctl commands"
  exit 1
fi
echo "✓ PASS: Script structure is valid"
echo ""

# Test 6: Verify LaunchAgent plist template
echo "Test 6: Verify plist template in script"
if ! grep -q "com.cliffmin.whisper.daemon.PTTServiceDaemon" "$SETUP_SCRIPT"; then
  echo "✗ FAIL: Script doesn't contain correct Java class name"
  exit 1
fi
echo "✓ PASS: Plist template contains correct daemon class"
echo ""

echo "================================================"
echo "All tests passed!"
echo ""
if [ $DAEMON_WAS_RUNNING -eq 0 ]; then
  echo "To actually setup the daemon service, run:"
  echo "  $SETUP_SCRIPT"
else
  echo "Daemon is already running and configured."
  echo ""
  echo "Service info:"
  launchctl list | grep voxcore || echo "  (not in launchctl list)"
fi
echo ""
