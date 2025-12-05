package com.cliffmin.voxcore.transcription;

import com.cliffmin.voxcore.config.VoxCoreConfig;
import com.cliffmin.whisper.WhisperPostProcessorCLI;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

/**
 * Orchestrates transcription: Whisper invocation + post-processing.
 * Replaces Lua transcription logic from push_to_talk.lua.
 */
public class TranscriptionService {

    private static final Logger log = LoggerFactory.getLogger(TranscriptionService.class);

    private final VoxCoreConfig config;
    private final WhisperInvoker whisperInvoker;

    public TranscriptionService(VoxCoreConfig config) {
        this.config = config;
        this.whisperInvoker = new WhisperInvoker(config);
    }

    /**
     * Transcribe audio file.
     *
     * @param audioFile Path to WAV file
     * @param postProcess Whether to apply post-processing
     * @return Transcribed text
     * @throws IOException if transcription fails
     */
    public String transcribe(Path audioFile, boolean postProcess) throws IOException {
        if (!Files.exists(audioFile)) {
            throw new IOException("Audio file not found: " + audioFile);
        }

        log.info("Transcribing: {}", audioFile);

        // Load vocabulary hints if enabled
        String initialPrompt = loadInitialPrompt();

        // Invoke Whisper
        WhisperResult whisperResult = whisperInvoker.transcribe(audioFile, initialPrompt);

        // Extract text
        String text = whisperResult.getText();

        // Apply post-processing if requested
        if (postProcess) {
            text = applyPostProcessing(text);
        }

        log.info("Transcription complete: {} chars", text.length());
        return text;
    }

    /**
     * Load initial prompt with vocabulary hints.
     * Replaces Lua loadInitialPrompt() function.
     *
     * @return Initial prompt string
     */
    private String loadInitialPrompt() {
        if (!config.isEnableDynamicVocab()) {
            return getStaticPrompt();
        }

        Path vocabFile = config.getVocabularyPath();
        if (vocabFile == null || !Files.exists(vocabFile)) {
            log.debug("Vocabulary file not found, using static prompt");
            return getStaticPrompt();
        }

        try {
            String dynamicVocab = Files.readString(vocabFile).trim();
            log.info("Loaded vocabulary: {} chars from {}", dynamicVocab.length(), vocabFile);
            return getStaticPrompt() + " " + dynamicVocab;
        } catch (IOException e) {
            log.warn("Failed to read vocabulary file: {}", e.getMessage());
            return getStaticPrompt();
        }
    }

    /**
     * Get static prompt (disfluency hints).
     */
    private String getStaticPrompt() {
        return "Um, uh, like, you know.";
    }

    /**
     * Apply post-processing to transcribed text.
     * Uses existing pipeline processors.
     *
     * @param text Raw transcription
     * @return Post-processed text
     */
    private String applyPostProcessing(String text) {
        try {
            // Use existing processing pipeline with default processors
            com.cliffmin.whisper.pipeline.ProcessingPipeline pipeline = createDefaultPipeline();
            return pipeline.process(text);
        } catch (Exception e) {
            log.warn("Post-processing failed: {}", e.getMessage());
            return text;
        }
    }

    /**
     * Create default processing pipeline with standard processors.
     */
    private com.cliffmin.whisper.pipeline.ProcessingPipeline createDefaultPipeline() {
        var pipeline = new com.cliffmin.whisper.pipeline.ProcessingPipeline();

        // Add standard processors (existing logic from WhisperPostProcessorCLI)
        pipeline.addProcessor(new com.cliffmin.whisper.processors.DisfluencyProcessor());
        pipeline.addProcessor(new com.cliffmin.whisper.processors.SentenceBoundaryProcessor());
        pipeline.addProcessor(new com.cliffmin.whisper.processors.CapitalizationProcessor());
        pipeline.addProcessor(new com.cliffmin.whisper.processors.PunctuationNormalizer());

        return pipeline;
    }

    /**
     * Whisper transcription result.
     */
    static class WhisperResult {
        private final String text;
        private final JsonObject metadata;

        public WhisperResult(String text, JsonObject metadata) {
            this.text = text;
            this.metadata = metadata;
        }

        public String getText() {
            return text;
        }

        public JsonObject getMetadata() {
            return metadata;
        }
    }
}
