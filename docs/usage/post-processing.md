# Post-Processing and Text Cleanup

The Java post-processor automatically cleans up transcribed text to make it more professional and readable.

## Features

### 1. Disfluency Removal

Automatically removes common speech disfluencies and filler words:

| Type | Examples | Result |
|------|----------|--------|
| **Fillers** | um, uh, er, erm | Removed |
| **Discourse markers** | you know, I mean, like | Removed when used as fillers |
| **Hedges** | sort of, kind of, basically, actually | Removed in most contexts |
| **Repetitions** | "I I think", "we we should" | Deduplicated |
| **Stuttering** | "th-th-this", "t-t-test" | Cleaned |

**Example:**
```
Input:  "Um, so basically, you know, I think we should, uh, implement this feature."
Output: "So, I think we should implement this feature."
```

### 2. Technical Term Correction

Automatically fixes common technical terms:

| Incorrect | Corrected |
|-----------|-----------|
| github | GitHub |
| javascript | JavaScript |
| typescript | TypeScript |
| nodejs | Node.js |
| api | API |
| json | JSON |
| xml | XML |
| python | Python |

### 3. Segment Reflow

Merges artificially broken segments into continuous thoughts while preserving:
- Sentence boundaries (. ! ?)
- Natural pauses
- Timing information (in JSON mode)

### 4. Custom Dictionary Options

You can apply custom corrections via either JSON (Java post-processor) or Lua (Hammerspoon plugin). Both can be used together; corrections are applied additively.

Option A: JSON dictionary (Java post-processor)
- Path priority (first found is loaded, later files can add/override):
  - `~/.config/ptt-dictation/dictionary.json`
  - `~/.config/ptt-dictation/corrections.json`
  - `~/.config/voxcompose/corrections.json`
  - `/usr/local/share/ptt-dictation/dictionary.json`
  - `/usr/local/share/ptt-dictation/corrections.json`

Example JSON (either flat map or {"replacements"} object):
```json
{
  "replacements": {
    "acme corp": "ACME Corporation",
    "my project": "MyProject™",
    "team lead": "Tech Lead"
  }
}
```

Option B: Lua plugin corrections (Hammerspoon)
1) Create the config directory
```bash
mkdir -p ~/.config/ptt-dictation
```

2) Copy the template and edit
```bash
cp examples/corrections.template.lua ~/.config/ptt-dictation/corrections.lua
```

3) Add your corrections
```lua
return {
  ["acme corp"] = "ACME Corporation",
  ["my project"] = "MyProject™",
  ["team lead"] = "Tech Lead",
}
```

See also: `docs/usage/dictionary-plugins.md` for details and advanced options.

## Usage

### Direct Text Processing

```bash
# Process plain text
echo "Um, this is, uh, a test." | java -jar whisper-post-processor/dist/whisper-post.jar
# Output: This is a test.

# Process with options
echo "Input text" | java -jar whisper-post.jar [options]
```

### JSON Processing (Whisper Output)

```bash
# Process Whisper JSON output
whisper audio.wav --output_format json | java -jar whisper-post.jar --json
```

### Command-Line Options

| Option | Description |
|--------|-------------|
| `--json` | Process JSON input/output (for Whisper integration) |
| `--disable-disfluency` | Keep filler words and disfluencies |
| `--disable-dictionary` | Skip dictionary replacements |
| `--disable-reflow` | Keep original segment breaks |
| `--disable-capitalization` | Don't fix capitalization |
| `--disable-punctuation` | Don't normalize punctuation |
| `-f FILE` | Read from file instead of stdin |
| `-o FILE` | Write to file instead of stdout |
| `--debug` | Enable debug output |

## Integration with Push-to-Talk

The post-processor is automatically integrated when configured in `ptt_config.lua`:

```lua
-- Enable post-processing (coming soon)
POST_PROCESSING_ENABLED = true
POST_PROCESSOR_PATH = "whisper-post-processor/dist/whisper-post.jar"
```

## Performance

- **Processing speed**: <50ms for typical dictation
- **Large text**: <200ms for 100 lines
- **Memory usage**: Minimal (runs in JVM)
- **No network**: 100% offline processing

## Examples

### Professional Email
```
Input:  "Um, hi John, uh, I wanted to, you know, follow up on our meeting."
Output: "Hi John, I wanted to follow up on our meeting."
```

### Technical Documentation
```
Input:  "The api uses json and, um, javascript for the frontend."
Output: "The API uses JSON and JavaScript for the frontend."
```

### Meeting Notes
```
Input:  "So basically, we need to, like, refactor the github repository."
Output: "So we need to refactor the GitHub repository."
```

## Customization

### Creating a Custom Dictionary (JSON)

1. Create the config directory:
```bash
mkdir -p ~/.config/ptt-dictation
```

2. Create `~/.config/ptt-dictation/dictionary.json`:
```json
{
  "replacements": {
    "old term": "new term",
    "abbreviation": "Full Name",
    "misspelling": "correct spelling"
  }
}
```

The Java post-processor will automatically load the JSON dictionary if present.

### Creating a Custom Dictionary (Lua)

1. Create the config directory:
```bash
mkdir -p ~/.config/ptt-dictation
```

2. Create `~/.config/ptt-dictation/corrections.lua`:
```lua
return {
  ["old term"] = "new term",
  ["abbreviation"] = "Full Name",
  ["misspelling"] = "correct spelling",
}
```

The Hammerspoon layer will load these Lua corrections if configured.

Note: You can use both JSON and Lua corrections; they complement each other.

### Disabling Specific Features

If certain cleaning features interfere with your use case:

```bash
# Keep filler words (for linguistic analysis)
java -jar whisper-post.jar --disable-disfluency

# Keep original capitalization (for code dictation)
java -jar whisper-post.jar --disable-capitalization

# Disable all processing except disfluency removal
java -jar whisper-post.jar \
  --disable-dictionary \
  --disable-capitalization \
  --disable-punctuation
```

## Troubleshooting

### Post-processor not working

1. Ensure Java 17+ is installed:
```bash
java --version
```

2. Build the processor:
```bash
cd whisper-post-processor
gradle clean shadowJar buildExecutable
```

3. Test directly:
```bash
echo "um, test" | java -jar dist/whisper-post.jar
```

### Custom dictionary not loading

Check for JSON dictionary (Java):
```bash
ls -l ~/.config/ptt-dictation/dictionary.json || true
```

Check for Lua corrections (Hammerspoon):
```bash
ls -l ~/.config/ptt-dictation/corrections.lua || true
```

If Lua corrections fail to load, temporarily remove recent edits and reload Hammerspoon. If JSON is not applied, ensure the file is valid JSON and readable.

### Performance issues

For large texts, ensure sufficient JVM memory:
```bash
java -Xmx256m -jar whisper-post.jar
```

## See Also

- [Basic Usage](basic-usage.md) - General push-to-talk usage
- [Configuration](../setup/configuration.md) - System configuration
- [Dictionary Plugins](dictionary-plugins.md) - Advanced dictionary features