# Canonical Repository Structure

This document defines the canonical structure of the macos-ptt-dictation repository.
Any files or directories not listed here should be considered non-canonical and potentially subject to cleanup.

## Purpose

This repository implements offline push-to-talk dictation for macOS using OpenAI Whisper.
Files should only exist if they directly support this purpose or its development/documentation.

## Canonical Structure

```
macos-ptt-dictation/
│
├── README.md                    # Main entry point, lean overview (max 100 lines)
├── CHANGELOG.md                 # Version history following Keep a Changelog format
├── CONTRIBUTING.md              # Contribution guidelines (brief, links to docs)
├── LICENSE                      # MIT License
├── CODE_OF_CONDUCT.md          # Community standards
├── SECURITY.md                 # Security policy
├── WARP.md                     # THIS FILE - canonical structure definition
│
├── .gitignore                  # Git ignore patterns
├── .gitattributes              # Git attributes
├── .editorconfig               # Editor configuration
├── .github/                    # GitHub-specific files
│   └── workflows/              # CI/CD workflows only
│       └── ci.yml
│
├── Makefile                    # Build and test automation
├── Brewfile                    # Homebrew dependencies
├── requirements-optional.txt   # Optional Python dependencies (via pipx)
│
├── hammerspoon/                # Core Lua implementation
│   ├── init.lua               # Hammerspoon entry point
│   ├── push_to_talk.lua       # Main PTT implementation
│   ├── ptt_config.lua         # User configuration
│   ├── ptt_config.lua.sample  # Configuration template
│   └── whisper_wrapper.lua    # Whisper integration
│
├── whisper-post-processor/     # Java text post-processor
│   ├── build.gradle           # Gradle build configuration
│   ├── settings.gradle        # Gradle settings
│   ├── gradle.properties      # Gradle properties
│   ├── gradlew               # Gradle wrapper script
│   ├── gradlew.bat           # Gradle wrapper for Windows
│   ├── gradle/               # Gradle wrapper files
│   ├── src/                  # Java source code
│   │   ├── main/java/        # Main implementation
│   │   └── test/java/        # Tests
│   ├── build/                # Build output (GITIGNORED)
│   └── dist/                 # Distribution JARs
│
├── scripts/                    # Utility scripts
│   ├── README.md              # Scripts documentation
│   ├── setup/                 # Installation and configuration
│   │   ├── install.sh
│   │   ├── uninstall.sh
│   │   ├── setup_fast_whisper.sh
│   │   ├── migrate_dictionary.sh
│   │   ├── auto_select_audio_device.sh
│   │   └── setup_ollama_service.sh
│   ├── testing/               # Test scripts
│   │   ├── test_accuracy.sh
│   │   ├── test_accuracy_enhanced.sh
│   │   ├── test_performance.sh
│   │   ├── test_integration.sh
│   │   ├── test_dictionary_plugin.sh
│   │   ├── test_whisper_cpp.sh
│   │   ├── test_f13_modes.sh
│   │   ├── test_bug_fixes.sh
│   │   ├── e2e_test.sh
│   │   ├── debug_recording.sh
│   │   └── quick_benchmark.sh
│   ├── analysis/              # Performance and log analysis
│   │   ├── analyze_durations.py
│   │   ├── analyze_logs.py
│   │   ├── analyze_performance.sh
│   │   └── compare_benchmarks.py
│   ├── utilities/             # Helper utilities
│   │   ├── punctuate.py
│   │   ├── generate_test_data.sh
│   │   └── query_refiner_capabilities.lua
│   ├── diagnostics/           # System diagnostics
│   │   ├── collect_latest.sh
│   │   └── summarize_tx.py
│   └── metrics/               # Performance metrics
│       ├── render_metrics.py
│       └── sweep_threshold.py
│
├── docs/                       # Public documentation
│   ├── README.md              # Documentation index
│   ├── setup/                 # Installation and configuration
│   │   ├── README.md
│   │   ├── dependencies.md
│   │   ├── configuration.md
│   │   └── troubleshooting.md
│   ├── usage/                 # User guides
│   │   ├── README.md
│   │   ├── basic-usage.md
│   │   ├── model-selection.md
│   │   └── dictionary-plugins.md
│   ├── development/           # Developer documentation
│   │   ├── README.md
│   │   ├── architecture.md
│   │   ├── testing.md
│   │   └── release-process.md
│   └── api/                   # API documentation
│       └── refiner-plugin.md
│
├── examples/                   # Example configurations
│   ├── corrections.template.lua
│   └── voxcompose-corrections.template.lua
│
├── tests/                      # Test infrastructure
│   ├── .gitignore             # Ignore test outputs
│   ├── README.md              # Testing documentation
│   ├── fixtures/              # Test data (MOSTLY GITIGNORED)
│   │   └── golden/            # Synthetic test data (GITIGNORED)
│   ├── integration/           # Integration tests
│   ├── util/                  # Test utilities
│   └── mock_refiner_plugin.sh # Mock refiner for testing
│
└── dist/                       # Distribution files (GITIGNORED)
```

