# Documentation Strategy

## Public vs Internal Documentation

### PUBLIC (Include in repo)

**README.md** (Keep to ~100 lines max)
- Brief, compelling description
- Key features (5-7 bullet points)
- Quick installation steps
- Basic usage
- Link to detailed docs
- License and contribution info

**docs/** (User-facing)
- USAGE.md - How to use the tool
- CONFIGURATION.md - Settings and options  
- TROUBLESHOOTING.md - Common issues
- CONTRIBUTING.md - How to contribute

### INTERNAL (Keep private or in docs/internal/)

**docs/internal/** (Developer notes)
- ARCHITECTURE.md - System design
- LOGGING.md - Metrics and analytics
- DEVELOPMENT.md - Dev setup and testing
- RELEASE.md - Release process

### What NOT to Document Publicly

1. **Detailed Metrics/Logging**
   - Don't expose internal performance tracking
   - Users don't need to know about JSONL structure
   - Keep analytics scripts internal

2. **Implementation Details**
   - Internal function names
   - Specific file paths for logs
   - Debug features and test modes

3. **Personal Workflow**
   - Your specific development setup
   - Internal tools (WARP.md)
   - Test fixtures and benchmarks

## Recommended Changes

### Simplify README.md to:
```markdown
# macos-ptt-dictation

Privacy-first push-to-talk dictation for macOS. Hold F13 to speak, release to paste.

## Features
✅ 100% offline - no cloud services
✅ One-key operation - just F13
✅ Fast transcription - 5x realtime
✅ Smart formatting - handles pauses naturally
✅ All recordings saved locally

## Quick Start
[Installation and basic usage - 20 lines max]

## Documentation
- [Usage Guide](docs/USAGE.md)
- [Configuration](docs/CONFIG.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)

## License
MIT - See LICENSE
```

### Move Internal Details to:
- `docs/internal/METRICS.md` - Logging and analytics
- `docs/internal/ARCHITECTURE.md` - Technical design
- `.github/DEVELOPMENT.md` - Contributor guide

### Why This Matters for Resume

**Good open source projects show:**
- Clean, professional documentation
- Clear separation of concerns
- Understanding of user vs developer needs
- Not oversharing implementation details

**Red flags to avoid:**
- Walls of text in README
- Exposing internal metrics
- Mixing user and dev docs
- TMI about your process
