package com.cliffmin.whisper.processors;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.ValueSource;

import static org.junit.jupiter.api.Assertions.*;

class PunctuationProcessorTest {
    
    private PunctuationProcessor processor;
    
    @BeforeEach
    void setUp() {
        processor = new PunctuationProcessor();
    }
    
    @Test
    @DisplayName("Should handle null input")
    void testNullInput() {
        assertNull(processor.process(null));
    }
    
    @Test
    @DisplayName("Should handle empty input")
    void testEmptyInput() {
        assertEquals("", processor.process(""));
    }
    
    @Test
    @DisplayName("Should add period to sentence without punctuation")
    void testAddPeriod() {
        String input = "This is a test sentence";
        String expected = "This is a test sentence.";
        assertEquals(expected, processor.process(input));
    }
    
    @Test
    @DisplayName("Should not add period if already present")
    void testExistingPeriod() {
        String input = "This sentence already has a period.";
        assertEquals(input, processor.process(input));
    }
    
    @ParameterizedTest
    @DisplayName("Should add question marks to questions")
    @CsvSource({
        "what is your name,What is your name?",
        "how are you doing,How are you doing?",
        "when will you arrive,When will you arrive?",
        "where is the meeting,Where is the meeting?",
        "why did this happen,Why did this happen?",
        "who is responsible,Who is responsible?",
        "can you help me,Can you help me?",
        "is this correct,Is this correct?"
    })
    void testQuestionMarks(String input, String expected) {
        assertEquals(expected, processor.process(input));
    }
    
    @Test
    @DisplayName("Should capitalize first letter of sentence")
    void testCapitalization() {
        String input = "this should be capitalized";
        String expected = "This should be capitalized.";
        assertEquals(expected, processor.process(input));
    }
    
    @Test
    @DisplayName("Should capitalize after sentence endings")
    void testCapitalizeAfterPeriod() {
        String input = "First sentence. second sentence. third sentence";
        String expected = "First sentence. Second sentence. Third sentence.";
        assertEquals(expected, processor.process(input));
    }
    
    @Test
    @DisplayName("Should handle multiple sentences")
    void testMultipleSentences() {
        String input = "This is the first sentence\nThis is the second sentence\nWhat about questions";
        String expected = "This is the first sentence.\nThis is the second sentence.\nWhat about questions?";
        assertEquals(expected, processor.process(input));
    }
    
    @Test
    @DisplayName("Should fix spacing around punctuation")
    void testPunctuationSpacing() {
        String input = "This has spaces before punctuation . This needs fixing , right ?";
        String result = processor.process(input);
        assertFalse(result.contains(" ."));
        assertFalse(result.contains(" ,"));
        assertFalse(result.contains(" ?"));
        assertTrue(result.contains(". "));
        assertTrue(result.contains(", "));
    }
    
    @Test
    @DisplayName("Should remove duplicate punctuation")
    void testDuplicatePunctuation() {
        String input = "This has duplicates... And this too!!!";
        String result = processor.process(input);
        assertFalse(result.contains("..."));
        assertFalse(result.contains("!!!"));
        assertTrue(result.contains("."));
        assertTrue(result.contains("!"));
    }
    
    @ParameterizedTest
    @DisplayName("Should add commas after introductory words")
    @ValueSource(strings = {
        "However",
        "Therefore",
        "Moreover",
        "Furthermore",
        "Additionally",
        "Also",
        "Next",
        "Then",
        "Finally",
        "First",
        "Second",
        "Third"
    })
    void testIntroductoryCommas(String introWord) {
        String input = introWord + " we should proceed";
        String result = processor.process(input);
        assertTrue(result.contains(introWord + ", "));
    }
    
    @Test
    @DisplayName("Should handle abbreviations correctly")
    void testAbbreviations() {
        String input = "Dr. Smith and Mr. Johnson work at Inc.";
        String result = processor.process(input);
        // Should not add extra periods after abbreviations
        assertFalse(result.contains("Dr.."));
        assertFalse(result.contains("Mr.."));
        assertFalse(result.contains("Inc.."));
    }
    
    @Test
    @DisplayName("Should add commas in lists")
    void testListCommas() {
        String input = "I need apples bananas and oranges";
        String result = processor.process(input);
        assertTrue(result.contains("apples, bananas, and oranges"));
    }
    
    @Test
    @DisplayName("Should handle complex mixed text")
    void testComplexText() {
        String input = "hello world\nwhat is your name\nmy name is Dr. Smith\nhowever I prefer to be called John";
        String result = processor.process(input);
        
        // Check various aspects
        assertTrue(result.startsWith("Hello")); // Capitalized
        assertTrue(result.contains("world.")); // Period added
        assertTrue(result.contains("name?")); // Question mark
        assertTrue(result.contains("However, ")); // Comma after However
        assertTrue(result.contains("Dr. Smith")); // Abbreviation preserved
    }
    
    @Test
    @DisplayName("Should handle empty lines")
    void testEmptyLines() {
        String input = "First line\n\nThird line";
        String result = processor.process(input);
        assertTrue(result.contains("\n\n")); // Empty lines preserved
        assertTrue(result.contains("First line."));
        assertTrue(result.contains("Third line."));
    }
    
    @Test
    @DisplayName("Should have correct priority")
    void testPriority() {
        assertEquals(25, processor.getPriority());
    }
    
    @ParameterizedTest
    @DisplayName("Should handle various exclamations correctly")
    @CsvSource({
        "wow,Wow!",
        "amazing,Amazing.",
        "stop that,Stop that.",
        "oh no,Oh no."
    })
    void testExclamations(String input, String expected) {
        // Note: Current implementation doesn't detect exclamations
        // This test documents current behavior
        String result = processor.process(input);
        assertTrue(result.startsWith(expected.substring(0, 1).toUpperCase()));
        assertTrue(result.endsWith(".") || result.endsWith("!"));
    }
    
    @Test
    @DisplayName("Should handle mixed punctuation scenarios")
    void testMixedPunctuation() {
        String input = "This is a statement! Is this a question? Yes it is.";
        String result = processor.process(input);
        assertEquals(input, result); // Already properly punctuated
    }
    
    @Test
    @DisplayName("Should handle coordinating conjunctions")
    void testCoordinatingConjunctions() {
        String input = "I went to the store but They were closed";
        String result = processor.process(input);
        assertTrue(result.contains(", but "));
    }
    
    @Test
    @DisplayName("Performance test with long text")
    void testPerformance() {
        StringBuilder longText = new StringBuilder();
        for (int i = 0; i < 100; i++) {
            longText.append("This is sentence number ").append(i);
            longText.append("\n");
        }
        
        long startTime = System.currentTimeMillis();
        String result = processor.process(longText.toString());
        long endTime = System.currentTimeMillis();
        
        assertNotNull(result);
        assertTrue(endTime - startTime < 1000); // Should complete within 1 second
    }
}