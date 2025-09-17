package com.cliffmin.whisper.processors;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.assertThat;

public class ReflowProcessorTest {
    private ReflowProcessor processor;
    
    @BeforeEach
    void setUp() {
        processor = new ReflowProcessor();
    }
    
    @Test
    void testBasicReflow() {
        String input = "This is a test\nthat spans multiple\nlines unnecessarily.";
        String result = processor.process(input);
        assertThat(result).isEqualTo("This is a test that spans multiple lines unnecessarily.");
    }
    
    @Test
    void testPreserveSentenceBoundaries() {
        String input = "First sentence.\nSecond sentence.\nThird sentence.";
        String result = processor.process(input);
        assertThat(result).isEqualTo("First sentence. Second sentence. Third sentence.");
    }
    
    @Test
    void testPreserveQuestionMarks() {
        String input = "Is this a question?\nYes it is.\nWhat about this?";
        String result = processor.process(input);
        assertThat(result).isEqualTo("Is this a question? Yes it is. What about this?");
    }
    
    @Test
    void testHandleEmptyLines() {
        String input = "First line\n\n\nSecond line";
        String result = processor.process(input);
        assertThat(result).isEqualTo("First line Second line");
    }
    
    @Test
    void testMidSentenceBreaks() {
        String input = "This is a sentence that\nbreaks in the middle\nfor no good reason.";
        String result = processor.process(input);
        assertThat(result).isEqualTo("This is a sentence that breaks in the middle for no good reason.");
    }
    
    @Test
    void testPreserveExclamations() {
        String input = "Amazing!\nThis is great!\nWonderful news.";
        String result = processor.process(input);
        assertThat(result).isEqualTo("Amazing! This is great! Wonderful news.");
    }
    
    @Test
    void testMixedPunctuation() {
        String input = "Hello there,\nhow are you?\nI'm fine!\nThanks.";
        String result = processor.process(input);
        assertThat(result).isEqualTo("Hello there, how are you? I'm fine! Thanks.");
    }

    @Test
    void testCollapseMultipleNewlinesToSpace() {
        String input = "First line\n\n\nSecond line\n\nThird line";
        String result = processor.process(input);
        assertThat(result).isEqualTo("First line Second line Third line");
    }

    @Test
    void testCRLFNormalized() {
        String input = "A\r\nB\r\n\r\nC";
        String result = processor.process(input);
        assertThat(result).isEqualTo("A B C");
    }

    @Test
    void testNewlinesWithQuestionAndExclamation() {
        String input = "Hello?\nWorld!\nNext line";
        String result = processor.process(input);
        assertThat(result).isEqualTo("Hello? World! Next line");
    }
    
    @Test
    void testJsonSegmentProcessing() {
        // JSON input with segments
        String input = "{\"segments\": [{\"text\": \"First part\"}, {\"text\": \"second part\"}]}";
        // For now, plain text processing doesn't parse JSON
        String result = processor.process(input);
        // Should process as plain text
        assertThat(result).isNotNull();
    }
    
    @Test
    void testEmptyInput() {
        String result = processor.process("");
        assertThat(result).isEmpty();
    }
    
    @Test
    void testNullInput() {
        String result = processor.process(null);
        assertThat(result).isNull();
    }
    
    @Test
    void testSingleLine() {
        String input = "This is a single line with no breaks.";
        String result = processor.process(input);
        assertThat(result).isEqualTo("This is a single line with no breaks.");
    }
    
    @Test
    void testTrailingWhitespace() {
        String input = "Line with trailing spaces    \nNext line   ";
        String result = processor.process(input);
        assertThat(result).isEqualTo("Line with trailing spaces Next line");
    }
}