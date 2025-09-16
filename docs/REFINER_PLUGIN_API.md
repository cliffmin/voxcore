# Refiner Plugin API Specification

## Overview
This document defines the simple interface between macos-ptt-dictation and refiner plugins (like VoxCompose).

## Philosophy
- **macos-ptt-dictation**: Dumb, fast, reliable transcription
- **Refiner plugins**: Smart, adaptive, configurable post-processing

## Plugin Capabilities Discovery

Refiners MAY implement a `--capabilities` flag that returns JSON describing their requirements and preferences.

### Request
```bash
voxcompose --capabilities
```

### Response
```json
{
  "version": "1.0",
  "activation": {
    "long_form": {
      "min_duration": 21,
      "description": "Minimum seconds for LLM refinement"
    },
    "quick": {
      "max_duration": 10,
      "description": "Maximum seconds for quick mode"
    }
  },
  "preferences": {
    "whisper_model": "medium.en",
    "whisper_impl": "whisper-cpp"
  },
  "features": {
    "learning": true,
    "auto_correction": true,
    "memory": true
  }
}
```

## How It Works

1. **On Startup**: macos-ptt-dictation queries refiner capabilities
2. **Dynamic Configuration**: Thresholds and models adjust based on refiner response
3. **Fallback**: If no capabilities response, use defaults from ptt_config.lua

## Implementation in macos-ptt-dictation

```lua
-- In push_to_talk.lua initialization
local refinerCaps = require("query_refiner_capabilities")
cfg = refinerCaps.applyRefinerCapabilities(cfg)
```

## Benefits

- **No Hard Dependencies**: Works with any refiner or none
- **Plugin Decides**: Refiner knows best when it should activate
- **Simple Interface**: Just one optional JSON endpoint
- **Backward Compatible**: Old refiners still work with defaults

## Example: VoxCompose Implementation

```java
// In VoxCompose Main.java
if (args.length > 0 && args[0].equals("--capabilities")) {
    JsonObject caps = new JsonObject();
    caps.addProperty("version", "1.0");
    
    JsonObject activation = new JsonObject();
    JsonObject longForm = new JsonObject();
    longForm.addProperty("min_duration", 21);
    longForm.addProperty("description", "Minimum duration for LLM refinement");
    activation.add("long_form", longForm);
    caps.add("activation", activation);
    
    System.out.println(caps.toString());
    System.exit(0);
}
```

## Why This Design?

1. **Separation of Concerns**: Recording doesn't know about refinement logic
2. **Plugin Authority**: Refiner decides its own activation criteria
3. **Zero Coupling**: No compile-time dependencies between projects
4. **Simple Protocol**: Just JSON over stdout
5. **Optional**: Everything works without this, just uses defaults

## Future Extensions

The capabilities response could include:
- Supported input/output formats
- Processing time estimates
- Resource requirements
- API key requirements
- User preference learning capabilities

But we keep it simple for now. The key insight: **the plugin knows best when and how it should run**.