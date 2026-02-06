# Architecture

## Design Principle: Stateless Core

**VoxCore is intentionally stateless.** All processing is algorithmic, deterministic, and side-effect-free. No learning, no user profiles, no adaptive behavior. This keeps VoxCore fast, predictable, and maintainable.

**For stateful/ML features,** use [VoxCompose](https://github.com/cliffmin/voxcompose) (optional plugin).

## Overview

```
┌─────────────────────────────────────────┐
│  Hammerspoon (Lua, ~422 lines)          │
│  - Hotkey binding (F13 hold/toggle)     │
│  - Audio recording via ffmpeg           │
│  - Audio device resolution (by name)    │
│  - Visual indicator (ripple animation)  │
│  - Paste result to cursor               │
└─────────────────┬───────────────────────┘
                  │
                  │  Calls: voxcore transcribe <audio.wav>
                  v
┌─────────────────────────────────────────┐
│  VoxCore CLI (Java, ~3,000+ lines)      │
│  - Config loading & validation          │
│  - Whisper transcription (whisper-cpp)  │
│  - Vocabulary loading (from VoxCompose) │
│  - Post-processing pipeline             │
└─────────────────┬───────────────────────┘
                  │
                  v
┌─────────────────────────────────────────┐
│  Post-Processing Pipeline (stateless)   │
│  Reflow → Disfluency → MergedWord →    │
│  Sentences → Capitalization →           │
│  Punctuation → Dictionary →             │
│  PunctuationNormalizer                  │
│  (all processors are pure functions)    │
└─────────────────┬───────────────────────┘
                  │
                  v
┌─────────────────────────────────────────┐
│  Optional: VoxCompose (ML plugin)       │
│  - LLM-based transcript refinement     │
│  - Self-learning corrections            │
│  - Vocabulary export to VoxCore         │
└─────────────────────────────────────────┘
```

### Data Flow

1. **User holds hotkey** (F13) -- Hammerspoon starts recording via `ffmpeg` (avfoundation, 16 kHz mono WAV)
2. **User releases hotkey** -- Recording stops, Hammerspoon calls `voxcore transcribe <audio.wav>`
3. **VoxCore CLI** loads config from `~/.config/voxcore/config.json` (env > file > defaults)
4. **Whisper transcription** via whisper-cpp (`WhisperService` / `WhisperCppAdapter`)
5. **Post-processing pipeline** applies stateless text corrections
6. **Optional VoxCompose refinement** via pipe or integration
7. **Result returned** to Hammerspoon, pasted at cursor position

### Config Precedence

```
request parameters > environment variables > config file > defaults
```

Config file: `~/.config/voxcore/config.json`

### Log Output

Transaction logs are written as JSONL:

```json
{
  "ts": "2026-02-05T21:59:30Z",
  "kind": "success",
  "app": "voxcore",
  "model": "base.en",
  "wav": "/Users/you/Documents/VoiceNotes/recording.wav",
  "duration_sec": 6.1,
  "tx_ms": 1450,
  "transcript_chars": 67
}
```

## Plugin Architecture

### Design Philosophy

**VoxCore is an extensible platform**, not a monolithic tool. The core provides fast, reliable, stateless transcription. Advanced features come via plugins.

This follows the VS Code extension model: lightweight core + rich ecosystem of opt-in extensions.

### VoxCore (This Project) - The Core

- **Stateless by design** - Pure algorithmic processing
- **Fast & predictable** - No learning overhead, deterministic output
- **Core functionality**: macOS automation, capture, transcription, UX, files, logs
- **Post-processing**: Basic cleanup (disfluencies, punctuation, word separation)
- **No ML models** - No training, no user profiles, no adaptive behavior
- **Plugin-ready** - Extensible architecture for community contributions

### VoxCompose (Official Plugin) - ML Enhancement

[VoxCompose](https://github.com/cliffmin/voxcompose) is the **official plugin** for ML-based refinement:

- **Stateful by design** - Learning, adaptation, user profiles
- **ML-enhanced** - LLM refinement, context-aware processing
- **Advanced features**: Adaptive casing, correction learning, intelligent formatting
- **Pluggable providers**: Local Ollama, cloud APIs (optional)
- **Builds on VoxCore** - Takes VoxCore output, enhances it
- **Completely optional** - Install only if you want ML features

### Future: Community Plugins

The architecture is designed to support community-built extensions:

**Planned plugin types:**
- **Output formatters** - Journal, email, meeting notes, code comments
- **Language-specific** - Optimizations for specific languages/domains
- **Integration plugins** - Direct paste to specific apps, cloud sync
- **Custom workflows** - Build your own processing pipeline

**Plugin API** (planned):
```
Input: VoxCore transcription + metadata
Output: Refined text + optional metadata
Interface: Simple stdin/stdout or HTTP endpoint
```

### Why This Architecture?

| Approach | VoxCore (Plugin-based) | Monolithic |
|----------|------------------------|------------|
| Startup time | Fast (no ML) | Slow (loads everything) |
| Memory usage | Low (~500MB) | High (~2-3GB with ML) |
| User choice | Install what you need | Everything included |
| Extensibility | High (community plugins) | Low (fork required) |
| Maintenance | Core + plugins separate | Everything coupled |

## Architectural Decision: Removed ContextProcessor

**Background**: ContextProcessor (v0.4.0) learned term casing from recent transcripts. While useful, it introduced state into VoxCore's core pipeline.

**Decision**: Removed ContextProcessor from VoxCore (v0.4.3+), moved adaptive/contextual features to VoxCompose.

**Rationale**:
- Maintains VoxCore's stateless principle
- Simplifies VoxCore architecture
- Allows VoxCompose to do this better (with more context, better ML)
- No behavior change for CLI users (who weren't using streaming pipeline)

**Result**: VoxCore remains fast, predictable, and stateless. VoxCompose handles all stateful/adaptive processing.
