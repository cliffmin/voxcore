# Troubleshooting

Common issues and solutions for VoxCore.

## Installation Issues

### Hammerspoon Not Starting

**Symptoms:** Hammerspoon doesn't launch or shows errors.

**Solutions:**
1. **Check Accessibility Permissions:**
   - System Preferences → Security & Privacy → Privacy → Accessibility
   - Ensure Hammerspoon is checked
   - Restart Hammerspoon: `killall Hammerspoon && open -a Hammerspoon`

2. **Check Console for Errors:**
   - Open Console.app
   - Filter for "Hammerspoon"
   - Look for Lua errors or permission issues

3. **Verify Installation:**
   ```bash
   # Check if Hammerspoon is installed
   ls -la ~/.hammerspoon/
   
   # Check if config exists
   ls -la ~/.hammerspoon/ptt_config.lua
   ```

### Whisper Model Not Found

**Symptoms:** Transcription fails with "failed to open 'base.en'" or "model not found".

**Solutions:**
1. **Install whisper-cpp:**
   ```bash
   brew install whisper-cpp
   ```

2. **Download Model Files:**
   ```bash
   # Download base.en model (required)
   ./scripts/setup/download_whisper_models.sh base
   
   # Optional: Download medium.en for longer recordings
   ./scripts/setup/download_whisper_models.sh medium
   ```

3. **Verify Installation:**
   ```bash
   # Check binary
   which whisper-cli
   # Should show: /opt/homebrew/bin/whisper-cli
   
   # Check model file
   ls -lh /opt/homebrew/share/whisper-cpp/ggml-base.bin
   # Should show the model file (~150 MB)
   ```

4. **Manual Download (if script fails):**
   ```bash
   mkdir -p /opt/homebrew/share/whisper-cpp
   cd /opt/homebrew/share/whisper-cpp
   curl -L -o ggml-base.bin https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin
   ```

See [Whisper Models Setup](whisper-models.md) for complete instructions.

### Java Post-Processor Not Found

**Symptoms:** Transcription works but post-processing fails.

**Solutions:**
1. **Build Java Component:**
   ```bash
   cd /path/to/voxcore
   make build-java
   ```

2. **Verify JAR Exists:**
   ```bash
   ls whisper-post-processor/dist/whisper-post.jar
   ```

3. **Check Java Version:**
   ```bash
   java -version
   # Should show Java 17 or higher
   ```

## Audio Issues

### Wrong Microphone Selected

**Symptoms:** Recording from wrong device (e.g., iPhone Continuity mic instead of Mac mic).

**Solutions:**
1. **Check Device Name:**
   VoxCore resolves the mic by name (default: `"MacBook Pro Microphone"`). List available devices:
   ```bash
   /opt/homebrew/bin/ffmpeg -f avfoundation -list_devices true -i '' 2>&1 | grep "audio devices" -A 20
   ```

2. **Update Config:**
   Edit `~/.hammerspoon/ptt_config.lua` and set the device name:
   ```lua
   AUDIO_DEVICE_NAME = "MacBook Pro Microphone"  -- or your device name
   ```
   Reload Hammerspoon: Menu -> Reload Config (or Cmd+Opt+Ctrl+R)

3. **Fallback to Index:**
   If name matching doesn't work, set an explicit index:
   ```lua
   AUDIO_DEVICE_INDEX = 1
   ```

### No Audio Captured

**Symptoms:** Recording creates empty or silent WAV files.

**Solutions:**
1. **Check Microphone Permissions:**
   - System Preferences → Security & Privacy → Privacy → Microphone
   - Ensure Hammerspoon (or Terminal if using CLI) has microphone access
   - Restart Hammerspoon after granting permissions

2. **Test Audio Device:**
   ```bash
   make test-audio
   # This records a 2-second test clip
   ```

3. **Verify Device Index:**
   - Check `AUDIO_DEVICE_INDEX` in `~/.hammerspoon/ptt_config.lua`
   - Ensure it matches a valid input device (not output)

## Performance Issues

### Slow Transcription

**Symptoms:** Transcription takes >2 seconds for short clips.

**Solutions:**
1. **First Use is Slower:**
   - First transcription loads models (~500-800ms overhead)
   - Subsequent transcriptions are fast (<1 second)
   - This is normal and expected

2. **Check System Resources:**
   - Open Activity Monitor
   - Look for high CPU usage from other apps
   - Close unnecessary applications

3. **Verify Model Selection:**
   - Short clips (<21s) should use `base.en` (faster)
   - Long clips (≥21s) use `medium.en` (slower but more accurate)
   - Check logs to see which model was used

4. **See Performance Guide:**
   - Check [Performance Documentation](../performance.md) for benchmarks

## Configuration Issues

### Config File Not Found

**Symptoms:** VoxCore uses defaults instead of your config.

**Solutions:**
1. **Check Config Location:**
   - Primary: `~/.hammerspoon/ptt_config.lua`
   - Fallback: `~/.config/voxcore/ptt_config.lua`

2. **Verify Config Syntax:**
   ```bash
   # Test Lua syntax
   lua -l ~/.hammerspoon/ptt_config.lua
   ```

3. **Reinstall Config:**
   ```bash
   ./scripts/setup/install.sh
   # This creates a fresh config file
   ```

### Hotkeys Not Working

**Symptoms:** Pressing hotkey does nothing.

**Solutions:**
1. **Check Hammerspoon is Running:**
   - Look for Hammerspoon icon in menu bar
   - If missing, launch: `open -a Hammerspoon`

2. **Check Hotkey Conflicts:**
   - System Preferences → Keyboard → Shortcuts
   - Look for conflicts with your VoxCore hotkeys
   - Change VoxCore hotkeys in config if needed

3. **Verify Config Loaded:**
   - Hammerspoon menu → Console
   - Look for errors when loading `ptt_config.lua`
   - Reload config: Menu → Reload Config

## Getting Help

### Check Logs

**Transaction Logs:**
```bash
# View today's logs
tail -f ~/Documents/VoiceNotes/tx_logs/tx-$(date +%F).jsonl

# Search for errors
grep -i error ~/Documents/VoiceNotes/tx_logs/tx-*.jsonl
```

**Hammerspoon Console:**
- Open Hammerspoon
- Menu → Console
- Look for Lua errors or warnings

### Run Diagnostics

**Quick Status Check:**
```bash
make status
# Shows version, components, and health
```

**Full Diagnostics:**
- Press `Cmd+Alt+Ctrl+D` (or your configured DIAGNOSTICS key)
- Shows system info, config, and component status

### Get Support

1. **Check Documentation:**
   - [Configuration Guide](configuration.md)
   - [Usage Guide](../usage/README.md)
   - [Performance Guide](../performance.md)

2. **Search Issues:**
   - https://github.com/cliffmin/voxcore/issues
   - Search for similar problems

3. **Ask for Help:**
   - Open a GitHub issue: https://github.com/cliffmin/voxcore/issues/new
   - Include:
     - Your macOS version
     - VoxCore version (`make version`)
     - Error messages from logs
     - Steps to reproduce

4. **Community:**
   - GitHub Discussions: https://github.com/cliffmin/voxcore/discussions
   - Ask questions, share tips, get help

---

**Still stuck?** Open an issue with:
- Your macOS version
- VoxCore version (`make version`)
- Full error message
- Steps to reproduce
