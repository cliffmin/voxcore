package com.cliffmin.whisper.service;

import java.nio.file.Path;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;

/**
 * Interface for Whisper transcription services.
 * Provides abstraction over different Whisper implementations (whisper.cpp, OpenAI Whisper, etc.)
 */
public interface WhisperService {
    
    /**
     * Transcription result containing text and metadata.
     */
    class TranscriptionResult {
        private final String text;
        private final List<Segment> segments;
        private final String language;
        private final double duration;
        private final Map<String, Object> metadata;
        
        public TranscriptionResult(String text, List<Segment> segments, String language, 
                                  double duration, Map<String, Object> metadata) {
            this.text = text;
            this.segments = segments;
            this.language = language;
            this.duration = duration;
            this.metadata = metadata;
        }
        
        public String getText() { return text; }
        public List<Segment> getSegments() { return segments; }
        public String getLanguage() { return language; }
        public double getDuration() { return duration; }
        public Map<String, Object> getMetadata() { return metadata; }
    }
    
    /**
     * Represents a transcription segment with timing information.
     */
    class Segment {
        private final int id;
        private final double start;
        private final double end;
        private final String text;
        private final double confidence;
        
        public Segment(int id, double start, double end, String text, double confidence) {
            this.id = id;
            this.start = start;
            this.end = end;
            this.text = text;
            this.confidence = confidence;
        }
        
        public int getId() { return id; }
        public double getStart() { return start; }
        public double getEnd() { return end; }
        public String getText() { return text; }
        public double getConfidence() { return confidence; }
    }
    
    /**
     * Transcription options.
     */
    class TranscriptionOptions {
        private String model = "base.en";
        private String language = "en";
        private boolean timestamps = true;
        private String outputFormat = "json";
        private int beamSize = 5;
        private double temperatureIncrement = 0.2;
        private boolean noSpeechThreshold = true;
        
        // Builder pattern for easy configuration
        public static class Builder {
            private final TranscriptionOptions options = new TranscriptionOptions();
            
            public Builder model(String model) {
                options.model = model;
                return this;
            }
            
            public Builder language(String language) {
                options.language = language;
                return this;
            }
            
            public Builder timestamps(boolean timestamps) {
                options.timestamps = timestamps;
                return this;
            }
            
            public Builder outputFormat(String format) {
                options.outputFormat = format;
                return this;
            }
            
            public Builder beamSize(int size) {
                options.beamSize = size;
                return this;
            }
            
            public TranscriptionOptions build() {
                return options;
            }
        }
        
        // Getters
        public String getModel() { return model; }
        public String getLanguage() { return language; }
        public boolean hasTimestamps() { return timestamps; }
        public String getOutputFormat() { return outputFormat; }
        public int getBeamSize() { return beamSize; }
        public double getTemperatureIncrement() { return temperatureIncrement; }
        public boolean hasNoSpeechThreshold() { return noSpeechThreshold; }
    }
    
    /**
     * Transcribe an audio file synchronously.
     * 
     * @param audioPath Path to the audio file (WAV format preferred)
     * @param options Transcription options
     * @return Transcription result
     * @throws TranscriptionException if transcription fails
     */
    TranscriptionResult transcribe(Path audioPath, TranscriptionOptions options) 
        throws TranscriptionException;
    
    /**
     * Transcribe an audio file asynchronously.
     * 
     * @param audioPath Path to the audio file
     * @param options Transcription options  
     * @return CompletableFuture with transcription result
     */
    CompletableFuture<TranscriptionResult> transcribeAsync(Path audioPath, TranscriptionOptions options);
    
    /**
     * Detect the best model to use based on audio duration.
     * 
     * @param durationSeconds Audio duration in seconds
     * @return Recommended model name
     */
    String detectModel(double durationSeconds);
    
    /**
     * Validate if an audio file is suitable for transcription.
     * 
     * @param audioPath Path to the audio file
     * @return true if file is valid
     */
    boolean validateAudioFile(Path audioPath);
    
    /**
     * Check if the service is available and properly configured.
     * 
     * @return true if service is ready
     */
    boolean isAvailable();
    
    /**
     * Get the name of this Whisper implementation.
     * 
     * @return Implementation name (e.g., "whisper.cpp", "openai-whisper")
     */
    String getImplementationName();
    
    /**
     * Exception thrown when transcription fails.
     */
    class TranscriptionException extends Exception {
        public TranscriptionException(String message) {
            super(message);
        }
        
        public TranscriptionException(String message, Throwable cause) {
            super(message, cause);
        }
    }
}