package com.cliffmin.whisper.config;

import java.util.Objects;

/**
 * Immutable configuration for PTT dictation components.
 * Values may come from defaults, a JSON config file, and environment variables.
 */
public class Configuration {
    // Core
    private final String language;          // e.g., "en"
    private final String whisperModel;      // e.g., "base.en"

    // LLM / VoxCompose
    private final boolean llmEnabled;       // true to use refinement when available
    private final String llmModel;          // e.g., "llama3.2:1b"
    private final int llmTimeoutMs;         // default 30000
    private final String llmApiUrl;         // e.g., http://127.0.0.1:11434/api/generate

    // Caching
    private final boolean cacheEnabled;
    private final int cacheMaxSize;

    // Pipeline toggles
    private final boolean enableReflow;
    private final boolean enableDisfluency;
    private final boolean enableMergedWords;
    private final boolean enableSentences;
    private final boolean enableCapitalization;
    private final boolean enableDictionary;
    private final boolean enablePunctuationNormalization;
    private final boolean enablePunctuationRestoration;

    // System
    private final String notesDir;          // where to write output notes
    private final Integer audioDeviceIndex; // input device index

    private Configuration(Builder b) {
        this.language = b.language;
        this.whisperModel = b.whisperModel;
        this.llmEnabled = b.llmEnabled;
        this.llmModel = b.llmModel;
        this.llmTimeoutMs = b.llmTimeoutMs;
        this.llmApiUrl = b.llmApiUrl;
        this.cacheEnabled = b.cacheEnabled;
        this.cacheMaxSize = b.cacheMaxSize;
        this.enableReflow = b.enableReflow;
        this.enableDisfluency = b.enableDisfluency;
        this.enableMergedWords = b.enableMergedWords;
        this.enableSentences = b.enableSentences;
        this.enableCapitalization = b.enableCapitalization;
        this.enableDictionary = b.enableDictionary;
        this.enablePunctuationNormalization = b.enablePunctuationNormalization;
        this.enablePunctuationRestoration = b.enablePunctuationRestoration;
        this.notesDir = b.notesDir;
        this.audioDeviceIndex = b.audioDeviceIndex;
    }

    public static Builder defaults() {
        return new Builder()
            .language("en")
            .whisperModel("base.en")
            .llmEnabled(true)
            .llmModel("llama3.2:1b")
            .llmTimeoutMs(30000)
            .cacheEnabled(false)
            .cacheMaxSize(100)
            // Default: match current CLI defaults (all enabled)
            .enableReflow(true)
            .enableDisfluency(true)
            .enableMergedWords(true)
            .enableSentences(true)
            .enableCapitalization(true)
            .enableDictionary(true)
            .enablePunctuationNormalization(true)
            .enablePunctuationRestoration(true)
            .notesDir(System.getProperty("user.home") + "/Notes/PTT")
            .audioDeviceIndex(0);
    }

    public Builder toBuilder() {
        return new Builder()
            .language(language)
            .whisperModel(whisperModel)
            .llmEnabled(llmEnabled)
            .llmModel(llmModel)
            .llmTimeoutMs(llmTimeoutMs)
            .llmApiUrl(llmApiUrl)
            .cacheEnabled(cacheEnabled)
            .cacheMaxSize(cacheMaxSize)
            .enableReflow(enableReflow)
            .enableDisfluency(enableDisfluency)
            .enableMergedWords(enableMergedWords)
            .enableSentences(enableSentences)
            .enableCapitalization(enableCapitalization)
            .enableDictionary(enableDictionary)
            .enablePunctuationNormalization(enablePunctuationNormalization)
            .enablePunctuationRestoration(enablePunctuationRestoration)
            .notesDir(notesDir)
            .audioDeviceIndex(audioDeviceIndex);
    }

    public static class Builder {
        private String language;
        private String whisperModel;
        private boolean llmEnabled;
        private String llmModel;
        private int llmTimeoutMs;
        private String llmApiUrl;
        private boolean cacheEnabled;
        private int cacheMaxSize;
        private String notesDir;
        private Integer audioDeviceIndex;

        // Pipeline toggles
        private boolean enableReflow;
        private boolean enableDisfluency;
        private boolean enableMergedWords;
        private boolean enableSentences;
        private boolean enableCapitalization;
        private boolean enableDictionary;
        private boolean enablePunctuationNormalization;
        private boolean enablePunctuationRestoration;

        public Configuration build() { return new Configuration(this); }

        public Builder language(String v) { this.language = v; return this; }
        public Builder whisperModel(String v) { this.whisperModel = v; return this; }
        public Builder llmEnabled(boolean v) { this.llmEnabled = v; return this; }
        public Builder llmModel(String v) { this.llmModel = v; return this; }
        public Builder llmTimeoutMs(int v) { this.llmTimeoutMs = v; return this; }
        public Builder llmApiUrl(String v) { this.llmApiUrl = v; return this; }
        public Builder cacheEnabled(boolean v) { this.cacheEnabled = v; return this; }
        public Builder cacheMaxSize(int v) { this.cacheMaxSize = v; return this; }
        public Builder notesDir(String v) { this.notesDir = v; return this; }
        public Builder audioDeviceIndex(Integer v) { this.audioDeviceIndex = v; return this; }
        public Builder enableReflow(boolean v) { this.enableReflow = v; return this; }
        public Builder enableDisfluency(boolean v) { this.enableDisfluency = v; return this; }
        public Builder enableMergedWords(boolean v) { this.enableMergedWords = v; return this; }
        public Builder enableSentences(boolean v) { this.enableSentences = v; return this; }
        public Builder enableCapitalization(boolean v) { this.enableCapitalization = v; return this; }
        public Builder enableDictionary(boolean v) { this.enableDictionary = v; return this; }
        public Builder enablePunctuationNormalization(boolean v) { this.enablePunctuationNormalization = v; return this; }
        public Builder enablePunctuationRestoration(boolean v) { this.enablePunctuationRestoration = v; return this; }
    }

    // Getters
    public String getLanguage() { return language; }
    public String getWhisperModel() { return whisperModel; }
    public boolean isLlmEnabled() { return llmEnabled; }
    public String getLlmModel() { return llmModel; }
    public int getLlmTimeoutMs() { return llmTimeoutMs; }
    public String getLlmApiUrl() { return llmApiUrl; }
    public boolean isCacheEnabled() { return cacheEnabled; }
    public int getCacheMaxSize() { return cacheMaxSize; }
    public String getNotesDir() { return notesDir; }
    public Integer getAudioDeviceIndex() { return audioDeviceIndex; }
    public boolean isEnableReflow() { return enableReflow; }
    public boolean isEnableDisfluency() { return enableDisfluency; }
    public boolean isEnableMergedWords() { return enableMergedWords; }
    public boolean isEnableSentences() { return enableSentences; }
    public boolean isEnableCapitalization() { return enableCapitalization; }
    public boolean isEnableDictionary() { return enableDictionary; }
    public boolean isEnablePunctuationNormalization() { return enablePunctuationNormalization; }
    public boolean isEnablePunctuationRestoration() { return enablePunctuationRestoration; }
}