## Files That Should NOT Exist

The following patterns indicate files that should be removed:

### Temporary Files
- `*.tmp`, `*.log`, `*.bak`
- `.DS_Store`, `Thumbs.db`
- `*~`, `*.swp`, `*.swo`

### Build Artifacts  
- `build/`, `target/`, `out/`
- `*.class`, `*.jar` (except in dist/)
- `__pycache__/`, `*.pyc`, `*.pyo`
- `.pytest_cache/`, `.coverage`

### Personal Data
- Any audio files (`*.wav`, `*.mp3`, `*.m4a`) outside test fixtures
- Personal voice recordings
- `~/Documents/VoiceNotes/` references
- Personal dictionary corrections in code

### Development Files
- `.idea/` (unless .gitignored)
- `.vscode/` (unless .gitignored)
- `node_modules/` (we don't use Node.js)
- `.env`, `.env.local`
- Personal configuration overrides

### Old/Duplicate Files
- `*_OLD.*`, `*_NEW.*`, `*.backup`
- `*_v2.*`, `*_final.*`, `*_final_final.*`
- Duplicate scripts with similar names
- Migration scripts after they've been applied

### Documentation
- Internal notes in public docs/
- Personal TODO files
- Meeting notes
- Design drafts in main directories

## Directories That Can Exist (But Are Gitignored)

These directories may exist locally but should not be committed:

```
docs-internal/                  # Internal documentation and notes
tests/fixtures/personal/        # Personal test recordings  
tests/fixtures/samples_current/ # Current test batch
tests/results/                  # Test run outputs
~/.config/ptt-dictation/        # User configuration
build/                          # Build outputs
dist/                           # Distribution files
*.egg-info/                     # Python package info
.venv/                          # Python virtual environment
```

## Validation

To check for non-canonical files:

```bash
# Find potentially unwanted files
find . -type f \( \
  -name "*.tmp" -o \
  -name "*.log" -o \
  -name "*.bak" -o \
  -name "*_OLD*" -o \
  -name "*_NEW*" -o \
  -name ".DS_Store" \
\) -not -path "./.git/*"

# Find audio files outside fixtures
find . -type f \( -name "*.wav" -o -name "*.mp3" \) \
  -not -path "./tests/fixtures/*" \
  -not -path "./.git/*"

# Check for personal paths
grep -r "cliffmin" --exclude-dir=.git --exclude-dir=docs-internal .
```

## Maintenance

When adding new files:
1. Ensure they serve the repository's purpose
2. Place them in the appropriate canonical location
3. Update this document if adding new canonical paths
4. Add to .gitignore if they should not be committed

When you see files not in this structure:
1. Determine if they're needed
2. If yes, move to canonical location and update this doc
3. If no, remove them
4. If temporary/personal, add to .gitignore

## Version

Last updated: 2024-09-16
Canonical structure version: 1.0.0