# Repository Structure & Agent Guidelines (WARP)

## Purpose
Offline push-to-talk dictation for macOS using Whisper. Every file must directly support this purpose.

## Core Principle
**Before creating/modifying anything, ask:**
1. Does this directly improve PTT dictation functionality?
2. Is there already a place for this in the structure?
3. Will this break existing user workflows?

---

## Directory Structure & Rules

### `/hammerspoon/` - Core PTT Logic (Lua)
**Purpose**: User-facing PTT functionality and macOS integration  
**MUST contain**: Hammerspoon modules, config templates  
**NEVER add**: Implementation details, processing logic, tests  
**Key files**: `push_to_talk.lua` (main), `ptt_config.lua.sample` (user template)

### `/whisper-post-processor/` - Text Processing (Java)
**Purpose**: All text processing after Whisper transcription  
**MUST contain**: Java processors, pipeline logic, tests, Whisper service, audio utils  
**NEVER add**: UI code, user configs  
**Structure**: Standard Maven/Gradle layout (`src/main/java`, `src/test/java`)  
**New**: `service/` (WhisperService, adapters), `audio/` (AudioProcessor), `daemon/` (HTTP service)

### `/scripts/` - Automation & Utilities
**Purpose**: Setup, testing, analysis tools  
**MUST contain**: Shell/Python scripts that automate tasks  
**NEVER add**: Core functionality, required dependencies  
**Subdirs**: 
- `setup/` - Installation, configuration
- `testing/` - System testing (not unit tests)
- `analysis/` - Performance, metrics, debugging

### `/docs/` - User Documentation
**Purpose**: Public-facing documentation  
**MUST contain**: Setup guides, usage docs, API references  
**NEVER add**: Internal notes, TODOs, meeting notes  
**Structure**: Topic-based (`setup/`, `usage/`, `development/`)

### `/tests/` - Test Infrastructure
**Purpose**: Integration tests and test data  
**MUST contain**: End-to-end tests, fixtures, mocks  
**NEVER add**: Unit tests (those go with code), personal recordings

### Root Files - Project Metadata
**Keep minimal**: README, LICENSE, CHANGELOG, Makefile  
**Config files**: `.gitignore`, `.editorconfig`, CI configs  
**NEVER add**: Personal configs, temp files, drafts

---

## Common Workflows

### Adding a New Feature

1. **Determine placement**:
   - Text processing → `/whisper-post-processor/src/main/java/`
   - User interaction → `/hammerspoon/`
   - Setup/utility → `/scripts/`

2. **Create tests FIRST**:
   - Unit tests → Same directory structure in `src/test/java/`
   - Integration tests → `/tests/integration/`
   - Document test approach → `/docs/development/testing.md`

3. **Update documentation**:
   - User-facing change → Update `/docs/usage/`
   - API change → Update `/docs/api/`
   - Config change → Update sample configs

4. **Update CHANGELOG.md**:
   - Add entry under `[Unreleased]`
   - Follow Keep a Changelog format
   - Include migration notes if breaking

### Modifying Existing Code

1. **Check impact**:
   ```bash
   grep -r "function_name" --include="*.lua" --include="*.java"
   ```

2. **Update tests**:
   - Run existing tests first
   - Add tests for new behavior
   - Update integration tests if needed

3. **Preserve compatibility**:
   - Keep old configs working
   - Add deprecation warnings
   - Document migration path

### Adding Dependencies

- Prefer extending existing modules (service/, audio/, daemon/) before adding new packages
- If adding a new library, justify it in the PR description (why existing tools are insufficient)
- Update CHANGELOG and docs if behavior changes

1. **Justify necessity**:
   - Can existing tools do this?
   - Is it worth the complexity?
   - Will it work offline?

2. **Choose appropriate manager**:
   - Java → `build.gradle`
   - System → `Brewfile`
   - Python → `requirements-optional.txt` (avoid if possible)

3. **Document requirements**:
   - Update `/docs/setup/dependencies.md`
   - Add to CI pipeline
   - Test on clean system

---

## Quality Checklist

Before committing:

- [ ] **Tests pass**: `make test`
- [ ] **No personal data**: No audio files, no personal paths
- [ ] **Documentation updated**: User docs, API docs, CHANGELOG
- [ ] **Backwards compatible**: Old configs still work
- [ ] **No duplication**: Reuse existing utilities
- [ ] **Follows patterns**: Consistent with existing code
- [ ] **Clean history**: Squash WIP commits

---

## Anti-patterns to Avoid

❌ **Creating new directories** without strong justification  
❌ **Dumping scripts** in root or random locations  
❌ **Personal workflows** that only work for you  
❌ **Breaking changes** without migration path  
❌ **Large files** (>1MB) in the repo  
❌ **External dependencies** for simple tasks  
❌ **Mixing concerns** (e.g., audio processing in text processor)

---

## Decision Tree for New Files

```
Is it core PTT functionality?
├─ Yes → Is it Lua/Hammerspoon?
│        ├─ Yes → /hammerspoon/
│        └─ No → /whisper-post-processor/
└─ No → Is it for users?
        ├─ Yes → Is it documentation?
        │        ├─ Yes → /docs/
        │        └─ No → /scripts/setup/
        └─ No → Is it for testing?
                 ├─ Yes → /tests/ or with code
                 └─ No → Probably shouldn't exist
```

---

## Maintenance

**Regular cleanup**:
```bash
# Find suspicious files
make validate-structure

# Remove build artifacts
make clean

# Check for personal data
grep -r "$USER" . --exclude-dir=.git
```

**When in doubt**: Ask if this makes PTT dictation better for users. If not, it probably doesn't belong here.

---

*Version: 2.0 | Updated: 2024-09-16 | Keep this document under 300 lines*