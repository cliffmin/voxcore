package com.cliffmin.whisper.service;

import com.google.gson.Gson;
import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.*;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;
import java.util.stream.Collectors;

/**
 * WhisperService implementation using whisper.cpp binary.
 * Provides fast, efficient transcription for macOS.
 */
public class WhisperCppAdapter implements WhisperService {
    private static final Logger log = LoggerFactory.getLogger(WhisperCppAdapter.class);
    
    private final String whisperBinary;
    private final Path modelsPath;
    private final int timeout;
    private final Gson gson = new Gson();
    
    public WhisperCppAdapter() {
        this(findWhisperBinary(), getDefaultModelsPath(), 300);
    }
    
    public WhisperCppAdapter(String whisperBinary, Path modelsPath, int timeoutSeconds) {
        this.whisperBinary = whisperBinary;
        this.modelsPath = modelsPath;
        this.timeout = timeoutSeconds;
        
        if (!isAvailable()) {
            log.warn("whisper.cpp not available at: {}", whisperBinary);
        }
    }
    
    @Override
    public TranscriptionResult transcribe(Path audioPath, TranscriptionOptions options) 
            throws TranscriptionException {
        
        if (!validateAudioFile(audioPath)) {
            throw new TranscriptionException("Invalid audio file: " + audioPath);
        }
        
        List<String> command = buildCommand(audioPath, options);
        log.debug("Executing: {}", String.join(" ", command));
        
        try {
            ProcessBuilder pb = new ProcessBuilder(command);
            pb.redirectErrorStream(false);
            
            Process process = pb.start();
            
            // Capture output
            String jsonOutput = captureOutput(process.getInputStream());
            String errors = captureOutput(process.getErrorStream());
            
            boolean completed = process.waitFor(timeout, TimeUnit.SECONDS);
            
            if (!completed) {
                process.destroyForcibly();
                throw new TranscriptionException("Transcription timed out after " + timeout + " seconds");
            }
            
            int exitCode = process.exitValue();
            if (exitCode != 0) {
                throw new TranscriptionException("Whisper.cpp failed with exit code " + exitCode + ": " + errors);
            }
            
            return parseJsonOutput(jsonOutput, audioPath);
            
        } catch (IOException e) {
            throw new TranscriptionException("Failed to execute whisper.cpp", e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new TranscriptionException("Transcription interrupted", e);
        }
    }
    
    @Override
    public CompletableFuture<TranscriptionResult> transcribeAsync(Path audioPath, TranscriptionOptions options) {
        return CompletableFuture.supplyAsync(() -> {
            try {
                return transcribe(audioPath, options);
            } catch (TranscriptionException e) {
                throw new RuntimeException(e);
            }
        });
    }
    
    @Override
    public String detectModel(double durationSeconds) {
        // Model selection based on duration and quality needs
        if (durationSeconds < 10) {
            return "tiny.en";  // Fast for short clips
        } else if (durationSeconds < 30) {
            return "base.en";  // Good balance
        } else if (durationSeconds < 300) {
            return "small.en"; // Better quality for longer recordings
        } else {
            return "medium.en"; // Best quality for very long recordings
        }
    }
    
    @Override
    public boolean validateAudioFile(Path audioPath) {
        if (!Files.exists(audioPath)) {
            return false;
        }
        
        try {
            // Check if it's a WAV file
            String fileName = audioPath.getFileName().toString().toLowerCase();
            if (!fileName.endsWith(".wav")) {
                log.warn("Non-WAV file provided: {}", fileName);
            }
            
            // Check file size (not empty, not too large)
            long size = Files.size(audioPath);
            return size > 44 && size < 500_000_000; // 44 bytes min (WAV header), 500MB max
            
        } catch (IOException e) {
            log.error("Failed to validate audio file", e);
            return false;
        }
    }
    
    @Override
    public boolean isAvailable() {
        try {
            Process process = new ProcessBuilder(whisperBinary, "--help")
                .redirectErrorStream(true)
                .start();
            
            boolean completed = process.waitFor(2, TimeUnit.SECONDS);
            if (completed) {
                return process.exitValue() == 0;
            }
            process.destroyForcibly();
            return false;
            
        } catch (IOException | InterruptedException e) {
            return false;
        }
    }
    
    @Override
    public String getImplementationName() {
        return "whisper.cpp";
    }
    
    private List<String> buildCommand(Path audioPath, TranscriptionOptions options) {
        List<String> command = new ArrayList<>();
        command.add(whisperBinary);
        
        // Model selection
        Path modelPath = modelsPath.resolve("ggml-" + options.getModel() + ".bin");
        command.add("--model");
        command.add(modelPath.toString());
        
        // Language
        command.add("--language");
        command.add(options.getLanguage());
        
        // Output format
        command.add("--output-json");
        
        // Performance options
        command.add("--threads");
        command.add(String.valueOf(Runtime.getRuntime().availableProcessors()));
        
        // Beam search
        command.add("--beam-size");
        command.add(String.valueOf(options.getBeamSize()));
        
        // No timestamps reduces overhead if not needed
        if (!options.hasTimestamps()) {
            command.add("--no-timestamps");
        }
        
        // Input file must be last
        command.add(audioPath.toString());
        
        return command;
    }
    
    private String captureOutput(java.io.InputStream stream) throws IOException {
        StringBuilder output = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(stream))) {
            String line;
            while ((line = reader.readLine()) != null) {
                output.append(line).append("\n");
            }
        }
        return output.toString();
    }
    
    private TranscriptionResult parseJsonOutput(String jsonOutput, Path audioPath) 
            throws TranscriptionException {
        try {
            // Find the JSON output file (whisper.cpp writes to audioPath + ".json")
            Path jsonFile = Paths.get(audioPath.toString() + ".json");
            if (Files.exists(jsonFile)) {
                jsonOutput = Files.readString(jsonFile);
                Files.deleteIfExists(jsonFile); // Clean up
            }
            
            JsonObject root = JsonParser.parseString(jsonOutput).getAsJsonObject();
            
            // Extract transcription
            JsonObject transcription = root.getAsJsonObject("transcription");
            if (transcription == null) {
                throw new TranscriptionException("No transcription found in output");
            }
            
            String text = transcription.get("text").getAsString();
            String language = transcription.has("language") 
                ? transcription.get("language").getAsString() 
                : "en";
            
            // Parse segments
            List<Segment> segments = new ArrayList<>();
            if (transcription.has("segments")) {
                JsonArray segmentArray = transcription.getAsJsonArray("segments");
                for (int i = 0; i < segmentArray.size(); i++) {
                    JsonObject seg = segmentArray.get(i).getAsJsonObject();
                    segments.add(new Segment(
                        i,
                        seg.get("start").getAsDouble(),
                        seg.get("end").getAsDouble(),
                        seg.get("text").getAsString(),
                        seg.has("confidence") ? seg.get("confidence").getAsDouble() : 1.0
                    ));
                }
            }
            
            // Calculate duration
            double duration = segments.isEmpty() ? 0 : 
                segments.get(segments.size() - 1).getEnd();
            
            // Metadata
            Map<String, Object> metadata = new HashMap<>();
            metadata.put("model", transcription.has("model") ? 
                transcription.get("model").getAsString() : "unknown");
            metadata.put("implementation", "whisper.cpp");
            
            return new TranscriptionResult(text, segments, language, duration, metadata);
            
        } catch (Exception e) {
            throw new TranscriptionException("Failed to parse whisper.cpp output", e);
        }
    }
    
    private static String findWhisperBinary() {
        // Common locations for whisper.cpp on macOS
        String[] paths = {
            "/usr/local/bin/whisper-cpp",
            "/opt/homebrew/bin/whisper-cpp",
            "/usr/local/bin/whisper",
            System.getenv("HOME") + "/.local/bin/whisper-cpp"
        };
        
        for (String path : paths) {
            if (Files.exists(Paths.get(path))) {
                return path;
            }
        }
        
        // Fallback to PATH
        return "whisper-cpp";
    }
    
    private static Path getDefaultModelsPath() {
        // Common model locations
        String home = System.getenv("HOME");
        Path[] paths = {
            Paths.get(home, ".cache", "whisper"),
            Paths.get(home, ".local", "share", "whisper"),
            Paths.get("/usr/local/share/whisper/models")
        };
        
        for (Path path : paths) {
            if (Files.exists(path)) {
                return path;
            }
        }
        
        return Paths.get(home, ".cache", "whisper");
    }
}