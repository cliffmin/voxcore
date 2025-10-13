# VoxCore Java Migration - Learning Guide
## Your Journey to Restore Your Coding Skills

**Duration**: 2 weeks (10-15 hours/week)  
**Difficulty**: Intermediate to Advanced  
**Goal**: Migrate complex Lua logic to Java while rebuilding your coding confidence

---

## 🎯 Learning Objectives

By the end of this refactor, you will:
- ✅ Design and implement a Java service architecture from scratch
- ✅ Master Java process management and I/O
- ✅ Build testable, maintainable code without AI assistance
- ✅ Debug complex issues independently
- ✅ Understand the trade-offs in architectural decisions

---

## 📚 Phase 1: Remove Duplication (Day 1)
**Goal**: Build momentum with a quick win  
**Estimated Time**: 2-4 hours  
**Difficulty**: ⭐ Easy

### What You'll Learn:
- How to identify duplicate logic across languages
- Refactoring techniques for removing duplication
- Testing to ensure behavior doesn't change

### Your Tasks:

#### Task 1.1: Analyze the Duplication
**Location**: `hammerspoon/push_to_talk.lua` lines 690-767

**Questions to answer yourself:**
- What does `reflowFromSegments()` do?
- Is there already a Java equivalent?
- How is Lua currently calling the Java code?
- What would break if you removed the Lua version?

**Hint**: Look at `whisper-post-processor/src/main/java/com/cliffmin/whisper/processors/ReflowProcessor.java`

**Don't look yet**: Can you figure out the gap between Lua and Java versions?

---

#### Task 1.2: Remove Lua's reflowFromSegments()
**Challenge**: Make Lua call Java's ReflowProcessor instead

**Questions to solve:**
- How does Lua currently call Java code? (Check `applyJavaPostProcessor()`)
- What input format does Java expect?
- What output format does Lua need?
- How do you handle errors if Java fails?

**Test Strategy** (write these tests first!):
1. Test with same input before/after refactor
2. Verify output is identical
3. Test with edge cases (empty input, special characters)

**Success Criteria**:
- [ ] Lua version deleted
- [ ] Tests pass
- [ ] Behavior unchanged
- [ ] Performance same or better

---

#### Task 1.3: Remove applyDictionaryReplacements() from Lua
**Location**: Lines 365-385

**Challenge**: This is already in Java - why does Lua still have it?

**Questions:**
- Is Lua's version different from Java's?
- When is each version called?
- Can you just delete the Lua version?

**Gotcha**: Check if anything actually calls the Lua version!

```lua
-- Search for usages:
-- grep -n "applyDictionaryReplacements" hammerspoon/push_to_talk.lua
```

**Success Criteria**:
- [ ] Lua version deleted
- [ ] Nothing breaks
- [ ] Tests confirm dictionary still works

---

### Phase 1 Checkpoint:
**Before moving on, ask yourself:**
- Did I understand every line I changed?
- Did I write tests BEFORE changing code?
- Can I explain why duplication was bad?
- Did I resist asking AI to write the code?

**Estimated LOC removed**: ~100 lines of Lua

---

## 🔥 Phase 2: Whisper Orchestration Service (Days 2-8)
**Goal**: Master complex Java service design  
**Estimated Time**: 20-30 hours  
**Difficulty**: ⭐⭐⭐⭐ Hard (This is the main learning!)

### What You'll Learn:
- Process management in Java
- Async programming with CompletableFuture
- Error handling and timeouts
- JSON parsing and validation
- Service design patterns
- Test-driven development for complex logic

---

### Day 2: Design Phase (Research & Planning)
**Time**: 2-3 hours  
**No coding yet!**

#### Task 2.1: Understand Current Whisper Logic
**Location**: `hammerspoon/push_to_talk.lua` lines 1274-1674

**Your mission**: Reverse-engineer what this code does

