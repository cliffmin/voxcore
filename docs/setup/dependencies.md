# Dependencies and Architecture

## Overview

VoxCore is a hybrid application with a clear separation of concerns:
- **Core**: Lua (Hammerspoon) for macOS automation
- **Post-processing**: Java for transcript cleaning
- **Optional Tools**: Python via pipx for transcription and punctuation

## Dependency Management

### Lua/Hammerspoon (Core)
- **Installation**: Via Homebrew (`brew install --cask hammerspoon`)
- **Location**: System application
- **Config**: `~/.hammerspoon/`
- **No package management needed** - Hammerspoon provides all necessary APIs

### Java Post-Processor
- **Installation**: Via gradle (self-contained in `whisper-post-processor/`)
- **Build**: `gradle shadowJar` creates fat JAR with all dependencies
- **Runtime**: Requires Java 17+ (via `brew install openjdk`)
- **Dependencies**: Managed by Gradle, bundled in JAR

### Python Tools (Optional, Isolated)

**Important**: Python tools are NOT installed globally. They use **pipx** which creates isolated virtual environments for each tool.

#### Architecture
```
~/.local/pipx/
├── venvs/
│   ├── openai-whisper/        # Isolated venv for whisper
│   │   └── bin/python          # Used by push_to_talk.lua
│   └── deepmultilingualpunctuation/  # Isolated venv for punctuation
│       └── bin/python          # Used by punctuate.py
└── bin/
    ├── whisper                 # Executable symlink
    └── deep-punctuate          # Executable symlink
```

#### Current Python Dependencies

1. **openai-whisper** (Being phased out)
   - Purpose: Speech-to-text transcription
   - Installation: `pipx install openai-whisper`
   - Isolation: Runs in `~/.local/pipx/venvs/openai-whisper/`
   - Status: Being replaced by whisper-cpp for 5-10x speed improvement

2. **deepmultilingualpunctuation** (Deprecated)
  - Purpose: Legacy Python punctuation restoration
  - Status: Deprecated and not used by default. Replaced by Java PunctuationProcessor.
  - If needed for experiments, install via `pipx install deepmultilingualpunctuation` and use `scripts/utilities/punctuate.py` manually.

### System Dependencies

Installed via Homebrew:
```bash
brew install ffmpeg          # Audio recording
brew install whisper-cpp     # Fast transcription (recommended)
brew install openjdk         # Java runtime for post-processor
```

## Dependency Isolation

### Why pipx?
- **Isolation**: Each Python tool gets its own virtual environment
- **No conflicts**: Dependencies don't interfere with system Python or each other
- **Clean uninstall**: `pipx uninstall <package>` removes everything
- **User-level**: Installed in `~/.local/`, not system-wide
- **PATH management**: Automatically adds executables to PATH

### Project-local venv (Not Used)
This project does **not** use a project-local virtual environment (`.venv/`) because:
1. No Python source code in the project
2. Python tools are utilities, not project dependencies
3. pipx provides better isolation for standalone tools

The `.venv/` entry in `.gitignore` is defensive - preventing accidental commits if someone creates a local venv for testing.

## Installation Guide

### Minimal Setup (Recommended)
```bash
# Core dependencies only
brew install --cask hammerspoon
brew install ffmpeg whisper-cpp

# Java for post-processor
brew install openjdk
```

### Full Setup (With Optional Python Tools)
```bash
# Core dependencies
brew install --cask hammerspoon
brew install ffmpeg whisper-cpp openjdk

# Python tools via pipx (optional)
brew install pipx
pipx ensurepath
pipx install openai-whisper              # Fallback transcription
pipx install deepmultilingualpunctuation # Punctuation restoration
```

## Migration Path

The project is transitioning away from Python dependencies:

| Component | Current | Future | Status |
|-----------|---------|---------|--------|
| Transcription | openai-whisper (Python) | whisper-cpp (C++) | ✅ In Progress |
| Post-processing | Java | Java | ✅ Complete |
| Punctuation | deepmultilingualpunctuation (Python) | Optional/Native | 🔄 Planned |

## Testing Dependencies

For development and testing:
```bash
# Install test dependencies
pip install --user pytest  # Or use pipx install pytest

# Run tests
make test
```

## CI/CD Dependencies

GitHub Actions workflow uses:
- Python 3.11 (for CI environment setup)
- pipx (for installing whisper during tests)
- No production Python code

## Troubleshooting

### Python Tools Not Found
If `whisper` or punctuation tools aren't found:
```bash
# Check pipx installations
pipx list

# Reinstall if needed
pipx reinstall openai-whisper
pipx reinstall deepmultilingualpunctuation
```

### Verify Isolation
```bash
# Check that tools are using pipx venvs, not system Python
which whisper
# Should show: ~/.local/bin/whisper

ls -la ~/.local/bin/whisper
# Should be symlink to pipx installation
```

### Clean Uninstall
```bash
# Remove Python tools completely
pipx uninstall openai-whisper
pipx uninstall deepmultilingualpunctuation

# Remove pipx itself if desired
pip uninstall pipx
rm -rf ~/.local/pipx
```

## Summary

- **Core functionality**: No Python required (Lua + Java)
- **Python tools**: Optional, isolated via pipx
- **No global Python packages**: Everything is contained
- **Migration in progress**: Moving to compiled solutions for better performance