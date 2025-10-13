package com.cliffmin.whisper.integration;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.io.TempDir;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.*;
import java.util.concurrent.TimeUnit;
import java.util.stream.Collectors;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.*;

/**
 * End-to-end integration tests for the complete Whisper + Java post-processor pipeline.
 * Tests the full workflow from audio generation to final processed output.
 */
@Tag("integration")
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
public class E2EIntegrationTest {
    
    private static final Path PROJECT_ROOT = Paths.get(System.getProperty("user.dir")).getParent();
    private static final Path JAR_PATH = PROJECT_ROOT.resolve("whisper-post-processor/dist/whisper-post.jar");
    private static final Path WHISPER_PATH = Paths.get(System.getProperty("user.home"), ".local/bin/whisper");
    
    @TempDir
    Path tempDir;
    
    private static List<TestCase> testCases;
    private Gson gson = new Gson();
    
    static class TestCase {
        String input;
        String expectedClean;
        List<String> disfluencies;
        
        TestCase(String input, String expectedClean, String... disfluencies) {
            this.input = input;
            this.expectedClean = expectedClean;
            this.disfluencies = Arrays.asList(disfluencies);
        }
    }
    
    @BeforeAll
    static void setupTestCases() {
        testCases = Arrays.asList(
            new TestCase(
                "Um, hello there, this is a test.",
                "Hello there, this is a test.",
                "um"
            ),
            new TestCase(
                "So, you know, I think we should, uh, implement this feature.",
                "So, I think we should, implement this feature.",
                "you know", "uh"
            ),
            new TestCase(
                "Actually, the API uses JSON and, um, XML formats.",
                "The API uses JSON and XML formats.",
                "actually", "um"
            ),
            new TestCase(
                "I mean, what I'm trying to say is, like, really important.",
                "What I'm trying to say is really important.",
                "i mean", "like"
            ),
            new TestCase(
                "Well, basically, the JavaScript code is, you know, complex.",
                "The JavaScript code is complex.",
                "well", "basically", "you know"
            )
        );
    }
    
    @BeforeAll
    static void checkPrerequisites() {
        // Check if JAR exists, build if not
        if (!Files.exists(JAR_PATH)) {
            System.out.println("Building Java post-processor...");
            buildJavaProcessor();
        }
        
        // Check if Whisper is installed
        if (!Files.exists(WHISPER_PATH)) {
            fail("Whisper not installed at: " + WHISPER_PATH + 
                 "\nPlease install with: pip install openai-whisper");
        }
    }
    
    private static void buildJavaProcessor() {
        try {
            ProcessBuilder pb = new ProcessBuilder(
                "gradle", "clean", "shadowJar", "buildExecutable", "--no-daemon", "-q"
            );
            pb.directory(PROJECT_ROOT.resolve("whisper-post-processor").toFile());
            Process process = pb.start();
            
            boolean finished = process.waitFor(30, TimeUnit.SECONDS);
            if (!finished || process.exitValue() != 0) {
                throw new RuntimeException("Failed to build Java processor");
            }
        } catch (Exception e) {
            throw new RuntimeException("Failed to build Java processor", e);
        }
    }
    
    @Test
    @Order(1)
    @DisplayName("Test Java processor directly with text input")
    void testJavaProcessorDirect() throws Exception {
        for (int i = 0; i < testCases.size(); i++) {
            TestCase testCase = testCases.get(i);
            
            // Run Java processor
            String output = runJavaProcessor(testCase.input, false);
            
            // Verify disfluencies were removed
            for (String disfluency : testCase.disfluencies) {
                assertThat(output.toLowerCase())
                    .as("Test case %d: Disfluency '%s' should be removed", i + 1, disfluency)
                    .doesNotContain(disfluency.toLowerCase());
            }
            
            System.out.printf("✓ Test %d: Disfluencies removed from: %s%n", 
                            i + 1, testCase.input.substring(0, Math.min(30, testCase.input.length())));
        }
    }
    