**Questions to answer in a notebook:**
1. What inputs does `runWhisper()` take?
2. What outputs does it return?
3. What are the main steps in the process?
4. What error conditions exist?
5. How does it choose which model to use?
6. How does it handle timeouts?
7. What's the difference between whisper-cpp and openai-whisper?

**Exercise**: Draw a flowchart on paper (yes, actual paper!)

**Don't code yet!** Understanding first, implementation later.

---

#### Task 2.2: Review Existing Java Code
**Location**: `whisper-post-processor/src/main/java/com/cliffmin/whisper/service/WhisperService.java`

**Questions:**
1. What does the existing Java code already do?
2. What's missing compared to Lua?
3. Can you extend it, or do you need a new class?
4. What would you name the new class?

**Hint**: The existing code is minimal - you'll build on top of it.

---

#### Task 2.3: Design Your Service Interface
**Challenge**: Design the API BEFORE implementing it

**Questions to answer:**
- What methods will your service expose?
- What parameters do they need?
- What do they return?
- Synchronous or asynchronous?
- How do you handle configuration?

**Exercise**: Write the interface as comments first

```java
/**
 * Service for orchestrating Whisper transcription
 * 
 * Your design here - what methods?
 * What do they do?
 * What can go wrong?
 */
public class WhisperOrchestrationService {
    // Think about:
    // - transcribe(Path audio) -> ?
    // - selectModel(double duration) -> ?
    // - What about configuration?
    // - What about error cases?
}
```

**Checkpoint**: Can you explain your design to someone?

---

### Day 3-4: Core Implementation
**Time**: 6-8 hours  
**Now you can code!**

#### Task 2.4: Model Selection Logic
**Challenge**: Implement model selection based on duration

