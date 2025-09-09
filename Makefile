.PHONY: help test test-audio test-e2e test-smoke install clean auto-audio metrics-graph demo-gif

# Default target
help:
	@echo "Push-to-Talk Dictation - Make Targets"
	@echo "====================================="
	@echo ""
	@echo "  make install      - Install dependencies and setup symlinks"
	@echo "  make test         - Run all tests"
	@echo "  make test-audio   - Test audio device configuration"
	@echo "  make test-e2e     - Run end-to-end tests"  
	@echo "  make test-smoke   - Run smoke tests"
	@echo "  make auto-audio   - Auto-select best audio device"
	@echo "  make clean        - Clean test artifacts"
	@echo ""

# Install dependencies and setup
install:
	@echo "Installing push-to-talk dictation..."
	@bash scripts/install.sh

# Run all tests
test: test-audio test-smoke
	@echo "All tests completed!"

# Test audio device configuration
test-audio:
	@echo "Testing audio device configuration..."
	@bash tests/test_audio_device.sh

# Run end-to-end tests
test-e2e:
	@echo "Running end-to-end tests..."
	@bash scripts/e2e_test.sh

# Run smoke tests  
test-smoke:
	@echo "Running smoke tests..."
	@bash tests/smoke_test.sh

# Auto-select best audio device
auto-audio:
	@echo "Auto-selecting audio device..."
	@bash scripts/auto_select_audio_device.sh

# Clean test artifacts
clean:
	@echo "Cleaning test artifacts..."
	@rm -f /tmp/test_recording.wav
	@rm -f /tmp/audio_test_*.wav
	@rm -f /tmp/audio_device_test.wav
	@rm -rf tests/fixtures/samples_current/tmp_compare/
	@echo "Clean complete!"

# Generate performance metrics graph (SVG) from latest tx_logs
metrics-graph:
	@mkdir -p docs/assets
	@/usr/bin/env python3 scripts/metrics/render_metrics.py || echo "(metrics script exited)"
	@echo "Wrote docs/assets/metrics.svg (if data was available)"

# Record and render a short demo GIF (10s)
demo-gif:
	@bash scripts/generate_demo_gif.sh 10 docs/assets/demo.gif
	@echo "Wrote docs/assets/demo.gif"

# Development helpers
reload:
	@echo "Reloading Hammerspoon..."
	@hs -c "hs.reload()" 2>/dev/null || echo "Hammerspoon not running"

status:
	@echo "Current Status:"
	@echo "==============="
	@echo -n "Hammerspoon: "
	@pgrep -x "Hammerspoon" > /dev/null && echo "✓ Running" || echo "✗ Not running"
	@echo -n "Module: "
	@hs -c "require('push_to_talk'); print('✓ Loaded')" 2>/dev/null || echo "✗ Not loaded"
	@echo -n "Audio device: "
	@grep "AUDIO_DEVICE_INDEX" hammerspoon/ptt_config.lua | grep -oE "[0-9]+" | head -1 | xargs -I {} echo "Device :{}"
	@echo ""
	@echo "Recent recordings:"
	@ls -lt ~/Documents/VoiceNotes/ 2>/dev/null | head -4 | tail -3 | awk '{print "  " $$9 " " $$10 " " $$11}'

# Quick device check
check-audio:
	@echo "Audio Devices:"
	@/opt/homebrew/bin/ffmpeg -f avfoundation -list_devices true -i "" 2>&1 | grep -A 10 "audio devices:" | grep "^\[" || echo "No devices found"
