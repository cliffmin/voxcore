package com.cliffmin.voxcore.config;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.annotations.SerializedName;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;

/**
 * VoxCore configuration with path expansion and validation.
 * Replaces Lua config loading from ptt_config.lua.
 */
public class VoxCoreConfig {

    private static final Logger log = LoggerFactory.getLogger(VoxCoreConfig.class);
    private static final Gson gson = new GsonBuilder().setPrettyPrinting().create();

    // Storage directories
    @SerializedName("notes_dir")
    private String notesDir = "~/Documents/VoiceNotes";

    @SerializedName("log_dir")
    private String logDir = null;  // Default: notesDir/tx_logs

    // Whisper configuration
    @SerializedName("whisper_model")
    private String whisperModel = "base.en";

    @SerializedName("whisper_cpp_path")
    private String whisperCppPath = null;  // Auto-detect if null

    // VoxCompose integration
    @SerializedName("voxcompose_enabled")
    private boolean voxcomposeEnabled = false;

    @SerializedName("voxcompose_bin")
    private String voxcomposeBin = null;

    @SerializedName("ollama_host")
    private String ollamaHost = "http://localhost:11434";

    // Audio configuration
    @SerializedName("audio_device_index")
    private int audioDeviceIndex = 1;

    // Vocabulary configuration
    @SerializedName("vocabulary_file")
    private String vocabularyFile = "~/.config/voxcompose/vocabulary.txt";

    @SerializedName("enable_dynamic_vocab")
    private boolean enableDynamicVocab = true;

    // Transient (computed) fields
    private transient Path notesPath;
    private transient Path logPath;
    private transient Path vocabularyPath;
    private transient List<String> validationErrors = new ArrayList<>();

    /**
     * Load configuration from file.
     *
     * @param configFile Path to config file (JSON)
     * @return Loaded config, or default if file doesn't exist
     * @throws IOException if file exists but can't be read
     */
    public static VoxCoreConfig load(Path configFile) throws IOException {
        if (configFile == null || !Files.exists(configFile)) {
            log.info("Config file not found, using defaults");
            return new VoxCoreConfig();
        }

        String json = Files.readString(configFile);
        VoxCoreConfig config = gson.fromJson(json, VoxCoreConfig.class);
        log.info("Loaded config from: {}", configFile);
        return config;
    }

    /**
     * Load configuration from default locations.
     * Priority: ~/.config/voxcore/config.json, ~/. voxcore.json
     *
     * @return Loaded config, or default if no config found
     */
    public static VoxCoreConfig loadDefault() {
        Path home = PathExpander.getHomeDir();
        Path[] candidates = {
            home.resolve(".config/voxcore/config.json"),
            home.resolve(".voxcore.json"),
            Paths.get("/usr/local/etc/voxcore/config.json")
        };

        for (Path candidate : candidates) {
            if (Files.exists(candidate)) {
                try {
                    return load(candidate);
                } catch (IOException e) {
                    log.warn("Failed to load config from {}: {}", candidate, e.getMessage());
                }
            }
        }

        log.info("No config file found, using defaults");
        return new VoxCoreConfig();
    }

    /**
     * Validate and expand all paths.
     * Call this after loading config.
     *
     * @return true if all validations passed
     */
    public boolean validate() {
        validationErrors.clear();
        boolean valid = true;

        // Expand and validate notes directory
        notesPath = DirectoryValidator.ensureDirectory(notesDir, "NOTES_DIR");
        if (notesPath == null) {
            validationErrors.add(String.format("NOTES_DIR not writable: %s", notesDir));
            valid = false;
        }

        // Expand and validate log directory (defaults to notes_dir/tx_logs)
        String effectiveLogDir = (logDir != null) ? logDir : (notesDir + "/tx_logs");
        logPath = DirectoryValidator.ensureDirectory(effectiveLogDir, "LOG_DIR");
        if (logPath == null) {
            validationErrors.add(String.format("LOG_DIR not writable: %s", effectiveLogDir));
            log.warn("Transaction logging will be disabled");
        }

        // Expand vocabulary file path (don't create, it's optional)
        if (enableDynamicVocab && vocabularyFile != null) {
            vocabularyPath = PathExpander.expandToPath(vocabularyFile);
            if (vocabularyPath != null && Files.exists(vocabularyPath)) {
                log.info("Vocabulary file: {}", vocabularyPath);
            } else {
                log.info("Vocabulary file not found (optional): {}", vocabularyFile);
            }
        }

        // Validate Whisper binary if specified
        if (whisperCppPath != null) {
            Path whisperPath = PathExpander.expandToPath(whisperCppPath);
            if (whisperPath == null || !Files.exists(whisperPath) || !Files.isExecutable(whisperPath)) {
                validationErrors.add(String.format("Whisper binary not found or not executable: %s", whisperCppPath));
                valid = false;
            }
        }

        // Validate VoxCompose binary if enabled
        if (voxcomposeEnabled && voxcomposeBin != null) {
            Path voxcomposePath = PathExpander.expandToPath(voxcomposeBin);
            if (voxcomposePath == null || !Files.exists(voxcomposePath)) {
                validationErrors.add(String.format("VoxCompose binary not found: %s", voxcomposeBin));
                log.warn("VoxCompose integration will be disabled");
                voxcomposeEnabled = false;
            }
        }

        if (!valid) {
            log.error("Configuration validation failed:");
            for (String error : validationErrors) {
                log.error("  - {}", error);
            }
        }

        return valid;
    }

    // Getters

    public Path getNotesPath() {
        return notesPath;
    }

    public Path getLogPath() {
        return logPath;
    }

    public Path getVocabularyPath() {
        return vocabularyPath;
    }

    public String getWhisperModel() {
        return whisperModel;
    }

    public String getWhisperCppPath() {
        return whisperCppPath;
    }

    public boolean isVoxcomposeEnabled() {
        return voxcomposeEnabled;
    }

    public String getVoxcomposeBin() {
        return voxcomposeBin;
    }

    public String getOllamaHost() {
        return ollamaHost;
    }

    public int getAudioDeviceIndex() {
        return audioDeviceIndex;
    }

    public boolean isEnableDynamicVocab() {
        return enableDynamicVocab;
    }

    public List<String> getValidationErrors() {
        return new ArrayList<>(validationErrors);
    }

    /**
     * Get effective configuration as JSON.
     *
     * @return JSON representation
     */
    public String toJson() {
        return gson.toJson(this);
    }

    @Override
    public String toString() {
        return String.format("VoxCoreConfig{notesDir=%s, logDir=%s, whisperModel=%s, voxcomposeEnabled=%s}",
                notesPath, logPath, whisperModel, voxcomposeEnabled);
    }
}