**Current Lua logic** (DON'T COPY, UNDERSTAND):
```lua
-- Lines 1254-1267 in push_to_talk.lua
-- How does it choose between base and medium?
-- What's the threshold?
-- What about config overrides?
```

**Your challenge**:
1. Write a test FIRST:
   ```java
   @Test
   void shouldSelectBaseModelForShortAudio() {
       // Write this test before implementing
       // What duration should use base?
       // What duration should use medium?
   }
   ```

2. Then implement to make test pass

**Questions to solve yourself:**
- Where should the 21-second threshold live?
- Should it be configurable?
- What if config specifies a model explicitly?

**Don't look at Lua yet!** Try to implement from requirements.

---

#### Task 2.5: Command Construction
**Challenge**: Build whisper-cpp command line arguments

**Research needed:**
- What options does whisper-cpp accept?
- Run `whisper-cpp --help` and read the output
- What's the difference from openai-whisper?

**Questions:**
- How do you represent command-line args in Java?
- `List<String>`? `String[]`? Builder pattern?
- How do you add optional parameters?
- How do you avoid injection vulnerabilities?

**Test first:**
```java
@Test
void shouldBuildWhisperCppCommand() {
    // Given audio path and model
    // When building command
    // Then should have correct arguments
    // What are the MUST-HAVE args?
    // What are optional?
}
```

**Hint**: Look at existing `WhisperCppAdapter.java` for clues, but don't copy!

---

#### Task 2.6: Process Execution
**Challenge**: Run whisper-cpp and capture output

**Key Java concepts you'll need:**
- `ProcessBuilder`
- `Process.waitFor()`
- `InputStream` reading
- Timeout handling

**Questions to solve:**
- How do you read stdout AND stderr?
- What if process hangs?
- How do you kill a timed-out process?
- How do you handle non-zero exit codes?

**Gotcha Alert**: Processes can deadlock if you don't read streams!

**Research task**: Google "Java ProcessBuilder deadlock" and understand why

**Test approach:**
```java
@Test
void shouldHandleProcessTimeout() {
    // How do you test timeout behavior?
    // Can you create a mock "slow" process?
    // What should happen after timeout?
}
```

---

### Day 5-6: JSON Parsing & Error Handling
**Time**: 6-8 hours

#### Task 2.7: Parse Whisper JSON Output
**Challenge**: Handle two different JSON formats

**Background**: whisper-cpp and openai-whisper output different JSON structures

**Your research:**
1. Run whisper-cpp and save JSON output
2. Run openai-whisper and save JSON output
3. Compare them - what's different?
4. Design a unified representation

**Questions:**
- Do you need two parsers or one flexible one?
- What fields are essential vs optional?
- How do you handle missing fields gracefully?

**Test-driven approach:**
```java
@Test
void shouldParseWhisperCppJson() {
    String json = // ... real example from your system
    TranscriptionResult result = parser.parse(json);
    // What assertions?
}

@Test
void shouldParseOpenAIWhisperJson() {
    // Different structure!
}

@Test
void shouldHandleMalformedJson() {
    // What happens with invalid JSON?
}
```

---

#### Task 2.8: Comprehensive Error Handling
**Challenge**: Handle everything that can go wrong

**Error scenarios to handle:**
1. Whisper binary not found
2. Audio file doesn't exist
3. Audio file corrupted
4. Process crashes mid-transcription
5. JSON output missing/invalid
6. Timeout exceeded
7. Out of memory
8. Disk full

**Questions:**
- Which errors should retry?
- Which should fail fast?
- What information should error messages include?
- How do you log errors for debugging?

**Exercise**: Create an error taxonomy

```java
// Design your exceptions:
// - WhisperNotFoundException
// - TranscriptionTimeoutException
// - InvalidAudioException
// Which extend what?
// Checked vs unchecked?
```

---

### Day 7-8: Integration & Polish
**Time**: 4-6 hours

#### Task 2.9: Integrate with Existing Code
**Challenge**: Make your service work with the rest of the system

**Integration points:**
- Configuration loading
- Logging service
- Audio processor
- Text processing pipeline

**Questions:**
- How does your service get configuration?
- Where does it log events?
- How does it coordinate with AudioProcessor?
- What's the full pipeline flow?

**Test the integration:**
```java
@Test
void shouldTranscribeEndToEnd() {
    // Real audio file → transcription
    // This is an integration test
    // It can take seconds to run
}
```

---

#### Task 2.10: Update Lua to Call Java
**Challenge**: Replace 400 lines of Lua with simple service call

**Goal**: Simplify Lua to this:

```lua
local function runWhisper(audioPath)
    -- How do you call your Java service from Lua?
    -- HTTP request?
    -- Should you use the existing daemon?
    -- What about error handling?
end
```

**Questions:**
- Use existing PTTServiceDaemon or direct CLI call?
- What's the API endpoint?
- How do you handle Java service down?
- Should Lua have fallback logic?

---

### Phase 2 Checkpoint:
**Before considering this done:**

**Code Quality:**
- [ ] All tests pass
- [ ] Test coverage >80%
- [ ] No duplicate code
- [ ] Clear error messages
- [ ] Comprehensive logging

**Functionality:**
- [ ] Works with whisper-cpp
- [ ] Works with openai-whisper
- [ ] Handles timeouts correctly
- [ ] Model selection works
- [ ] Error recovery works

**Understanding:**
- [ ] Can you explain every design decision?
- [ ] Can you debug issues without AI?
- [ ] Did you learn something about Java you didn't know?
- [ ] Are you confident in this code?

**Estimated LOC**: 
- Added: ~500 lines Java
- Removed: ~400 lines Lua

---

## 🎓 Learning Checkpoints Throughout

### After Each Coding Session:
**Ask yourself:**
1. What did I learn today that I didn't know?
2. What mistake did I make and what did it teach me?
3. What did I figure out without Googling/AI?
4. What would I do differently next time?

**Keep a journal** - it reinforces learning!

---

### When You Get Stuck:
**30-Minute Rule**: Try to solve it yourself for 30 minutes first

**Debug Systematically:**
1. What's the symptom?
2. What's the expected behavior?
3. Where could the bug be?
4. Add logging/print statements
5. Use debugger (not println!)
6. Narrow it down

**Only after 30 minutes:** Ask targeted questions
- ❌ Bad: "Fix my code"
- ✅ Good: "Why does ProcessBuilder deadlock when reading stderr?"

---

## 📊 Measuring Your Progress

### Week 1 Goals:
- [ ] Phase 1 complete (duplication removed)
- [ ] Day 2 design complete
- [ ] Tests written for model selection
- [ ] Command construction working

### Week 2 Goals:
- [ ] Process execution working
- [ ] JSON parsing complete
- [ ] Error handling comprehensive
- [ ] Integration complete
- [ ] Lua simplified

---

## 🏆 Success Metrics

### Technical Metrics:
- Lines of Lua removed: Target 400+
- Test coverage: Target 80%+
- Code duplication: Target 0%
- Performance: Should be faster

### Personal Metrics:
**Most Important**: Can you honestly say:
- ✅ "I understand this code deeply"
- ✅ "I could maintain this without AI"
- ✅ "I'm confident debugging issues"
- ✅ "I learned how to design services"
- ✅ "I can explain my decisions"

---

## 🎯 What Happens Next?

### If You Succeed:
- You've restored ~70% of your coding confidence
- You've proven you can still code without AI crutches
- You've built something substantial
- **You can tackle Phase 3-4 yourself or delegate to AI**

### If You Get Stuck:
- That's OK! Everyone gets stuck
- Document where you're stuck and why
- Ask specific questions (not "write code for me")
- Take breaks - solutions come when walking away

### If You Want to Quit:
- Be honest about why
- It's OK to ask AI for help
- But try to understand the AI's code
- Learning from reading is still learning

---

## 💡 Tips for Success

### Before You Start:
1. **Block time** - 2-3 hour chunks work best
2. **Minimize distractions** - close Slack, Twitter, etc.
3. **Set up your environment** - good IDE, debugger ready
4. **Read the existing code** - understand before changing

### While Coding:
1. **Write tests first** - TDD is your friend
2. **Commit small** - commit every ~30 minutes
3. **Read docs** - Java docs, not just StackOverflow
4. **Use debugger** - step through code, don't just guess
5. **Take breaks** - 50 minutes work, 10 minutes walk

### When Debugging:
1. **Reproduce consistently** - can you make it fail on demand?
2. **Simplify** - remove complexity until it works
3. **Add logging** - but don't leave it in production
4. **Rubber duck** - explain the problem out loud
5. **Sleep on it** - seriously, your brain works while sleeping

---

## 📚 Resources You Can Use

### Allowed:
- ✅ Official Java documentation
- ✅ StackOverflow (read, understand, adapt)
- ✅ Existing VoxCore code
- ✅ Whisper documentation
- ✅ Books on Java concurrency

### Discouraged:
- ⚠️ AI code generation (defeats the purpose)
- ⚠️ Copy-paste from tutorials (understand first)
- ⚠️ "Just make it work" without understanding

### When to Ask for Help:
- ✅ After 30 minutes stuck on same issue
- ✅ To review your design decisions
- ✅ To understand why something doesn't work
- ❌ To write code for you
- ❌ Before trying yourself

---

## 🎬 Ready to Start?

### Your First Action:
1. Read Phase 1 completely
2. Open `hammerspoon/push_to_talk.lua`
3. Find `reflowFromSegments()` function
4. Start reading and understanding it
5. **Don't write code yet!**

### Remember:
- This is about **learning**, not just completing
- **Struggle is part of the process**
- **Mistakes teach more than successes**
- You're building skills that last

---

## 📝 Document Your Journey

Create a file: `MY_LEARNING_LOG.md`

```markdown
# My Learning Log

## Day 1 - [Date]
**Goal**: Remove duplication
**Time spent**: 
**What I learned**:
**Challenges**:
**Victories**:
**Tomorrow's goal**:

## Day 2 - [Date]
...
```

This will be valuable when you look back!

---

**Good luck! You've got this. 💪**

Remember: The goal isn't to finish fast - it's to understand deeply.
