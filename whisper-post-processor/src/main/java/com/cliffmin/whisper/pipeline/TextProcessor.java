package com.cliffmin.whisper.pipeline;

/**
 * Core interface for all text processors in the pipeline.
 * Each processor should do one thing well and be composable.
 */
public interface TextProcessor {
    
    /**
     * Process the input text and return the transformed result.
     * 
     * @param input The text to process
     * @return The processed text
     */
    String process(String input);
    
    /**
     * Get the name of this processor for logging/debugging.
     * 
     * @return The processor name
     */
    default String getName() {
        return this.getClass().getSimpleName();
    }
    
    /**
     * Whether this processor is enabled. Allows for runtime configuration.
     * 
     * @return true if enabled, false otherwise
     */
    default boolean isEnabled() {
        return true;
    }
    
    /**
     * Priority for ordering processors. Lower values run first.
     * 
     * @return The priority value
     */
    default int getPriority() {
        return 100;
    }
}
