# Manual Correction Feature - Future Implementation

**Status:** FUTURE - Not scheduled for implementation yet
**Date:** 2025-12-04
**Priority:** Medium (after Phase 1-2 of accuracy improvements)

---

## Overview

**Goal:** Enable users to explicitly correct transcriptions via hotkey, creating a tight feedback loop for speech learning.

**User Workflow:**
1. User triggers VoxCore hotkey → transcription pastes as normal
2. User edits the pasted text (fix errors, rephrase, improve)
3. User hits **correction hotkey** (e.g., `Cmd+Alt+Ctrl+Shift+C`)
4. VoxCore captures the corrected version and saves metadata
5. VoxCompose learns from the diff and improves future transcriptions

**Value Proposition:**
- **Faster learning:** Explicit corrections have higher confidence than inferred ones
- **User control:** Users actively teach VoxCore their speech patterns
- **Delta-based:** Only differences are stored, not full duplicate text
- **Augments auto-learning:** Works alongside existing LLM refinement

---

## Proposed Architecture

### Recommendation: **VoxCore Feature + VoxCompose Integration**

**NOT a plugin** - This should be core VoxCore functionality because:
- ✅ Hotkey handling requires Hammerspoon integration (VoxCore's domain)
- ✅ Metadata file writing is already VoxCore's responsibility
- ✅ Simple diff calculation can be done in Lua (stateless)
- ✅ VoxCompose reads metadata files for learning (existing pattern)

**Architecture:**

```
┌─────────────────────────────────────────────────────────┐
│ VoxCore (Stateless)                                     │
│                                                         │
│  1. User presses transcription hotkey                   │
│  2. Transcription pastes → clipboard                    │
│  3. User edits text in destination app                  │
│  4. User presses CORRECTION hotkey                      │
│  5. VoxCore reads current clipboard                     │
│  6. VoxCore calculates diff (original → corrected)      │
│  7. VoxCore writes to .meta.json                        │
│     {                                                   │
│       "original": "add error handling",                 │
│       "corrected": "Add error handling to DB module",   │
│       "correction_method": "explicit_hotkey",           │
│       "edit_distance": 23,                              │
│       "user_initiated": true                            │
│     }                                                   │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│ VoxCompose (Stateful Learning)                          │
│                                                         │
│  1. On startup: scan for .meta.json files with         │
│     corrections                                         │
│  2. Parse original → corrected diffs                    │
│  3. Extract word-level corrections:                     │
│     - "add" → "Add" (capitalization)                    │
│     - Missing "to DB module" (phrase completion)        │
│  4. Update UserProfile with learned patterns            │
│  5. Regenerate vocabulary files with new terms          │
│  6. Apply corrections to future transcriptions          │
└─────────────────────────────────────────────────────────┘
```

**Benefits of this architecture:**
- ✅ VoxCore stays stateless (just writes metadata files)
- ✅ VoxCompose owns all learning logic (stateful)
- ✅ Works even if VoxCompose not installed (corrections stored for future use)
- ✅ No new plugin needed
- ✅ Reuses existing metadata infrastructure

---

## Detailed Implementation

### Phase 1: VoxCore - Hotkey & Metadata Capture

#### 1.1 New Hotkey Binding

```lua
-- In ptt_config.lua
HOTKEYS = {
  RECORD = {"cmd", "alt", "ctrl"}, "space",
  CORRECT_LAST = {"cmd", "alt", "ctrl", "shift"}, "c"  -- NEW
}

-- In push_to_talk.lua
local lastRecordingId = nil
local lastTranscript = nil
local lastTranscriptTime = nil

-- Bind correction hotkey
hs.hotkey.bind(
  CONFIG.HOTKEYS.CORRECT_LAST[1],
  CONFIG.HOTKEYS.CORRECT_LAST[2],
  function()
    captureManualCorrection()
  end
)
```

#### 1.2 Correction Capture Logic

```lua
local function captureManualCorrection()
  -- Validate that we have a recent transcription to correct
  if not lastRecordingId then
    hs.alert.show("⚠️ No recent transcription to correct")
    return
  end

  -- Check if transcription is recent (within 5 minutes)
  local now = os.time()
  if lastTranscriptTime and (now - lastTranscriptTime) > 300 then
    hs.alert.show("⚠️ Last transcription too old (>5 min)")
    return
  end

  -- Get corrected text from clipboard
  local correctedText = hs.pasteboard.getContents()

  if not correctedText or correctedText == "" then
    hs.alert.show("⚠️ Clipboard is empty")
    return
  end

  -- Calculate edit distance
  local editDistance = levenshtein(lastTranscript, correctedText)

  if editDistance == 0 then
    hs.alert.show("✓ No changes detected - transcription was correct!")
    return
  end

  -- Save correction to metadata file
  local success = saveCorrection(lastRecordingId, {
    original = lastTranscript,
    corrected = correctedText,
    correction_method = "explicit_hotkey",
    edit_distance = editDistance,
    edit_ratio = editDistance / #lastTranscript,
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    user_initiated = true
  })

  if success then
    hs.alert.show(string.format("✓ Correction saved (%d chars changed)", editDistance))
    log.i(string.format("Correction saved for %s: %d char edits", lastRecordingId, editDistance))
  else
    hs.alert.show("❌ Failed to save correction")
  end
end
```

#### 1.3 Metadata File Update

```lua
local function saveCorrection(recordingId, correction)
  local metaPath = string.format(
    "%s/Documents/VoiceNotes/%s/%s.meta.json",
    os.getenv("HOME"),
    recordingId,
    recordingId
  )

  -- Load existing metadata or create new
  local meta = {}
  local f = io.open(metaPath, "r")
  if f then
    local content = f:read("*all")
    f:close()
    meta = json.decode(content) or {}
  end

  -- Update transcript section
  meta.transcript = meta.transcript or {}
  meta.transcript.original = correction.original
  meta.transcript.corrected = correction.corrected
  meta.transcript.correction_method = correction.correction_method

  -- Add user feedback section
  meta.user_feedback = meta.user_feedback or {}
  meta.user_feedback.correction_timestamp = correction.timestamp
  meta.user_feedback.edit_distance = correction.edit_distance
  meta.user_feedback.edit_ratio = correction.edit_ratio
  meta.user_feedback.user_initiated = correction.user_initiated

  -- Calculate and store diff details
  meta.correction_details = calculateDetailedDiff(
    correction.original,
    correction.corrected
  )

  -- Write back to file
  f = io.open(metaPath, "w")
  if not f then return false end

  f:write(json.encode(meta))
  f:close()

  return true
end
```

#### 1.4 Detailed Diff Calculation

```lua
local function calculateDetailedDiff(original, corrected)
  local origWords = splitWords(original)
  local corrWords = splitWords(corrected)

  local diff = {
    word_changes = {},
    insertions = {},
    deletions = {},
    capitalizations = {},
    substitutions = {}
  }

  -- Simple word-by-word comparison (can be improved with LCS algorithm)
  local i, j = 1, 1
  while i <= #origWords or j <= #corrWords do
    local origWord = origWords[i] or ""
    local corrWord = corrWords[j] or ""

    if origWord == corrWord then
      -- Exact match
      i, j = i + 1, j + 1

    elseif origWord:lower() == corrWord:lower() then
      -- Capitalization change
      table.insert(diff.capitalizations, {
        from = origWord,
        to = corrWord,
        position = i
      })
      i, j = i + 1, j + 1

    elseif origWord == "" then
      -- Insertion
      table.insert(diff.insertions, {
        word = corrWord,
        position = j
      })
      j = j + 1

    elseif corrWord == "" then
      -- Deletion
      table.insert(diff.deletions, {
        word = origWord,
        position = i
      })
      i = i + 1

    else
      -- Substitution
      table.insert(diff.substitutions, {
        from = origWord,
        to = corrWord,
        position = i
      })
      i, j = i + 1, j + 1
    end
  end

  return diff
}
```

#### 1.5 Levenshtein Distance Helper

```lua
local function levenshtein(s1, s2)
  local len1, len2 = #s1, #s2
  local matrix = {}

  -- Initialize first column and row
  for i = 0, len1 do matrix[i] = {[0] = i} end
  for j = 0, len2 do matrix[0][j] = j end

  -- Fill matrix
  for i = 1, len1 do
    for j = 1, len2 do
      local cost = (s1:sub(i,i) == s2:sub(j,j)) and 0 or 1
      matrix[i][j] = math.min(
        matrix[i-1][j] + 1,      -- deletion
        matrix[i][j-1] + 1,      -- insertion
        matrix[i-1][j-1] + cost  -- substitution
      )
    end
  end

  return matrix[len1][len2]
end
```

### Phase 2: VoxCompose - Learning from Corrections

#### 2.1 Metadata File Scanner

```java
// New class: MetadataScanner.java
public class MetadataScanner {
  private static final Path VOICE_NOTES_DIR = Paths.get(
    System.getProperty("user.home"),
    "Documents",
    "VoiceNotes"
  );

  public List<CorrectionRecord> scanForCorrections() throws IOException {
    List<CorrectionRecord> corrections = new ArrayList<>();

    Files.walk(VOICE_NOTES_DIR)
      .filter(p -> p.toString().endsWith(".meta.json"))
      .forEach(metaFile -> {
        try {
          CorrectionRecord record = parseMetadata(metaFile);
          if (record != null && record.hasCorrection()) {
            corrections.add(record);
          }
        } catch (IOException e) {
          log.warn("Failed to parse metadata: " + metaFile, e);
        }
      });

    return corrections;
  }

  private CorrectionRecord parseMetadata(Path metaFile) throws IOException {
    String content = Files.readString(metaFile);
    JsonObject meta = JsonParser.parseString(content).getAsJsonObject();

    // Check if this metadata has a user correction
    if (!meta.has("transcript") || !meta.getAsJsonObject("transcript").has("corrected")) {
      return null;
    }

    JsonObject transcript = meta.getAsJsonObject("transcript");
    String original = transcript.get("original").getAsString();
    String corrected = transcript.get("corrected").getAsString();

    CorrectionRecord record = new CorrectionRecord();
    record.setRecordingId(metaFile.getFileName().toString().replace(".meta.json", ""));
    record.setOriginalText(original);
    record.setCorrectedText(corrected);
    record.setMetadataPath(metaFile);

    // Parse correction details if available
    if (meta.has("correction_details")) {
      JsonObject details = meta.getAsJsonObject("correction_details");
      record.setWordChanges(parseWordChanges(details));
      record.setCapitalizations(parseCapitalizations(details));
      record.setSubstitutions(parseSubstitutions(details));
    }

    // Parse user feedback
    if (meta.has("user_feedback")) {
      JsonObject feedback = meta.getAsJsonObject("user_feedback");
      record.setUserInitiated(feedback.get("user_initiated").getAsBoolean());
      record.setEditDistance(feedback.get("edit_distance").getAsInt());
      record.setEditRatio(feedback.get("edit_ratio").getAsDouble());
    }

    return record;
  }
}
```

#### 2.2 Learning from Explicit Corrections

```java
// In LearningService.java
public void learnFromExplicitCorrections() {
  MetadataScanner scanner = new MetadataScanner();
  List<CorrectionRecord> corrections = scanner.scanForCorrections();

  log.info("Found " + corrections.size() + " user corrections to learn from");

  for (CorrectionRecord record : corrections) {
    // User-initiated corrections have HIGHEST confidence
    double confidence = record.isUserInitiated() ? 1.0 : 0.8;

    // Learn word-level corrections
    for (WordChange change : record.getWordChanges()) {
      if (change.isCapitalization()) {
        profile.addCapitalization(
          change.getFrom().toLowerCase(),
          change.getTo(),
          confidence
        );
      } else if (change.isSubstitution()) {
        profile.addWordCorrection(
          change.getFrom(),
          change.getTo(),
          confidence
        );
      }
    }

    // Learn phrase patterns
    if (record.getEditRatio() < 0.3) {  // Only minor edits
      extractPhrasePatterns(record.getOriginalText(), record.getCorrectedText());
    }

    // Update vocabulary
    extractTechnicalTerms(record.getCorrectedText());
  }

  // Regenerate vocabulary files with learned corrections
  vocabularyGenerator.regenerateAllVocabularies(profile);

  log.info("Learning complete. Updated profile with " +
           profile.getWordCorrections().size() + " corrections");
}
```

#### 2.3 Phrase Pattern Extraction

```java
private void extractPhrasePatterns(String original, String corrected) {
  // Find common 2-5 word phrases that were corrected
  String[] origWords = original.split("\\s+");
  String[] corrWords = corrected.split("\\s+");

  // Use LCS (Longest Common Subsequence) to find differences
  List<PhraseChange> changes = lcsPhraseDiff(origWords, corrWords);

  for (PhraseChange change : changes) {
    if (change.getType() == ChangeType.INSERTION) {
      // User added words - might be common phrase completion
      String addedPhrase = String.join(" ", change.getWords());
      profile.recordPhraseCompletion(addedPhrase);
    } else if (change.getType() == ChangeType.SUBSTITUTION) {
      // User changed phrase - record as correction pattern
      String from = String.join(" ", change.getFromWords());
      String to = String.join(" ", change.getToWords());
      profile.addPhraseCorrection(from, to);
    }
  }
}
```

### Phase 3: Integration & Feedback

#### 3.1 Correction Statistics

```lua
-- New command: Show correction stats
local function showCorrectionStats()
  local metaFiles = findFiles("~/Documents/VoiceNotes/**/*.meta.json")
  local totalCorrections = 0
  local totalRecordings = 0
  local avgEditDistance = 0

  for _, metaPath in ipairs(metaFiles) do
    totalRecordings = totalRecordings + 1
    local meta = loadJsonFile(metaPath)

    if meta.transcript and meta.transcript.corrected then
      totalCorrections = totalCorrections + 1
      avgEditDistance = avgEditDistance + (meta.user_feedback.edit_distance or 0)
    end
  end

  avgEditDistance = totalCorrections > 0 and (avgEditDistance / totalCorrections) or 0

  local message = string.format([[
Correction Statistics
=====================
Total recordings:    %d
User corrections:    %d (%.1f%%)
Avg edit distance:   %.1f chars

Press OK to regenerate vocabulary from corrections.
]],
    totalRecordings,
    totalCorrections,
    (totalCorrections / totalRecordings * 100),
    avgEditDistance
  )

  hs.dialog.blockAlert("VoxCore Stats", message, "OK", "Cancel")
end

-- Bind to hotkey or menu item
hs.hotkey.bind({"cmd", "alt", "ctrl", "shift"}, "s", showCorrectionStats)
```

#### 3.2 VoxCompose Regeneration Trigger

```java
// CLI command: voxcompose --regenerate-from-corrections
public static void main(String[] args) {
  if (args.length > 0 && "--regenerate-from-corrections".equals(args[0])) {
    LearningService learner = new LearningService();
    learner.learnFromExplicitCorrections();
    System.out.println("Vocabulary regenerated from user corrections.");
    System.exit(0);
  }

  // ... normal refinement mode
}
```

---

## User Experience Flow

### Scenario 1: Simple Word Correction

```
User speaks: "add error handling to the database"
VoxCore transcribes: "add error handling to the database"
User edits: "Add error handling to the database connection"
User presses: Cmd+Alt+Ctrl+Shift+C

VoxCore saves:
{
  "original": "add error handling to the database",
  "corrected": "Add error handling to the database connection",
  "correction_details": {
    "capitalizations": [{"from": "add", "to": "Add"}],
    "insertions": [{"word": "connection", "position": 7}]
  }
}

VoxCompose learns:
- Capitalize sentence starts: "add" → "Add"
- Common phrase: "database connection" (not just "database")

Next time user says "add error handling":
- Whisper gets "Add" in INITIAL_PROMPT (capitalization hint)
- More likely to transcribe as "Add error handling to the database connection"
```

### Scenario 2: Technical Term Correction

```
User speaks: "refactor the API endpoint"
VoxCore transcribes: "refactor the api endpoint"
User edits: "Refactor the API endpoint"
User presses: Cmd+Alt+Ctrl+Shift+C

VoxCompose learns:
- "api" → "API" (capitalization pattern for acronym)
- Technical term: "API" (add to vocabulary)

Next recording:
- INITIAL_PROMPT includes "API"
- Whisper more likely to capitalize correctly
```

### Scenario 3: Phrase Completion

```
User speaks: "fix the race condition"
VoxCore transcribes: "fix the race condition"
User edits: "fix the race condition in the event handler"
User presses: Cmd+Alt+Ctrl+Shift+C

VoxCompose learns:
- Common phrase completion: "race condition" → "race condition in the event handler"
- Technical vocabulary: "event handler"

Future behavior:
- If "race condition" detected, suggest completion
- Add "event handler" to code domain vocabulary
```

---

## Advanced Features (Optional)

### 1. Correction Suggestions

Show user suggested corrections based on low confidence:

```lua
local function showCorrectionSuggestions(recordingId, lowConfSegments)
  if #lowConfSegments == 0 then return end

  local message = "Low confidence detected in:\n\n"
  for _, seg in ipairs(lowConfSegments) do
    message = message .. string.format('  "%s" (%.0f%%)\n', seg.text, seg.confidence * 100)
  end
  message = message .. "\nReview transcription?"

  local button = hs.dialog.blockAlert("VoxCore", message, "Review", "Ignore")
  if button == "Review" then
    -- Open correction workflow
    openCorrectionWorkflow(recordingId)
  end
end
```

### 2. Batch Correction UI

Allow users to review and correct multiple transcriptions at once:

```lua
-- Show list of recent transcriptions
-- User can select and correct in bulk
-- Useful for correcting patterns across multiple recordings
```

### 3. Correction Undo

```lua
-- Allow user to undo last correction
-- Remove from metadata file
-- Useful if user accidentally pressed correction hotkey
```

---

## Success Metrics

1. **Correction adoption rate:** % of users who use the correction hotkey
   - Target: >20% of active users

2. **Learning velocity:** How fast corrections improve accuracy
   - Measure: Reduction in edit distance over time
   - Target: 10% improvement per 100 corrections

3. **Correction frequency:** How often users correct transcriptions
   - Baseline: Unknown
   - Target: <5% of transcriptions need correction

4. **Vocabulary growth:** Number of new terms learned per week
   - Target: 10-20 new terms/week for active users

---

## Risks & Mitigations

### Risk 1: Accidental Corrections
**Problem:** User presses hotkey by accident, wrong text gets saved

**Mitigation:**
- Show confirmation dialog with diff preview
- Allow undo of last correction
- Only accept corrections with edit distance >2 chars

### Risk 2: Bad Corrections
**Problem:** User makes typos in corrected version, VoxCompose learns wrong patterns

**Mitigation:**
- Confidence threshold: Only learn corrections that appear 2+ times
- Outlier detection: Flag corrections with very high edit ratios
- User can review learned corrections in VoxCompose profile

### Risk 3: Clipboard Conflicts
**Problem:** User's clipboard is overwritten, loses important data

**Mitigation:**
- Correction hotkey doesn't modify clipboard, only reads
- Save previous clipboard contents and restore after
- Make correction hotkey opt-in (disabled by default)

---

## Open Questions

1. **Should corrections be bidirectional?**
   - Can VoxCompose suggest corrections to the user?
   - E.g., "Did you mean 'API' instead of 'api'?"

2. **How to handle multi-app corrections?**
   - User corrects in one app, should it apply to all domains?
   - Or only to the specific domain (code, chat, email)?

3. **Correction expiry?**
   - Should old corrections be aged out or weighted less?
   - E.g., corrections from >6 months ago might be less relevant

4. **Collaborative corrections?**
   - Should users be able to share corrections with others? (opt-in)
   - Community-learned patterns for common technical terms?

---

## Implementation Timeline

**Prerequisite:** Phase 1-2 of accuracy improvement plan must be complete

**Phase 1: Core Correction Capture (2 weeks)**
- [ ] Hotkey binding and validation
- [ ] Metadata file writing
- [ ] Diff calculation (Levenshtein + detailed)
- [ ] User feedback alerts

**Phase 2: VoxCompose Integration (1 week)**
- [ ] Metadata scanner
- [ ] Correction learning logic
- [ ] Vocabulary regeneration
- [ ] CLI command for manual regeneration

**Phase 3: Polish & Testing (1 week)**
- [ ] Correction statistics UI
- [ ] Error handling and edge cases
- [ ] Documentation and user guide
- [ ] Beta testing with users

**Total:** 4 weeks (1 developer)

---

## Conclusion

**Manual correction is a high-value feature** that closes the learning loop between user speech and transcription accuracy. By explicitly capturing user edits, we can:

1. **Learn faster** - Direct user feedback vs inferred patterns
2. **Build confidence** - User-initiated corrections have highest reliability
3. **Improve accuracy** - Learned patterns feed back into vocabulary generation
4. **Empower users** - Users actively teach VoxCore their speech

**Recommended architecture:**
- ✅ VoxCore handles hotkey and metadata capture (stateless)
- ✅ VoxCompose handles learning and vocabulary generation (stateful)
- ✅ No new plugin needed
- ✅ Reuses existing metadata infrastructure

**Status:** Ready for implementation after Phase 1-2 of accuracy plan is complete.

---

**Document Version:** 1.0
**Author:** Claude Code
**Date:** 2025-12-04
