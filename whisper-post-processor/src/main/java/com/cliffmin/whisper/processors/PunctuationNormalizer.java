package com.cliffmin.whisper.processors;

import com.cliffmin.whisper.pipeline.TextProcessor;

/**
 * Normalizes spacing around punctuation marks.
 */
public class PunctuationNormalizer implements TextProcessor {
    
    @Override
    public String process(String input) {
        if (input == null || input.isEmpty()) {
            return input;
        }
        
        String result = input;
        
        // Remove spaces before punctuation
        result = result.replaceAll("\\s+([,.!?;:])", "$1");
        
        // Ensure space after punctuation (except at end)
        result = result.replaceAll("([,.!?;:])([A-Za-z])", "$1 $2");
        
        // Collapse multiple spaces
        result = result.replaceAll("\\s+", " ");
        
        // Remove leading/trailing whitespace
        result = result.trim();
        
        // Collapse multiple periods
        result = result.replaceAll("\\.{2,}", ".");
        
        return result;
    }
    
    @Override
    public int getPriority() {
        return 40; // Run last, cleanup pass
    }
}
