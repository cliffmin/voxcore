.PHONY: help test test-audio test-e2e test-smoke test-java test-java-integration install clean auto-audio metrics-graph demo-gif build-java dev dev-install

# Default target
help:
	@echo "VoxCore - Make Targets"
	@echo "====================================="
	@echo ""
	@echo "Development:"
	@echo "  make dev-install  - Build & install locally (restart daemon)"
	@echo "  make dev          - Alias for dev-install"
	@echo "  make build-java   - Build Java post-processor only"
	@echo "  make reload       - Reload Hammerspoon config"
	@echo "  make status       - Show current status"
	@echo "  make transcribe /path/to/audio.wav  - Transcribe file and print output"
	@echo ""
	@echo "Testing:"
	@echo "  make test         - Run all tests"
	@echo "  make test-java    - Run Java unit tests"
	@echo "  make test-audio   - Test audio device configuration"
	@echo "  make test-smoke   - Run smoke tests"
	@echo ""
	@echo "Setup:"
	@echo "  make install      - Install dependencies and setup symlinks"
	@echo "  make auto-audio   - Auto-select best audio device"
	@echo "  make version      - Show project version"
	@echo "  make clean        - Clean test artifacts"
	@echo ""
	@echo "Version Management:"
	@echo "  make organize-recordings      - Organize recordings by version"
	@echo "  make compare-versions         - Compare performance across versions"
	@echo ""

# Install dependencies and setup
install:
	@echo "Installing VoxCore..."
	@bash scripts/install.sh

# Run all tests
test: test-smoke test-java-all
	@echo "All tests completed!"

# Test audio device configuration
test-audio:
	@echo "Testing audio device configuration..."
	@bash scripts/testing/debug_recording.sh

# Run smoke tests (daemon health check)
test-smoke:
	@echo "Running smoke tests..."
	@bash scripts/testing/daemon_health.sh

# Build Java post-processor
build-java:
	@echo "Building Java post-processor..."
	@cd whisper-post-processor && gradle clean shadowJar buildExecutable --no-daemon -q
	@echo "Java processor built successfully!"

# Run Java unit tests
test-java: build-java
	@echo "Running Java unit tests..."
	@cd whisper-post-processor && gradle test --no-daemon

# Run Java integration tests (E2E)
test-java-integration: build-java
	@echo "Running Java E2E integration tests..."
	@cd whisper-post-processor && gradle integrationTest --no-daemon

# Run all Java tests
test-java-all: build-java
	@echo "Running all Java tests (unit + integration)..."
	@cd whisper-post-processor && gradle testAll --no-daemon

# Auto-select best audio device
auto-audio:
	@echo "Auto-selecting audio device..."
	@bash scripts/setup/auto_select_audio_device.sh

# Clean test artifacts
clean:
	@echo "Cleaning test artifacts..."
	@rm -f /tmp/test_recording.wav
	@rm -f /tmp/audio_test_*.wav
	@rm -f /tmp/audio_device_test.wav
	@rm -rf tests/fixtures/samples_current/tmp_compare/
	@echo "Clean complete!"

# Diagnostics: collect latest logs + summary
.PHONY: diag
diag:
	@bash scripts/diagnostics/collect_latest.sh

# Version information (git + Java CLI)
.PHONY: version
version:
	@echo "Git describe: $$(git describe --tags --match 'v[0-9]*' --always 2>/dev/null || echo 'no-tags')"
	@echo -n "Java CLI (whisper-post) version: "
	@if [ -f whisper-post-processor/dist/whisper-post.jar ]; then \
	  java -jar whisper-post-processor/dist/whisper-post.jar --version 2>/dev/null || echo "unavailable"; \
	else \
	  v=$$(/usr/bin/awk -F\' "/^version\s*=\s*\'/ {print \$$2; exit}" whisper-post-processor/build.gradle 2>/dev/null); \
	  if [ -n "$$v" ]; then echo "$$v (from build.gradle)"; else echo "unavailable"; fi; \
	fi

# Generate performance metrics graph (SVG) from latest tx_logs
metrics-graph:
	@mkdir -p docs/assets
	@/usr/bin/env python3 scripts/metrics/render_metrics.py || echo "(metrics script exited)"
	@echo "Wrote docs/assets/metrics.svg (if data was available)"

# Record and render a short demo GIF (10s)
demo-gif:
	@bash scripts/generate_demo_gif.sh 10 docs/assets/demo.gif
	@echo "Wrote docs/assets/demo.gif"

# Sweep threshold between models on golden fixtures
.PHONY: sweep-threshold
sweep-threshold:
	@/usr/bin/env python3 scripts/metrics/sweep_threshold.py --golden tests/fixtures/golden --models base.en medium.en --start 6 --end 40 --step 2 | tee tests/results/threshold_sweep_$$(/bin/date +%Y%m%d_%H%M).json

# Version management and recording organization
.PHONY: organize-recordings compare-versions
organize-recordings:
	@echo "Organizing recordings by version..."
	@bash scripts/utilities/organize_by_version.sh

organize-recordings-dry-run:
	@echo "Preview: Organizing recordings by version (dry-run)..."
	@bash scripts/utilities/organize_by_version.sh --dry-run

compare-versions:
	@echo "Comparing performance across versions..."
	@python3 scripts/analysis/compare_versions.py

# Development helpers

# Local dev install: build, restart daemon, reload Hammerspoon
dev-install:
	@echo "=== Local Dev Install ==="
	@echo "1. Building JAR..."
	@cd whisper-post-processor && ./gradlew shadowJar --no-daemon -q
	@echo "2. Stopping daemon..."
	@pkill -f "PTTServiceDaemon" 2>/dev/null || true
	@sleep 0.5
	@echo "3. Reloading Hammerspoon (will auto-start daemon)..."
	@hs -c "hs.reload()" 2>/dev/null || echo "Hammerspoon not running"
	@sleep 1
	@echo "4. Checking daemon health..."
	@curl -s http://127.0.0.1:8765/health | grep -q '"status":"ok"' && echo "✓ Daemon running" || echo "✗ Daemon not responding (will start on first use)"
	@echo ""
	@echo "Done! Test with a recording."

# Alias for dev-install
dev: dev-install

reload:
	@echo "Reloading Hammerspoon..."
	@hs -c "hs.reload()" 2>/dev/null || echo "Hammerspoon not running"

status:
	@echo "Current Status:"
	@echo "==============="

# Transcribe an audio file and print the output
# Usage: make transcribe [/path/to/audio.wav]  (defaults to latest recording)
transcribe:
	@bash scripts/utilities/transcribe_and_paste.sh $(if $(filter-out $@,$(MAKECMDGOALS)),"$(filter-out $@,$(MAKECMDGOALS))",) --no-paste

# Allow any argument to be passed without error
%:
	@:

# Quick device check
check-audio:
	@echo "Audio Devices:"
	@/opt/homebrew/bin/ffmpeg -f avfoundation -list_devices true -i "" 2>&1 | grep -A 10 "audio devices:" | grep "^\[" || echo "No devices found"
