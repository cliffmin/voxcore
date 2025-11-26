package com.cliffmin.whisper.processors;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;
import static org.assertj.core.api.Assertions.*;

class MergedWordProcessorTest {
    
    private MergedWordProcessor processor;
    
    @BeforeEach
    void setUp() {
        processor = new MergedWordProcessor();
    }
    
    @Test
    @DisplayName("Should fix merged contractions")
    void testMergedContractions() {
        assertThat(processor.process("that'slike")).isEqualTo("that's like");
        assertThat(processor.process("it'slike")).isEqualTo("it's like");
        assertThat(processor.process("i'mjust")).isEqualTo("I'm just");
        assertThat(processor.process("don'tknow")).isEqualTo("don't know");
    }
    
    @Test
    @DisplayName("Should fix 'they' mergers")
    void testTheyMergers() {
        assertThat(processor.process("theyconfigure")).isEqualTo("they configure");
        assertThat(processor.process("theydon't")).isEqualTo("they don't");
        assertThat(processor.process("theywere")).isEqualTo("they were");
    }
    
    @Test
    @DisplayName("Should fix preposition mergers")
    void testPrepositionMergers() {
        assertThat(processor.process("withthe")).isEqualTo("with the");
        assertThat(processor.process("inthe")).isEqualTo("in the");
        assertThat(processor.process("forthe")).isEqualTo("for the");
    }
    
    @Test
    @DisplayName("Should fix technical terms")
    void testTechnicalTerms() {
        assertThat(processor.process("apikey")).isEqualTo("API key");
        assertThat(processor.process("servicelayer")).isEqualTo("service layer");
        assertThat(processor.process("usecase")).isEqualTo("use case");
    }
    
    @Test
    @DisplayName("Should preserve case when possible")
    void testCasePreservation() {
        assertThat(processor.process("Theyconfigure")).isEqualTo("They configure");
        assertThat(processor.process("APIKEY")).isEqualTo("API key");
    }
    
    @Test
    @DisplayName("Should handle complex sentences")
    void testComplexSentences() {
        String input = "theyconfigure the system withthe apikey validation";
        String expected = "they configure the system with the API key validation";
        assertThat(processor.process(input)).isEqualTo(expected);
    }
    
    @Test
    @DisplayName("Should not modify correct text")
    void testNoModification() {
        String correct = "They configure the system properly";
        assertThat(processor.process(correct)).isEqualTo(correct);
    }
    
    @Test
    @DisplayName("Should handle null and empty input")
    void testNullAndEmpty() {
        assertThat(processor.process(null)).isNull();
        assertThat(processor.process("")).isEqualTo("");
        assertThat(processor.process("  ")).isEqualTo("  ");
    }
    
    // === NEW TESTS: Sentence boundary merging (currently failing) ===
    
    @Test
    @DisplayName("Should fix sentence boundary merging with period")
    void testSentenceBoundaryPeriod() {
        // Real examples from recordings: staff.I, easy.And, approach.That
        assertThat(processor.process("staff.I don't know")).isEqualTo("staff. I don't know");
        assertThat(processor.process("easy.And I think")).isEqualTo("easy. And I think");
        assertThat(processor.process("approach.That's the")).isEqualTo("approach. That's the");
    }
    
    @Test
    @DisplayName("Should fix sentence boundary merging with question mark")
    void testSentenceBoundaryQuestion() {
        // Real example: I?Like
        assertThat(processor.process("do I?Like, I read")).isEqualTo("do I? Like, I read");
        assertThat(processor.process("status?Don't know")).isEqualTo("status? Don't know");
    }
    
    @Test
    @DisplayName("Should fix sentence boundary merging with exclamation")
    void testSentenceBoundaryExclamation() {
        assertThat(processor.process("works!And then")).isEqualTo("works! And then");
        assertThat(processor.process("great!The next")).isEqualTo("great! The next");
    }
    
    // === NEW TESTS: Missing common patterns (currently failing) ===
    
    @Test
    @DisplayName("Should fix word+and mergers")
    void testWordAndMergers() {
        // Real example: statementand
        assertThat(processor.process("the statementand then")).isEqualTo("the statement and then");
        assertThat(processor.process("problemand solution")).isEqualTo("problem and solution");
    }
    
    @Test
    @DisplayName("Should fix word+then/you mergers")
    void testWordThenYouMergers() {
        // Real examples: thenyou, toThen
        assertThat(processor.process("and thenyou told me")).isEqualTo("and then you told me");
        assertThat(processor.process("want toThen we")).isEqualTo("want to. Then we");
    }
    
    @Test
    @DisplayName("Should fix the+word mergers beyond 'the'")
    void testTheWordMergers() {
        // Real example: thecustom
        assertThat(processor.process("if thecustom field")).isEqualTo("if the custom field");
        assertThat(processor.process("check thevalue of")).isEqualTo("check the value of");
    }
}
