package com.cliffmin.voxcore.transcription;

import com.cliffmin.voxcore.config.VoxCoreConfig;
import com.google.gson.JsonObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;

/**
 * Invokes whisper-cpp binary for transcription.
 * Replaces Lua Whisper invocation logic.
 */
public class WhisperInvoker {

    private static final Logger log = LoggerFactory.getLogger(WhisperInvoker.class);

    private final VoxCoreConfig config;
    private final String whisperBinary;

    public WhisperInvoker(VoxCoreConfig config) {
        this.config = config;
        this.whisperBinary = detectWhisperBinary();
    }

    /**
     * Transcribe audio file using Whisper.
     *
     * @param audioFile Path to audio file
     * @param initialPrompt Initial prompt with vocabulary hints
     * @return Whisper result with text and metadata
     * @throws IOException if transcription fails
     */
    public TranscriptionService.WhisperResult transcribe(Path audioFile, String initialPrompt) throws IOException {
        List<String> command = buildWhisperCommand(audioFile, initialPrompt);

        log.info("Invoking Whisper: {}", String.join(" ", command));

        ProcessBuilder pb = new ProcessBuilder(command);
        pb.redirectErrorStream(false);

        Process process = pb.start();

        // Read output
        StringBuilder stdout = new StringBuilder();
        StringBuilder stderr = new StringBuilder();

        Thread stdoutReader = new Thread(() -> {
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    stdout.append(line).append("\n");
                }
            } catch (IOException e) {
                log.error("Error reading stdout: {}", e.getMessage());
            }
        });

        Thread stderrReader = new Thread(() -> {
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getErrorStream()))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    stderr.append(line).append("\n");
                    log.debug("Whisper: {}", line);
                }
            } catch (IOException e) {
                log.error("Error reading stderr: {}", e.getMessage());
            }
        });

        stdoutReader.start();
        stderrReader.start();

        try {
            int exitCode = process.waitFor();
            stdoutReader.join();
            stderrReader.join();

            if (exitCode != 0) {
                throw new IOException("Whisper failed with exit code " + exitCode + ": " + stderr);
            }

            // Parse output
            return parseWhisperOutput(stdout.toString());

        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IOException("Whisper process interrupted", e);
        }
    }

    /**
     * Build Whisper command.
     */
    private List<String> buildWhisperCommand(Path audioFile, String initialPrompt) {
        List<String> command = new ArrayList<>();

        command.add(whisperBinary);
        command.add("-m");
        command.add(getModelPath(config.getWhisperModel()));
        command.add("-f");
        command.add(audioFile.toAbsolutePath().toString());
        command.add("--language");
        command.add("en");
        command.add("--no-timestamps"); // Just the text, no timestamps

        if (initialPrompt != null && !initialPrompt.isEmpty()) {
            command.add("--prompt");
            command.add(initialPrompt);
        }

        return command;
    }

    /**
     * Parse Whisper output (plain text).
     * whisper-cpp outputs transcription to stdout (metadata goes to stderr).
     */
    private TranscriptionService.WhisperResult parseWhisperOutput(String output) throws IOException {
        // stdout contains just the transcription text
        String text = output.trim();

        if (text.isEmpty()) {
            log.warn("No transcription text found in Whisper output");
        }

        return new TranscriptionService.WhisperResult(text, new JsonObject());
    }

    /**
     * Auto-detect Whisper binary.
     * Replaces Lua detectWhisper() function.
     */
    private String detectWhisperBinary() {
        // Check config first
        if (config.getWhisperCppPath() != null) {
            return config.getWhisperCppPath();
        }

        // Auto-detect common paths
        String[] candidates = {
            "/opt/homebrew/bin/whisper-cli",
            "/opt/homebrew/bin/whisper-cpp",
            "/usr/local/bin/whisper-cpp",
            System.getProperty("user.home") + "/.local/bin/whisper"
        };

        for (String candidate : candidates) {
            Path path = Paths.get(candidate);
            if (Files.exists(path) && Files.isExecutable(path)) {
                log.info("Detected Whisper binary: {}", candidate);
                return candidate;
            }
        }

        throw new RuntimeException("Whisper binary not found! Install with: brew install whisper-cpp");
    }

    /**
     * Get model file path.
     */
    private String getModelPath(String modelName) {
        // Strip .en suffix if present (Homebrew models don't have language variants)
        String normalizedName = modelName.replace(".en", "");

        // Standard Homebrew path
        String homebrewModels = "/opt/homebrew/share/whisper-cpp";
        Path modelPath = Paths.get(homebrewModels, "ggml-" + normalizedName + ".bin");

        if (Files.exists(modelPath)) {
            return modelPath.toString();
        }

        // Check if it's already a full path
        Path fullPath = Paths.get(modelName);
        if (Files.exists(fullPath)) {
            return modelName;
        }

        // Model not found - provide helpful error
        String errorMsg = String.format(
            "Whisper model '%s' not found at %s\n" +
            "Download with: ./scripts/setup/download_whisper_models.sh %s\n" +
            "Or manually: curl -L -o %s https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-%s.en.bin",
            modelName, modelPath, normalizedName, modelPath, normalizedName
        );
        throw new RuntimeException(errorMsg);
    }
}
