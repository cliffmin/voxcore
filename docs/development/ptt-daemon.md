# PTT Service Daemon

The PTT Service Daemon exposes a minimal HTTP API to let Hammerspoon (Lua) call Java transcription without spawning a JVM per request.

## Endpoints

- GET /health
  - Returns: `{ "status": "ok", "whisperAvailable": true|false }`
- POST /transcribe
  - Body: `{ "path": "/abs/path.wav", "model": "base.en" }`
  - Returns: `{ text, language, duration, segments[], metadata{} }`

## Running locally

```bash
# From project root
./gradlew :whisper-post-processor:shadowJar
java -cp whisper-post-processor/build/libs/whisper-post.jar com.cliffmin.whisper.daemon.PTTServiceDaemon
```

## Lua bridge usage (Hammerspoon)

```lua
local jb = require('java_bridge')
local ok = jb.ensure_up()
if ok then
  local res, err = jb.transcribe('/path/to/file.wav', 'base.en')
  if res then print(res.text) else print('error', err) end
end
```

## Notes

- The daemon normalizes audio to 16kHz mono 16-bit using the AudioProcessor.
- Model is auto-selected by audio duration if not specified.
- Security: bound to 127.0.0.1 only.
