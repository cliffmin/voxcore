# Development Documentation

Documentation for VoxCore developers and contributors.

## Architecture & Design

- **[Architecture](architecture.md)** - System design, plugin model, and design principles
- **[PTT Daemon](ptt-daemon.md)** - Push-to-talk daemon implementation details
- **[Dependency Policy](dependency-policy.md)** - Guidelines for adding dependencies

## Development Workflow

- **[Local Testing](local-testing.md)** - Test changes locally (`make dev-install`)
- **[Transcribe File](transcribe-file.md)** - Transcribe a local audio file and paste (`make paste-file`)
- **[Testing](testing.md)** - Running tests and writing new tests
- **[Release Process](release.md)** - How to create releases
- **[Release Procedures](release-process.md)** - Detailed release procedures
- **[Versioning](versioning.md)** - Version management and recording organization

## Contributing

See [CONTRIBUTING.md](../../CONTRIBUTING.md) for how to contribute to VoxCore.

## Quick Development Commands

```bash
# Build Java post-processor
make build-java

# Run all tests
make test

# Run Java tests only
make test-java-all

# Check version
make version

# Clean artifacts
make clean
```

## Architecture Overview

VoxCore is designed with a **stateless core** and **plugin architecture**:

- **Core**: Fast, predictable, algorithmic processing (no ML, no learning)
- **Plugins**: Opt-in enhancements (VoxCompose for ML features)
- **Clean separation**: Transcription vs. enhancement

See [architecture.md](architecture.md) for complete details.

## Development Principles

1. **Keep core lightweight** - No forced ML dependencies
2. **Plugin-first for advanced features** - Extensibility over monolithic design
3. **Test comprehensively** - Unit + integration tests
4. **Document changes** - Update docs and CHANGELOG
5. **Preserve compatibility** - Avoid breaking changes when possible

---

**For questions or help**, see [GitHub Discussions](https://github.com/cliffmin/voxcore/discussions).
