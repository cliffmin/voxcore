# Architecture

## Design Principle: Stateless Core

**VoxCore is intentionally stateless.** All processing is algorithmic, deterministic, and side-effect-free. No learning, no user profiles, no adaptive behavior. This keeps VoxCore fast, predictable, and maintainable.

**For stateful/ML features,** use [VoxCompose](https://github.com/cliffmin/voxcompose) (optional plugin).

## Overview

- **Hammerspoon (Lua)**: macOS automation & UX (hotkeys, notifications)
- **Audio capture**: ffmpeg avfoundation → 16 kHz mono WAV
- **Java Service (Undertow)**: Long-running daemon (no per-request JVM cold-start)
  - HTTP: /health, /transcribe, /metrics (Prometheus)
  - WebSocket: /ws (incremental processing of accumulated text)
- **Transcription**: whisper.cpp via WhisperService/WhisperCppAdapter
- **Java Post-Processor Pipeline**: Stateless algorithmic processing
  - Reflow → Disfluency → MergedWord → Sentences → Capitalization → PunctuationProcessor → Dictionary → PunctuationNormalizer
  - **All processors are pure functions** - no state, no learning
- **Config precedence**: request > env/file (~/.config/ptt-dictation/config.json) > defaults
- **Outputs**: pasted text (Hammerspoon), optional files/logs
- **Optional refine**: VoxCompose (separate project) for ML-based enhancement

Log example
```json path=null start=null
{
  "ts": "2025-08-30T21:59:30Z",
  "kind": "success",
  "app": "voxcore",
  "model": "base.en",
  "device": "cpu",
  "beam_size": 3,
  "wav": "/Users/you/Documents/VoiceNotes/2025-Aug-30_12.31.34_AM/2025-Aug-30_12.31.34_AM.wav",
  "duration_sec": 6.1,
  "preprocess_used": false,
  "tx_ms": 1450,
  "transcript_chars": 67
}
```

Key benefits of the Java service
- Faster start-of-speech capture (service is warm; avoids JVM cold-start delays that used to truncate first words when combined with silence gating)
- Real-time streaming via WebSocket (incremental refinement)
- Observability via Prometheus metrics
- Clean API seam (Lua ↔ HTTP/WS) and better CI test surfaces

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

**Benefits:**

1. **Lightweight core** - VoxCore stays fast with zero ML dependencies
2. **User choice** - Install only what you need (pay for what you use)
3. **Clear boundaries** - Core = transcription, plugins = enhancement
4. **Independent evolution** - Plugins can evolve without affecting core
5. **Community contributions** - Anyone can build plugins
6. **No forced complexity** - Simple transcription doesn't require ML overhead

**Comparison to monolithic approach:**

| Approach | VoxCore (Plugin-based) | Monolithic |
|----------|------------------------|------------|
| Startup time | Fast (no ML) | Slow (loads everything) |
| Memory usage | Low (~500MB) | High (~2-3GB with ML) |
| User choice | Install what you need | Everything included |
| Extensibility | High (community plugins) | Low (fork required) |
| Maintenance | Core + plugins separate | Everything coupled |

### Extension Marketplace (Future)

Inspired by VS Code, planned features:

- **Plugin registry** - Discover and install community plugins
- **Version management** - Update plugins independently
- **Ratings & reviews** - Community feedback on quality
- **Security sandboxing** - Safe execution of third-party code
- **Plugin API docs** - Guide for building your own

**Timeline:** After v1.0 (core stabilization first)

## Architectural Decision: Removed ContextProcessor

**Background**: ContextProcessor (v0.4.0) learned term casing from recent transcripts. While useful, it introduced state into VoxCore's core pipeline.

**Decision**: Removed ContextProcessor from VoxCore (v0.4.3+), moved adaptive/contextual features to VoxCompose.

**Rationale**:
- Maintains VoxCore's stateless principle
- Simplifies VoxCore architecture
- Allows VoxCompose to do this better (with more context, better ML)
- No behavior change for CLI users (who weren't using streaming pipeline)

**Result**: VoxCore remains fast, predictable, and stateless. VoxCompose handles all stateful/adaptive processing.