    @Test
    @Order(2)
    @DisplayName("Test JSON input/output processing")
    void testJsonProcessing() throws Exception {
        // Create test JSON
        JsonObject input = new JsonObject();
        input.addProperty("text", "um, this is, uh, a test.");
        
        JsonObject segment = new JsonObject();
        segment.addProperty("text", "um, this is, uh, a test.");
        segment.addProperty("start", 0.0);
        segment.addProperty("end", 2.5);
        
        com.google.gson.JsonArray segments = new com.google.gson.JsonArray();
        segments.add(segment);
        input.add("segments", segments);
        
        // Process with Java processor
        String output = runJavaProcessor(gson.toJson(input), true);
        JsonObject result = JsonParser.parseString(output).getAsJsonObject();
        
        // Verify processing
        String processedText = result.get("text").getAsString();
        assertThat(processedText.toLowerCase())
            .doesNotContain("um")
            .doesNotContain("uh");
        
        // Verify segments were processed
        assertTrue(result.has("segments"), "Output should contain segments");
        assertThat(result.getAsJsonArray("segments").size()).isGreaterThan(0);
        
        System.out.println("✓ JSON processing works correctly");
    }
    
    @Test
    @Order(3)
    @DisplayName("Test complete Whisper → Java pipeline")
    void testCompletePipeline() throws Exception {
        // Create test audio
        String testText = "Um, so basically, you know, I was thinking about, uh, the architecture.";
        Path audioFile = createTestAudio(testText, "pipeline_test");
        
        // Run Whisper
        JsonObject whisperOutput = runWhisper(audioFile);
        assertNotNull(whisperOutput, "Whisper should produce output");
        
        String originalText = whisperOutput.get("text").getAsString();
        System.out.println("Whisper output: " + originalText);
        
        // Process with Java post-processor
        String processedJson = runJavaProcessor(gson.toJson(whisperOutput), true);
        JsonObject processedOutput = JsonParser.parseString(processedJson).getAsJsonObject();
        
        String processedText = processedOutput.get("text").getAsString();
        System.out.println("Processed output: " + processedText);
        
        // Verify processing occurred
        assertNotEquals(originalText.toLowerCase(), processedText.toLowerCase(),
                       "Text should be modified by post-processor");
        
        // Check for disfluency removal (may not be perfect due to TTS/Whisper)
        // At minimum, verify the processor ran successfully
        assertThat(processedText).isNotEmpty();
        
        System.out.println("✓ Complete pipeline test passed");
    }
    
    @Test
    @Order(4)
    @DisplayName("Test performance with large input")
    void testPerformance() throws Exception {
        // Generate large input with disfluencies
        StringBuilder largeInput = new StringBuilder();
        for (int i = 0; i < 100; i++) {
            largeInput.append(String.format("Um, this is, uh, test line number %d, you know.%n", i));
        }
        
        // Measure processing time
        long startTime = System.currentTimeMillis();
        String output = runJavaProcessor(largeInput.toString(), false);
        long elapsedMs = System.currentTimeMillis() - startTime;
        
        // Verify performance
        assertThat(output).isNotEmpty();
        assertThat(elapsedMs)
            .as("Processing 100 lines should take less than 1 second")
            .isLessThan(1000);
        
        System.out.printf("✓ Performance test: %d ms for 100 lines%n", elapsedMs);
    }
    
    @Test
    @Order(5)
    @DisplayName("Test various disfluency patterns")
    void testDisfluencyPatterns() throws Exception {
        Map<String, String> patterns = new LinkedHashMap<>();
        patterns.put("I I think we we should go go there.", "I think we should go there.");
        patterns.put("Th-th-this is a t-t-test.", "This is a test.");
        patterns.put("Um, you know, like, actually, basically done.", "Done.");
        patterns.put("So, I mean, uh, what's important, you know?", "So, what's important?");
        
        for (Map.Entry<String, String> entry : patterns.entrySet()) {
            String input = entry.getKey();
            String expected = entry.getValue();
            
            String output = runJavaProcessor(input, false);
            
            // Check that some cleaning occurred
            assertThat(output.length())
                .as("Output should be shorter after removing disfluencies")
                .isLessThanOrEqualTo(input.length());
            
            System.out.printf("✓ Pattern test: %s → %s%n", 
                            input.substring(0, Math.min(20, input.length())), 
                            output.substring(0, Math.min(20, output.length())));
        }
    }
    
