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
}
