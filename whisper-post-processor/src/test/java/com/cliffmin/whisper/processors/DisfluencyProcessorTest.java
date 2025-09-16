package com.cliffmin.whisper.processors;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.assertThat;

public class DisfluencyProcessorTest {
    private DisfluencyProcessor processor;
    
    @BeforeEach
    void setUp() {
        processor = new DisfluencyProcessor();
    }
    
    @Test
    void testRemoveUm() {
        String input = "Um, this is a test.";
        String result = processor.process(input);
        assertThat(result).isEqualTo("This is a test.");
    }
    
    @Test
    void testRemoveUh() {
        String input = "This is, uh, a test.";
        String result = processor.process(input);
        assertThat(result).isEqualTo("This is, a test.");
    }
    
    @Test
    void testRemoveMultipleDisfluencies() {
        String input = "Um, you know, I think, uh, we should, like, probably go.";
        String result = processor.process(input);
        assertThat(result).isEqualTo("I think, we should, probably go.");
    }
    
    @Test
    void testRemoveYouKnow() {
        String input = "You know, this is important, you know?";
        String result = processor.process(input);
        assertThat(result).isEqualTo("This is important?");
    }
    
    @Test
    void testRemoveSortOf() {
        String input = "It's sort of difficult to explain.";
        String result = processor.process(input);
        assertThat(result).isEqualTo("It's difficult to explain.");
    }
    
    @Test
    void testRemoveKindOf() {
        String input = "This is kind of what I meant.";
        String result = processor.process(input);
        assertThat(result).isEqualTo("This is what I meant.");
    }
    
    @Test
    void testRemoveLike() {
        String input = "It's like, really important, like totally.";
        String result = processor.process(input);
        assertThat(result).isEqualTo("It's really important, totally.");
    }
    
    @Test
    void testPreserveMeaningfulLike() {
        String input = "I like ice cream.";
        String result = processor.process(input);
        assertThat(result).isEqualTo("I like ice cream.");
    }
    
    @Test
    void testRemoveIMean() {
        String input = "I mean, what I'm trying to say is important.";
        String result = processor.process(input);
        assertThat(result).isEqualTo("What I'm trying to say is important.");
    }
    
    @Test
    void testRemoveActually() {
        String input = "Actually, this is actually quite simple.";
        String result = processor.process(input);
        assertThat(result).isEqualTo("This is quite simple.");
    }
    
    @Test
    void testRemoveBasically() {
        String input = "Basically, it's basically done.";
        String result = processor.process(input);
        assertThat(result).isEqualTo("It's done.");
    }
    
    @Test
    void testCaseInsensitive() {
        String input = "UM, this is UH, a TEST, you KNOW?";
        String result = processor.process(input);
        assertThat(result).isEqualTo("This is a TEST?");
    }
    
    @Test
    void testCleanupExtraSpaces() {
        String input = "Um,    this   has   uh,   extra    spaces.";
        String result = processor.process(input);
        assertThat(result).isEqualTo("This has extra spaces.");
    }
    
    @Test
    void testCleanupExtraCommas() {
        String input = "This is, um, , uh, a test.";
        String result = processor.process(input);
        assertThat(result).isEqualTo("This is, a test.");
    }
    
    @Test
    void testHandleStartOfSentence() {
        String input = "Um, hello. Uh, goodbye. You know, see you later.";
        String result = processor.process(input);
        assertThat(result).isEqualTo("Hello. Goodbye. See you later.");
    }
    
    @Test
    void testComplexRealWorldExample() {
        String input = "So, um, I was thinking, you know, that we should, uh, " +
                      "probably, like, consider the, sort of, implications of this, " +
                      "I mean, decision.";
        String result = processor.process(input);
        assertThat(result).isEqualTo("So, I was thinking, that we should, probably, " +
                                     "consider the, implications of this, decision.");
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
    void testNoDisfluencies() {
        String input = "This is a clean sentence with no disfluencies.";
        String result = processor.process(input);
        assertThat(result).isEqualTo("This is a clean sentence with no disfluencies.");
    }
    
    @Test
    void testRepeatedWords() {
        String input = "I I think we we should go go there.";
        String result = processor.process(input);
        assertThat(result).isEqualTo("I think we should go there.");
    }
    
    @Test 
    void testStuttering() {
        String input = "Th-th-this is a t-t-test.";
        String result = processor.process(input);
        assertThat(result).isEqualTo("This is a test.");
    }
}