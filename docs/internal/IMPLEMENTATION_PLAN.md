# VoxCore Java Migration - Detailed Implementation Plan
## Complete Technical Specification

**Version**: 1.0  
**Target Date**: 2025-10-27 (2 weeks)  
**Status**: Ready to Start

---

## 📋 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Phase 1: Remove Duplication](#phase-1-remove-duplication)
3. [Phase 2: Whisper Orchestration Service](#phase-2-whisper-orchestration-service)
4. [Phase 3: Lua Simplification](#phase-3-lua-simplification)
5. [Testing Strategy](#testing-strategy)
6. [Rollout Plan](#rollout-plan)
7. [Success Criteria](#success-criteria)

---

## 🏗 Architecture Overview

### Current State
```
Lua (push_to_talk.lua) 2,063 lines
├── Hotkey handling (must stay)
├── UI indicators (must stay)
├── Audio recording (679 lines) → Should be Java
├── Whisper execution (400 lines) → Should be Java
├── Text processing (200 lines) → DUPLICATE (already in Java!)
└── Logging/fixtures (142 lines) → Should be Java
```

### Target State
```
Lua (push_to_talk.lua) ~600 lines
├── Hotkey handling
├── UI indicators
└── Thin wrappers to Java services

Java Services ~12,000 lines
├── WhisperOrchestrationService
├── AudioRecordingService
├── TextProcessingPipeline (existing, enhanced)
├── LoggingService
└── TestFixtureService
```

### Service Communication
```
Hammerspoon (Lua)
    ↓ HTTP/WebSocket
PTTServiceDaemon (Java)
    ├→ WhisperOrchestrationService
    ├→ AudioRecordingService
    ├→ TextProcessingPipeline
    └→ LoggingService
```

---

## 🔥 Phase 1: Remove Duplication (Day 1)

### Objective
Eliminate ~200 lines of duplicated logic between Lua and Java

### Tasks

#### 1.1 Remove reflowFromSegments() from Lua
**File**: `hammerspoon/push_to_talk.lua`  
**Lines to remove**: 690-767 (78 lines)

**Current Lua Function:**
```lua
local function reflowFromSegments(segments)
    -- Gap-based newline insertion
    -- Sentence boundary detection
    -- Punctuation normalization
    -- Returns processed text
end
```

**Java Equivalent (already exists):**
```java
// whisper-post-processor/src/main/java/com/cliffmin/whisper/processors/ReflowProcessor.java
public class ReflowProcessor {
    public String process(String text) { ... }
}
```

**Gap Analysis:**
- Lua version works on segment arrays with timestamps
- Java version works on plain text
- Need to convert segments → text before calling Java

**Implementation Steps:**

1. **Extract segment text in Lua:**
```lua
local function extractTextFromSegments(segments)
    local parts = {}
    for _, seg in ipairs(segments) do
        table.insert(parts, seg.text or "")
    end
    return table.concat(parts, " ")
end
```

2. **Call Java processor:**
```lua
local function reflowFromSegments(segments)
    local rawText = extractTextFromSegments(segments)
    return applyJavaPostProcessor(rawText)  -- Already exists!
end
```

3. **Test coverage:**
- Test with existing fixtures
- Compare old vs new output
- Verify no regressions

**Validation:**
```bash
# Run existing tests
cd tests/integration
bash reflow_on_latest_samples.sh

# Compare output
diff old_output.txt new_output.txt
```

---

#### 1.2 Remove applyDictionaryReplacements() from Lua
**File**: `hammerspoon/push_to_talk.lua`  
**Lines to remove**: 365-385 (21 lines)

**Analysis:**
- This is already handled by Java's `DictionaryProcessor`
- Called as part of `applyJavaPostProcessor()`
- Lua version is dead code if Java is always called

**Implementation:**
1. Verify Java processor includes dictionary: ✅ (already does)
2. Search for Lua function calls: `grep "applyDictionaryReplacements" *.lua`
3. If no direct calls, safely delete
4. If called, replace with Java call

**Testing:**
```java
// Verify in Java tests:
@Test
void dictionaryProcessorShouldBeInPipeline() {
    ProcessingPipeline pipeline = new ProcessingPipeline();
    // Assert DictionaryProcessor is included
}
```

---

### Phase 1 Deliverables
- [ ] `reflowFromSegments()` deleted from Lua
- [ ] `applyDictionaryReplacements()` deleted from Lua
- [ ] All tests pass
- [ ] Git commit: "refactor: remove duplicate text processing logic from Lua"
- [ ] Lua LOC: 2,063 → 1,963 (-100 lines)

**Time estimate**: 2-4 hours  
**Difficulty**: ⭐ Easy

---

## 🚀 Phase 2: Whisper Orchestration Service (Days 2-8)

### Objective
Create comprehensive Java service for all Whisper operations

### Architecture

```java
package com.cliffmin.whisper.service;

public class WhisperOrchestrationService {
    private final Configuration config;
    private final AudioProcessor audioProcessor;
    private final WhisperProcessManager processManager;
    private final JsonParser jsonParser;
    
    // Main API
    public CompletableFuture<TranscriptionResult> transcribe(
        Path audioPath, 
        TranscriptionOptions options
    );
    
    // Internal methods
    private String selectModel(double durationSeconds);
    private List<String> buildCommand(Path audio, String model);
    private Process executeWhisper(List<String> command, Duration timeout);
    private TranscriptionResult parseOutput(Path jsonFile);
}
```

---

### 2.1 Create Core Classes (Day 2-3)

#### File: `TranscriptionOptions.java`
```java
package com.cliffmin.whisper.service;

public class TranscriptionOptions {
    private String model;           // Optional: override model selection
    private String language;        // Default: "en"
    private Duration timeout;       // Default: 120s
    private boolean preprocess;     // Apply audio preprocessing
    private Map<String, String> overrides;  // CLI arg overrides
    
    // Builder pattern for construction
    public static class Builder { ... }
}
```

#### File: `TranscriptionResult.java`
```java
package com.cliffmin.whisper.service;

public class TranscriptionResult {
    private final String text;
    private final List<Segment> segments;
    private final double duration;
    private final Map<String, Object> metadata;
    private final long processingTimeMs;
    
    // Immutable data class
    public static class Segment {
        private final double start;
        private final double end;
        private final String text;
    }
}
```

#### File: `WhisperProcessManager.java`
```java
package com.cliffmin.whisper.service;

class WhisperProcessManager {
    // Handles low-level process execution
    public ProcessResult execute(List<String> command, Duration timeout) 
        throws WhisperExecutionException;
    
    // Captures stdout, stderr, exit code
    private void consumeStreams(Process process);
    
    // Kills process on timeout
    private void enforceTimeout(Process process, Duration timeout);
}
```

---

### 2.2 Model Selection Logic (Day 3)

#### Method: `selectModel()`

**Requirements:**
- Duration < 21s → `base.en`
- Duration >= 21s → `medium.en`
- Config override takes precedence
- Fallback to `base.en` if unknown

**Implementation:**
```java
private String selectModel(double durationSeconds) {
    // 1. Check explicit config override
    if (config.hasExplicitModel()) {
        return config.getWhisperModel();
    }
    
    // 2. Check dynamic model selection enabled
    if (!config.isDynamicModelEnabled()) {
        return config.getWhisperModel(); // Use default
    }
    
    // 3. Select based on duration
    double threshold = config.getModelSwitchThreshold(); // 21.0
    
    if (durationSeconds <= threshold) {
        return config.getShortModel(); // base.en
    } else {
        return config.getLongModel(); // medium.en
    }
}
```

**Testing:**
```java
@Test
void shouldSelectBaseForShortAudio() {
    Configuration config = new Configuration();
    WhisperOrchestrationService service = new WhisperOrchestrationService(config);
    
    String model = service.selectModel(15.0); // 15 seconds
    assertEquals("base.en", model);
}

@Test
void shouldSelectMediumForLongAudio() {
    String model = service.selectModel(30.0); // 30 seconds
    assertEquals("medium.en", model);
}

@Test
void shouldRespectExplicitOverride() {
    Configuration config = Configuration.builder()
        .whisperModel("large-v2")
        .build();
    WhisperOrchestrationService service = new WhisperOrchestrationService(config);
    
    String model = service.selectModel(15.0);
    assertEquals("large-v2", model); // Override respected
}
```

---

### 2.3 Command Construction (Day 4)

#### Method: `buildCommand()`

**Whisper-cpp command structure:**
```bash
whisper-cpp \
    -m /path/to/model.bin \
    -l en \
    -oj \
    -of /output/base \
    --beam-size 3 \
    -t 4 \
    -p 1 \
    /path/to/audio.wav
```

**Implementation:**
```java
private List<String> buildCommand(Path audioPath, String model, TranscriptionOptions options) {
    List<String> command = new ArrayList<>();
    
    // 1. Executable
    String whisperPath = detectWhisperExecutable();
    command.add(whisperPath);
    
    // 2. Model
    Path modelPath = resolveModelPath(model);
    command.add("-m");
    command.add(modelPath.toString());
    
    // 3. Language
    command.add("-l");
    command.add(options.getLanguage());
    
    // 4. Output format
    command.add("-oj");  // JSON output
    command.add("-of");
    command.add(audioPath.toString().replace(".wav", ""));
    
    // 5. Performance options
    command.add("--beam-size");
    command.add(String.valueOf(config.getBeamSize()));
    command.add("-t");
    command.add(String.valueOf(config.getThreads()));
    
    // 6. Audio file (last!)
    command.add(audioPath.toString());
    
    return command;
}

private String detectWhisperExecutable() {
    // Check in order: whisper-cli, whisper-cpp, whisper
    String[] candidates = {
        "/opt/homebrew/bin/whisper-cli",
        "/opt/homebrew/bin/whisper-cpp",
        "/usr/local/bin/whisper-cpp",
        System.getProperty("user.home") + "/.local/bin/whisper"
    };
    
    for (String path : candidates) {
        if (Files.exists(Paths.get(path))) {
            return path;
        }
    }
    
    throw new WhisperNotFoundException("No whisper executable found in standard locations");
}

private Path resolveModelPath(String modelName) {
    // /opt/homebrew/share/whisper-cpp/ggml-{model}.bin
    String basePath = "/opt/homebrew/share/whisper-cpp";
    String filename = String.format("ggml-%s.bin", modelName.replace(".en", ""));
    
    Path modelPath = Paths.get(basePath, filename);
    if (!Files.exists(modelPath)) {
        throw new ModelNotFoundException("Model not found: " + modelPath);
    }
    
    return modelPath;
}
```

**Testing:**
```java
@Test
void shouldBuildValidWhisperCppCommand() {
    Path audio = Paths.get("/tmp/test.wav");
    TranscriptionOptions options = TranscriptionOptions.builder()
        .language("en")
        .build();
    
    List<String> command = service.buildCommand(audio, "base.en", options);
    
    // Verify structure
    assertTrue(command.get(0).endsWith("whisper-cpp"));
    assertTrue(command.contains("-m"));
    assertTrue(command.contains("-l"));
    assertTrue(command.contains("en"));
    assertEquals(audio.toString(), command.get(command.size() - 1));
}
```

---

### 2.4 Process Execution (Day 5)

#### Method: `executeWhisper()`

**Key challenges:**
- Read stdout AND stderr without deadlocking
- Enforce timeout and kill process
- Handle non-zero exit codes
- Capture output for debugging

**Implementation:**
```java
private ProcessResult executeWhisper(List<String> command, Duration timeout) 
    throws WhisperExecutionException {
    
    ProcessBuilder pb = new ProcessBuilder(command);
    pb.redirectErrorStream(false); // Keep stdout/stderr separate
    
    try {
        Process process = pb.start();
        
        // Start stream consumers (CRITICAL: prevents deadlock!)
        CompletableFuture<String> stdoutFuture = CompletableFuture.supplyAsync(() ->
            consumeStream(process.getInputStream())
        );
        CompletableFuture<String> stderrFuture = CompletableFuture.supplyAsync(() ->
            consumeStream(process.getErrorStream())
        );
        
        // Wait with timeout
        boolean finished = process.waitFor(timeout.toSeconds(), TimeUnit.SECONDS);
        
        if (!finished) {
            process.destroyForcibly();
            throw new WhisperTimeoutException(
                "Whisper process timed out after " + timeout.toSeconds() + "s"
            );
        }
        
        // Get outputs
        String stdout = stdoutFuture.get(5, TimeUnit.SECONDS);
        String stderr = stderrFuture.get(5, TimeUnit.SECONDS);
        int exitCode = process.exitValue();
        
        if (exitCode != 0) {
            throw new WhisperExecutionException(
                "Whisper exited with code " + exitCode + ": " + stderr
            );
        }
        
        return new ProcessResult(stdout, stderr, exitCode);
        
    } catch (InterruptedException e) {
        Thread.currentThread().interrupt();
        throw new WhisperExecutionException("Interrupted during transcription", e);
    } catch (Exception e) {
        throw new WhisperExecutionException("Failed to execute whisper", e);
    }
}

private String consumeStream(InputStream stream) {
    try (BufferedReader reader = new BufferedReader(
            new InputStreamReader(stream, StandardCharsets.UTF_8))) {
        return reader.lines().collect(Collectors.joining("\n"));
    } catch (IOException e) {
        return "";
    }
}
```

**Testing:**
```java
@Test
void shouldHandleProcessTimeout() throws Exception {
    // Create a mock long-running process
    List<String> command = List.of("sleep", "10");
    Duration timeout = Duration.ofSeconds(1);
    
    assertThrows(WhisperTimeoutException.class, () -> {
        service.executeWhisper(command, timeout);
    });
}

@Test
void shouldHandleNonZeroExitCode() {
    List<String> command = List.of("false"); // Exits with 1
    
    assertThrows(WhisperExecutionException.class, () -> {
        service.executeWhisper(command, Duration.ofSeconds(5));
    });
}
```

---

### 2.5 JSON Parsing (Day 6)

#### Method: `parseOutput()`

**JSON Format Differences:**

**Whisper-cpp format:**
```json
{
  "systeminfo": "...",
  "model": { ... },
  "params": { ... },
  "result": { "language": "en" },
  "transcription": [
    {
      "timestamps": { "from": "00:00:00,000", "to": "00:00:05,000" },
      "offsets": { "from": 0, "to": 5000 },
      "text": " Hello world"
    }
  ]
}
```

**OpenAI Whisper format:**
```json
{
  "text": "Hello world",
  "segments": [
    {
      "id": 0,
      "start": 0.0,
      "end": 5.0,
      "text": " Hello world"
    }
  ],
  "language": "en"
}
```

**Unified Parser:**
```java
private TranscriptionResult parseOutput(Path jsonFile) throws IOException {
    String jsonContent = Files.readString(jsonFile);
    JsonObject root = JsonParser.parseString(jsonContent).getAsJsonObject();
    
    // Detect format
    boolean isWhisperCpp = root.has("transcription");
    boolean isOpenAI = root.has("segments");
    
    if (isWhisperCpp) {
        return parseWhisperCppFormat(root);
    } else if (isOpenAI) {
        return parseOpenAIFormat(root);
    } else {
        throw new InvalidJsonException("Unknown JSON format");
    }
}

private TranscriptionResult parseWhisperCppFormat(JsonObject root) {
    JsonArray transcription = root.getAsJsonArray("transcription");
    
    List<Segment> segments = new ArrayList<>();
    StringBuilder fullText = new StringBuilder();
    
    for (JsonElement elem : transcription) {
        JsonObject seg = elem.getAsJsonObject();
        JsonObject offsets = seg.getAsJsonObject("offsets");
        
        double start = offsets.get("from").getAsDouble() / 1000.0;
        double end = offsets.get("to").getAsDouble() / 1000.0;
        String text = seg.get("text").getAsString().trim();
        
        segments.add(new Segment(start, end, text));
        fullText.append(text).append(" ");
    }
    
    return new TranscriptionResult(
        fullText.toString().trim(),
        segments,
        /* metadata */ extractMetadata(root)
    );
}

private TranscriptionResult parseOpenAIFormat(JsonObject root) {
    // Similar but for OpenAI format
    String text = root.get("text").getAsString();
    JsonArray segs = root.getAsJsonArray("segments");
    
    List<Segment> segments = new ArrayList<>();
    for (JsonElement elem : segs) {
        JsonObject seg = elem.getAsJsonObject();
        segments.add(new Segment(
            seg.get("start").getAsDouble(),
            seg.get("end").getAsDouble(),
            seg.get("text").getAsString()
        ));
    }
    
    return new TranscriptionResult(text, segments, extractMetadata(root));
}
```

**Testing:**
```java
@Test
void shouldParseWhisperCppJson() throws Exception {
    Path jsonFile = Paths.get("src/test/resources/whisper-cpp-output.json");
    TranscriptionResult result = service.parseOutput(jsonFile);
    
    assertNotNull(result.getText());
    assertFalse(result.getSegments().isEmpty());
    assertEquals("en", result.getMetadata().get("language"));
}

@Test
void shouldParseOpenAIWhisperJson() throws Exception {
    Path jsonFile = Paths.get("src/test/resources/openai-whisper-output.json");
    TranscriptionResult result = service.parseOutput(jsonFile);
    
    assertNotNull(result.getText());
    assertFalse(result.getSegments().isEmpty());
}

@Test
void shouldHandleMalformedJson() {
    Path jsonFile = Paths.get("src/test/resources/invalid.json");
    
    assertThrows(InvalidJsonException.class, () -> {
        service.parseOutput(jsonFile);
    });
}
```

---

### 2.6 Main Transcribe Method (Day 7)

#### Method: `transcribe()` - Putting it all together

```java
public CompletableFuture<TranscriptionResult> transcribe(
    Path audioPath, 
    TranscriptionOptions options
) {
    return CompletableFuture.supplyAsync(() -> {
        try {
            // 1. Validate audio file
            if (!audioProcessor.validateForWhisper(audioPath)) {
                throw new InvalidAudioException("Invalid audio file: " + audioPath);
            }
            
            // 2. Get audio duration for model selection
            double duration = audioProcessor.getDuration(audioPath);
            
            // 3. Preprocess if needed
            Path processedAudio = audioPath;
            if (options.isPreprocess() && duration >= config.getPreprocessMinSec()) {
                processedAudio = audioProcessor.normalize(audioPath);
            }
            
            // 4. Select model
            String model = options.getModel() != null 
                ? options.getModel() 
                : selectModel(duration);
            
            log.info("Transcribing {} ({}s) with model {}", 
                audioPath.getFileName(), duration, model);
            
            // 5. Build command
            List<String> command = buildCommand(processedAudio, model, options);
            
            // 6. Execute whisper
            long startTime = System.currentTimeMillis();
            ProcessResult result = processManager.execute(command, options.getTimeout());
            long elapsed = System.currentTimeMillis() - startTime;
            
            // 7. Parse output JSON
            Path jsonOutput = findOutputJson(processedAudio);
            TranscriptionResult transcription = parseOutput(jsonOutput);
            
            // 8. Add timing metadata
            transcription.getMetadata().put("processing_time_ms", elapsed);
            transcription.getMetadata().put("model_used", model);
            transcription.getMetadata().put("audio_duration_sec", duration);
            
            log.info("Transcription complete in {}ms", elapsed);
            
            return transcription;
            
        } catch (Exception e) {
            log.error("Transcription failed for {}", audioPath, e);
            throw new TranscriptionException("Failed to transcribe", e);
        }
    }, executorService);
}

private Path findOutputJson(Path audioPath) throws IOException {
    // Whisper outputs to same directory with .json extension
    String baseName = audioPath.getFileName().toString().replace(".wav", "");
    Path jsonPath = audioPath.getParent().resolve(baseName + ".json");
    
    if (!Files.exists(jsonPath)) {
        throw new FileNotFoundException("Whisper output not found: " + jsonPath);
    }
    
    return jsonPath;
}
```

**Integration Test:**
```java
@Test
void shouldTranscribeEndToEnd() throws Exception {
    // Use a real audio file from test resources
    Path audioFile = Paths.get("src/test/resources/test-audio-5s.wav");
    
    TranscriptionOptions options = TranscriptionOptions.builder()
        .language("en")
        .timeout(Duration.ofSeconds(30))
        .build();
    
    CompletableFuture<TranscriptionResult> future = service.transcribe(audioFile, options);
    TranscriptionResult result = future.get(60, TimeUnit.SECONDS);
    
    assertNotNull(result);
    assertNotNull(result.getText());
    assertFalse(result.getText().isEmpty());
    assertTrue(result.getProcessingTimeMs() > 0);
    assertTrue(result.getProcessingTimeMs() < 10000); // Should be fast
}
```

---

### 2.7 Exception Hierarchy (Day 7)

```java
// Base exception
public class WhisperException extends RuntimeException {
    public WhisperException(String message) { super(message); }
    public WhisperException(String message, Throwable cause) { super(message, cause); }
}

// Specific exceptions
public class WhisperNotFoundException extends WhisperException { }
public class ModelNotFoundException extends WhisperException { }
public class WhisperTimeoutException extends WhisperException { }
public class WhisperExecutionException extends WhisperException { }
public class InvalidAudioException extends WhisperException { }
public class InvalidJsonException extends WhisperException { }
public class TranscriptionException extends WhisperException { }
```

---

### 2.8 Add HTTP Endpoint to Daemon (Day 8)

**File**: `PTTServiceDaemon.java`

```java
private void addTranscribeEndpointAsync(RoutingHandler router) {
    router.post("/transcribe", exchange -> {
        try {
            // Parse multipart request for audio file
            FormData formData = exchange.getAttachment(FormDataParser.FORM_DATA);
            FormData.FormValue audioFile = formData.getFirst("audio");
            
            // Save to temp file
            Path tempAudio = Files.createTempFile("ptt_", ".wav");
            Files.copy(audioFile.getFileItem().getInputStream(), tempAudio, 
                StandardCopyOption.REPLACE_EXISTING);
            
            // Parse options from request
            TranscriptionOptions options = parseOptions(formData);
            
            // Transcribe asynchronously
            whisperService.transcribe(tempAudio, options)
                .thenAccept(result -> {
                    // Send response
                    exchange.getResponseHeaders().put(Headers.CONTENT_TYPE, "application/json");
                    exchange.getResponseSender().send(gson.toJson(result));
                    
                    // Cleanup
                    Files.deleteIfExists(tempAudio);
                })
                .exceptionally(error -> {
                    exchange.setStatusCode(500);
                    exchange.getResponseSender().send(
                        gson.toJson(Map.of("error", error.getMessage()))
                    );
                    return null;
                });
                
        } catch (Exception e) {
            handleError(exchange, e);
        }
    });
}
```

---

### Phase 2 Deliverables
- [ ] `WhisperOrchestrationService.java` complete
- [ ] All supporting classes created
- [ ] Unit tests >80% coverage
- [ ] Integration test passes
- [ ] HTTP endpoint added to daemon
- [ ] Documentation updated
- [ ] Git commit: "feat: add WhisperOrchestrationService with full transcription pipeline"
- [ ] Java LOC: +500 lines
- [ ] Test LOC: +300 lines

**Time estimate**: 20-30 hours (6-8 days)  
**Difficulty**: ⭐⭐⭐⭐ Hard

---

## 🔧 Phase 3: Lua Simplification (Day 9-10)

### Objective
Replace 400 lines of Lua Whisper logic with simple service calls

### 3.1 Update Lua to Call Java Service

**Before** (400+ lines):
```lua
local function runWhisper(audioPath)
    -- Complex model selection
    -- Command construction
    -- Process management
    -- JSON parsing
    -- Error handling
end
```

**After** (20 lines):
```lua
local function runWhisper(audioPath)
    local url = "http://localhost:8080/transcribe"
    local response = http.post(url, {audio = audioPath})
    
    if response.status == 200 then
        local result = json.decode(response.body)
        return result.text, result.segments
    else
        log.e("Transcription failed: " .. response.body)
        return nil, nil
    end
end
```

### 3.2 Update java_bridge.lua

**File**: `hammerspoon/java_bridge.lua`

Add transcription method:
```lua
function M.transcribe(audioPath, options)
    local url = SERVICE_URL .. "/transcribe"
    
    -- Build multipart form data
    local boundary = "----" .. os.time()
    local body = buildMultipart(audioPath, options, boundary)
    
    local response = http.post(url, {
        headers = {
            ["Content-Type"] = "multipart/form-data; boundary=" .. boundary
        },
        body = body
    })
    
    if response.status ~= 200 then
        error("Transcription failed: " .. response.body)
    end
    
    return json.decode(response.body)
end
```

### 3.3 Add Fallback Logic

```lua
local function runWhisperWithFallback(audioPath)
    -- Try Java service first
    local ok, result = pcall(function()
        return javaBridge.transcribe(audioPath)
    end)
    
    if ok and result then
        return result.text, result.segments
    end
    
    -- Fallback to direct CLI if service unavailable
    log.w("Java service unavailable, falling back to CLI")
    return runWhisperCLI(audioPath)  -- Keep old function as backup
end
```

### Phase 3 Deliverables
- [ ] Lua simplified to <30 lines for Whisper
- [ ] Java service integration tested
- [ ] Fallback mechanism works
- [ ] All existing features still functional
- [ ] Git commit: "refactor: simplify Lua to call WhisperOrchestrationService"
- [ ] Lua LOC: 1,963 → 1,600 (-363 lines)

**Time estimate**: 4-6 hours  
**Difficulty**: ⭐⭐ Medium

---

## 🧪 Testing Strategy

### Unit Tests (Java)
```
whisper-post-processor/src/test/java/
└── com/cliffmin/whisper/service/
    ├── WhisperOrchestrationServiceTest.java
    ├── WhisperProcessManagerTest.java
    ├── TranscriptionOptionsTest.java
    └── JsonParserTest.java
```

**Coverage Target**: >80%

**Key Tests:**
- Model selection logic (all branches)
- Command construction (valid/invalid)
- Process execution (success/failure/timeout)
- JSON parsing (both formats)
- Error handling (all exception types)

### Integration Tests
```java
@Test
@Tag("integration")
void shouldTranscribeRealAudio() {
    // End-to-end test with real whisper-cpp
    // Uses actual audio files
    // Verifies complete flow
}
```

### Regression Tests
```bash
# Before/after comparison
bash tests/integration/compare_outputs.sh
```

### Performance Tests
```java
@Test
void shouldTranscribeIn3Seconds() {
    Path audio = createTestAudio(5.0); // 5s audio
    
    long start = System.currentTimeMillis();
    TranscriptionResult result = service.transcribe(audio).get();
    long elapsed = System.currentTimeMillis() - start;
    
    assertTrue(elapsed < 3000, "Should transcribe in <3s");
}
```

---

## 🚀 Rollout Plan

### Week 1: Development
- Day 1: Phase 1 (duplication removal)
- Days 2-8: Phase 2 (Java service)

### Week 2: Integration & Testing
- Days 9-10: Phase 3 (Lua simplification)
- Days 11-12: Testing & bug fixes
- Days 13-14: Documentation & cleanup

### Deployment Strategy
1. **Feature Flag**: Add `USE_JAVA_WHISPER_SERVICE` config
2. **Gradual Rollout**: Default to old Lua, opt-in to Java
3. **Monitor**: Check logs for errors
4. **Full Switchover**: After 3 days stable
5. **Cleanup**: Remove old Lua code after 1 week

---

## ✅ Success Criteria

### Functional Requirements
- [ ] All existing transcription features work
- [ ] whisper-cpp supported
- [ ] openai-whisper supported
- [ ] Model selection automatic
- [ ] Timeouts enforced
- [ ] Errors handled gracefully
- [ ] JSON parsing works for both formats

### Performance Requirements
- [ ] <3s for 5s audio
- [ ] <10s for 30s audio
- [ ] <100ms overhead vs direct CLI
- [ ] No memory leaks

### Code Quality
- [ ] Test coverage >80%
- [ ] No duplicate logic
- [ ] Clear error messages
- [ ] Comprehensive logging
- [ ] JavaDoc complete

### Documentation
- [ ] README updated
- [ ] CHANGELOG.md entry
- [ ] Architecture diagrams
- [ ] Migration guide

---

## 📊 Metrics

### Before Migration
- Lua LOC: 2,063
- Java LOC: ~8,000
- Duplicate logic: ~200 lines
- Process spawns per transcription: 1-2
- Test coverage: ~60%

### After Migration
- Lua LOC: ~600 (-71%)
- Java LOC: ~12,000 (+50%)
- Duplicate logic: 0 (-100%)
- Process spawns: 0 (via daemon)
- Test coverage: >80%

### Performance Impact
- Latency: -50ms (no subprocess)
- Memory: -30% (connection pooling)
- CPU: Similar or better

---

## 🔧 Tools & Setup

### Development Environment
```bash
# Java 17+
java -version

# Gradle
./gradlew --version

# Whisper (for testing)
whisper-cpp --version

# IDE
# IntelliJ IDEA recommended
```

### Running Tests
```bash
# Unit tests only
./gradlew test

# Integration tests
./gradlew integrationTest

# All tests
./gradlew clean build

# With coverage
./gradlew jacocoTestReport
open build/reports/jacoco/test/html/index.html
```

### Running the Service
```bash
# Start daemon
java -jar whisper-post-processor/build/libs/whisper-post-processor.jar daemon

# Test endpoint
curl -X POST http://localhost:8080/transcribe \
  -F "audio=@test.wav" \
  -F "language=en"
```

---

## 📝 Git Workflow

### Branch Strategy
```bash
git checkout -b refactor/java-whisper-service
```

### Commit Messages
```
feat: add WhisperOrchestrationService
refactor: remove duplicate reflow logic from Lua
test: add integration tests for transcription
docs: update architecture diagrams
fix: handle JSON parsing edge cases
```

### Pull Request
- Title: "Migrate Whisper orchestration to Java service"
- Description: Link to this implementation plan
- Checklist: All success criteria
- Reviewers: Self-review first!

---

## 🎯 Next Steps

1. Read MOTIVATION.md (understand WHY)
2. Read LEARNING_GUIDE.md (understand HOW)
3. Read this file (understand WHAT)
4. Create `MY_LEARNING_LOG.md`
5. Start Phase 1!

**Ready to begin? Let's build something great! 💪**
