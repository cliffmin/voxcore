package com.cliffmin.whisper.pipeline;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

/**
 * Manages a pipeline of text processors that are executed in sequence.
 */
public class ProcessingPipeline {
    private static final Logger logger = LoggerFactory.getLogger(ProcessingPipeline.class);
    
    private final List<TextProcessor> processors = new ArrayList<>();
    private boolean debugMode = false;
    
    /**
     * Add a processor to the pipeline.
     */
    public ProcessingPipeline addProcessor(TextProcessor processor) {
        processors.add(processor);
        return this;
    }
    
    /**
     * Process text through all enabled processors in priority order.
     */
    public String process(String input) {
        if (input == null || input.isEmpty()) {
            return input;
        }
        
        // Sort by priority
        List<TextProcessor> sortedProcessors = processors.stream()
            .filter(TextProcessor::isEnabled)
            .sorted(Comparator.comparingInt(TextProcessor::getPriority))
            .toList();
        
        String result = input;
        for (TextProcessor processor : sortedProcessors) {
            String before = result;
            long startTime = System.nanoTime();
            
            result = processor.process(result);
            
            if (debugMode) {
                long elapsedMs = (System.nanoTime() - startTime) / 1_000_000;
                logger.debug("{} took {}ms", processor.getName(), elapsedMs);
                if (!before.equals(result)) {
                    logger.debug("{} modified text", processor.getName());
                }
            }
        }
        
        return result;
    }
    
    /**
     * Enable debug mode for detailed logging.
     */
    public ProcessingPipeline setDebugMode(boolean debug) {
        this.debugMode = debug;
        return this;
    }
    
    /**
     * Get the number of processors in the pipeline.
     */
    public int size() {
        return processors.size();
    }
    
    /**
     * Clear all processors from the pipeline.
     */
    public void clear() {
        processors.clear();
    }
}
