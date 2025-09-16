package com.cliffmin.whisper.pipeline;

import com.cliffmin.whisper.processors.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;
import static org.assertj.core.api.Assertions.*;

class ProcessingPipelineTest {
    
    private ProcessingPipeline pipeline;
    
    @BeforeEach
    void setUp() {
        pipeline = new ProcessingPipeline()
            .addProcessor(new MergedWordProcessor())
            .addProcessor(new SentenceBoundaryProcessor())
            .addProcessor(new CapitalizationProcessor())
            .addProcessor(new PunctuationNormalizer());
    }
    
    @Test
    @DisplayName("Should process complete pipeline")
    void testCompletePipeline() {
        String input = "theyconfigure the system that'slike important withthe apikey";
        String output = pipeline.process(input);
        
        assertThat(output)
            .startsWith("They configure")
            .contains("API key")
            .endsWith(".");
    }
    
    @Test
    @DisplayName("Should fix run-on sentences")
    void testRunOnSentences() {
        String input = "this is one sentence and this is another sentence without punctuation";
        String output = pipeline.process(input);
        
        assertThat(output).contains(". ");
    }
    
    @Test
    @DisplayName("Should handle real-world transcription")
    void testRealWorldExample() {
        String input = "i'mjust implementing the servicelayer theydon't know what'sthe issue";
        String output = pipeline.process(input);
        
        assertThat(output).isEqualTo("I'm just implementing the service layer they don't know what's the issue.");
    }
    
    @Test
    @DisplayName("Should preserve already correct text")
    void testPreserveCorrectText() {
        String input = "This is already correct text.";
        String output = pipeline.process(input);
        
        assertThat(output).isEqualTo(input);
    }
    
    @Test
    @DisplayName("Should respect processor priority")
    void testProcessorPriority() {
        // Create a test processor that adds a marker
        TextProcessor marker = new TextProcessor() {
            @Override
            public String process(String input) {
                return input + " [MARKED]";
            }
            
            @Override
            public int getPriority() {
                return 5; // Should run first
            }
        };
        
        ProcessingPipeline testPipeline = new ProcessingPipeline()
            .addProcessor(new CapitalizationProcessor()) // Priority 30
            .addProcessor(marker); // Priority 5
        
        String output = testPipeline.process("test");
        assertThat(output).isEqualTo("Test [MARKED]");
    }
    
    @Test
    @DisplayName("Should handle empty pipeline")
    void testEmptyPipeline() {
        ProcessingPipeline emptyPipeline = new ProcessingPipeline();
        String input = "test input";
        assertThat(emptyPipeline.process(input)).isEqualTo(input);
    }
    
    @Test
    @DisplayName("Should handle disabled processors")
    void testDisabledProcessor() {
        TextProcessor disabledProcessor = new TextProcessor() {
            @Override
            public String process(String input) {
                return "SHOULD NOT APPEAR";
            }
            
            @Override
            public boolean isEnabled() {
                return false;
            }
        };
        
        pipeline.addProcessor(disabledProcessor);
        String output = pipeline.process("test");
        assertThat(output).doesNotContain("SHOULD NOT APPEAR");
    }
}
