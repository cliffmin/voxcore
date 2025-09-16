# Dictionary Plugin Architecture

## Overview

The push-to-talk dictation system now supports external dictionary plugins for text corrections, removing the need for hard-coded personal corrections in the repository.

## Why This Change?

Previously, personal word corrections were hard-coded in `ptt_config.lua`, which caused several problems:
- Personal mishearings contaminated the public repository
- No way to share correction sets between users
- Git history polluted with dictionary updates
- Difficult to maintain different correction sets for different contexts

## How It Works

The system now loads dictionary corrections from external files in order of preference:

1. **User's personal dictionary**: `~/.config/ptt-dictation/corrections.lua`
2. **VoxCompose learned corrections**: `~/.config/voxcompose/corrections.lua`
3. **System-wide shared corrections**: `/usr/local/share/ptt-dictation/corrections.lua`

The first file found is loaded and used. If no external dictionary is found, no corrections are applied (beyond the Java post-processor's algorithmic fixes).

## Setting Up Your Personal Dictionary

### Quick Start

1. Create the config directory:
```bash
mkdir -p ~/.config/ptt-dictation
```

2. Copy the template:
```bash
cp examples/corrections.template.lua ~/.config/ptt-dictation/corrections.lua
```

3. Edit the file to add your corrections:
```lua
return {
  ["jason"] = "JSON",
  ["jura"] = "Jira",
  ["github"] = "GitHub",
  -- Add your corrections here
}
```

4. Reload Hammerspoon for changes to take effect

### Format

The dictionary file should return a Lua table with corrections:
- **Keys**: The misheard text (case-insensitive)
- **Values**: The correct replacement text

Example:
```lua
return {
  -- Technical terms
  ["no sequel"] = "NoSQL",
  ["jason"] = "JSON",
  
  -- Common mishearings
  ["withe"] = "with the",
  ["its like"] = "it's like",
  
  -- Domain-specific
  ["acme corp"] = "ACME Corporation",
}
```

## VoxCompose Integration

VoxCompose can automatically learn corrections from your edits and export them for use by the dictation system.

### Automatic Integration

When VoxCompose is configured to export learned corrections, they can be automatically loaded:

1. Configure VoxCompose to export to `~/.config/voxcompose/learned_corrections.json`
2. Create a Lua adapter using the template:
```bash
cp examples/voxcompose-corrections.template.lua ~/.config/voxcompose/corrections.lua
```

### Manual Integration

You can also manually copy high-confidence corrections from VoxCompose:

```bash
# View VoxCompose's learned corrections
cat ~/.config/voxcompose/learned_corrections.json | jq '.corrections | to_entries[] | select(.value.confidence > 0.8)'

# Add them to your personal dictionary
vim ~/.config/ptt-dictation/corrections.lua
```

## Shared Team Dictionaries

Teams can maintain shared correction dictionaries:

1. Create a Git repository for team corrections
2. Install to the system location:
```bash
sudo mkdir -p /usr/local/share/ptt-dictation
sudo cp team-corrections.lua /usr/local/share/ptt-dictation/corrections.lua
```

3. Team members automatically get updates when pulling the repository

## Processing Order

Text corrections are applied in this order:

1. **Whisper transcription** - Raw speech-to-text
2. **Java post-processor** - Algorithmic fixes (merged words, punctuation, capitalization)
3. **Dictionary replacements** - Your custom corrections
4. **VoxCompose** (if enabled) - AI-powered refinement

## What Should Go in the Dictionary?

### Good Candidates ✅
- Personal/accent-specific mishearings ("Jason" → "JSON")
- Domain terminology ("the product" → "WidgetPro")
- Company/project names ("acme" → "ACME Corp")
- Technical terms specific to your work

### Poor Candidates ❌
- Universal corrections (handled by Java processor)
- Punctuation fixes (handled by Java processor)
- Grammatical corrections (better suited for VoxCompose)
- Context-dependent corrections (need AI understanding)

## Debugging

To see if your dictionary is being loaded:

1. Check Hammerspoon Console (`Cmd+Alt+Ctrl+H`)
2. Look for: `Loaded dictionary from: <path>`

To test corrections:
1. Create a test audio with the misheard words
2. Run transcription
3. Check if corrections were applied

## Migration Guide

If you have existing corrections in `ptt_config.lua`:

1. Copy your DICTIONARY_REPLACE table content
2. Create `~/.config/ptt-dictation/corrections.lua`
3. Paste and reformat as a Lua return statement
4. Remove DICTIONARY_REPLACE from `ptt_config.lua`
5. Reload Hammerspoon

Example migration:
```lua
-- Old (in ptt_config.lua):
DICTIONARY_REPLACE = {
  ["jason"] = "JSON",
  ["jura"] = "Jira",
}

-- New (in ~/.config/ptt-dictation/corrections.lua):
return {
  ["jason"] = "JSON",
  ["jura"] = "Jira",
}
```

## Future Enhancements

Planned improvements to the dictionary system:

1. **Hot reload** - Reload dictionary without restarting Hammerspoon
2. **Multiple dictionaries** - Load and merge multiple dictionary files
3. **Context-aware corrections** - Different corrections based on active application
4. **Regex patterns** - Support for pattern-based replacements
5. **Confidence scores** - Learn from usage patterns
6. **Two-way sync with VoxCompose** - Bidirectional learning

## FAQ

**Q: Can I use multiple dictionary files?**
A: Currently, only the first found file is loaded. Multiple dictionary support is planned.

**Q: Are corrections case-sensitive?**
A: No, patterns are matched case-insensitively, but the replacement preserves the specified case.

**Q: How do I disable all corrections?**
A: Remove or rename your corrections.lua file, or return an empty table `{}`.

**Q: Can I use regex patterns?**
A: Not yet. Currently only exact string matching with word boundaries is supported.

**Q: Will my corrections sync across machines?**
A: Only if you manually sync the `~/.config/ptt-dictation/` directory (e.g., via Git, Dropbox, etc.)