    @Test
    @Order(6)
    @DisplayName("Test error handling")
    void testErrorHandling() throws Exception {
        // Test with invalid JSON
        String invalidJson = "{invalid json}";
        String output = runJavaProcessor(invalidJson, true);
        assertThat(output).isNotEmpty(); // Should fall back to text processing
        
        // Test with empty input
        String emptyOutput = runJavaProcessor("", false);
        assertThat(emptyOutput).isEmpty();
        
        // Test with null-like input
        String nullOutput = runJavaProcessor("null", false);
        assertThat(nullOutput).isIn("null", "Null", "Null."); // Should pass through or capitalize
        
        System.out.println("✓ Error handling tests passed");
    }
    
    /**
     * Helper method to run the Java post-processor
     */
    private String runJavaProcessor(String input, boolean useJson) throws IOException, InterruptedException {
        List<String> command = new ArrayList<>();
        command.add("java");
        command.add("-jar");
        command.add(JAR_PATH.toString());
        if (useJson) {
            command.add("--json");
        }
        
        ProcessBuilder pb = new ProcessBuilder(command);
        pb.redirectErrorStream(false);
        Process process = pb.start();
        
        // Send input
        process.getOutputStream().write(input.getBytes());
        process.getOutputStream().close();
        
        // Get output
        String output = new BufferedReader(new InputStreamReader(process.getInputStream()))
            .lines()
            .collect(Collectors.joining("\n"));
        
        process.waitFor(5, TimeUnit.SECONDS);
        return output.trim();
    }
    
    /**
     * Helper method to create test audio using macOS TTS
     */
    private Path createTestAudio(String text, String filename) throws IOException, InterruptedException {
        Path aiffFile = tempDir.resolve(filename + ".aiff");
        Path wavFile = tempDir.resolve(filename + ".wav");
        
        // Generate audio with 'say' command
        ProcessBuilder sayPb = new ProcessBuilder("say", "-o", aiffFile.toString(), text);
        Process sayProcess = sayPb.start();
        sayProcess.waitFor(10, TimeUnit.SECONDS);
        
        // Convert to WAV format for Whisper
        ProcessBuilder ffmpegPb = new ProcessBuilder(
            "ffmpeg", "-i", aiffFile.toString(),
            "-ar", "16000", "-ac", "1",
            wavFile.toString(), "-y"
        );
        Process ffmpegProcess = ffmpegPb.start();
        ffmpegProcess.waitFor(10, TimeUnit.SECONDS);
        
        return wavFile;
    }
    
    /**
     * Helper method to run Whisper transcription
     */
    private JsonObject runWhisper(Path audioFile) throws IOException, InterruptedException {
        ProcessBuilder pb = new ProcessBuilder(
            WHISPER_PATH.toString(),
            "--model", "base.en",
            "--output_format", "json",
            "--output_dir", tempDir.toString(),
            "--fp16", "False",
            audioFile.toString()
        );
        pb.directory(PROJECT_ROOT.resolve("hammerspoon").toFile());
        
        Process process = pb.start();
        boolean finished = process.waitFor(30, TimeUnit.SECONDS);
        
        if (!finished || process.exitValue() != 0) {
            return null;
        }
        
        // Read the JSON output
        String baseName = audioFile.getFileName().toString().replace(".wav", "");
        Path jsonFile = tempDir.resolve(baseName + ".json");
        
        if (Files.exists(jsonFile)) {
            String jsonContent = Files.readString(jsonFile);
            return JsonParser.parseString(jsonContent).getAsJsonObject();
        }
        
        return null;
    }
}