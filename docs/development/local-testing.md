# Local Development Testing

How to test changes locally before creating a PR.

## Quick Start

```bash
# Build, restart daemon, reload Hammerspoon - all in one
make dev-install   # or just: make dev
```

Then test with a voice recording.

## What `make dev-install` Does

1. **Builds JAR** - `gradle shadowJar` in whisper-post-processor/
2. **Stops daemon** - Kills running PTTServiceDaemon process
3. **Reloads Hammerspoon** - Which auto-starts daemon on first use
4. **Health check** - Verifies daemon is responding

## Why Restart the Daemon?

The PTTServiceDaemon is a **long-running Java process** that loads the JAR at startup. It keeps the JVM warm to avoid cold-start delays (which used to cause missed first words).

When you build a new JAR, the old daemon is still running the old code. You must restart it to pick up changes.

## Manual Steps (if needed)

```bash
# 1. Build the JAR
cd whisper-post-processor
gradle shadowJar

# 2. Kill existing daemon
pkill -f "PTTServiceDaemon"

# 3. Reload Hammerspoon (starts daemon on first recording)
hs -c "hs.reload()"

# 4. Verify daemon is running
curl http://127.0.0.1:8765/health
# Should return: {"status":"ok"}
```

## Testing Workflow

1. Make code changes
2. Run `make dev-install` (or `make dev`)
3. Do a test recording (press your PTT key, speak, release)
4. Check the output
5. If issues, check logs:
   ```bash
   # Daemon logs
   tail -f /tmp/ptt_daemon.log
   
   # Hammerspoon console
   # Open Hammerspoon > Console
   ```

## Debugging Tips

### Daemon not starting?
```bash
# Check if port is in use
lsof -i :8765

# Start daemon manually to see errors
cd whisper-post-processor
java -cp build/libs/whisper-post.jar com.cliffmin.whisper.daemon.PTTServiceDaemon
```

### JAR not found?
The system looks for the JAR in these locations (in order):
1. `cfg.POST_PROCESSOR_JAR` (config override)
2. `~/code/voxcore/whisper-post-processor/dist/whisper-post.jar`
3. `~/.local/bin/whisper-post.jar`
4. `/usr/local/bin/whisper-post.jar`
5. `/opt/homebrew/bin/whisper-post.jar`

### Processing not applied?
Check that your processor is in the pipeline. See `ProcessingPipeline.java` and verify your processor's `getPriority()` ordering.

## Running Specific Tests

```bash
# All unit tests
make test-java

# Specific test class
cd whisper-post-processor
./gradlew test --tests "MergedWordProcessorTest"

# With verbose output
./gradlew test --tests "MergedWordProcessorTest" --info
```

## Architecture Recap

```
Hammerspoon (Lua) 
    ↓ HTTP POST to localhost:8765
PTTServiceDaemon (Java, Undertow) ← Long-running, loads JAR once
    ↓
whisper.cpp → ProcessingPipeline → Response
```

The daemon must be restarted to pick up new JAR changes.
