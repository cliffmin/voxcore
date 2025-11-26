package com.cliffmin.whisper.processors;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.assertThat;

import java.util.HashMap;
import java.util.Map;

public class DictionaryProcessorTest {
    private DictionaryProcessor processor;
    
    @BeforeEach
    void setUp() {
        processor = new DictionaryProcessor();
    }
    
    @Test
    void testDefaultReplacements() {
        String input = "I'm using github for version control.";
        String result = processor.process(input);
        assertThat(result).isEqualTo("I'm using GitHub for version control.");
    }
    
    @Test
    void testCaseInsensitiveMatch() {
        String input = "GITHUB and github and GitHub are all the same.";
        String result = processor.process(input);
        assertThat(result).isEqualTo("GitHub and GitHub and GitHub are all the same.");
    }
    
    @Test
    void testMultipleReplacements() {
        String input = "Using javascript with typescript and nodejs.";
        String result = processor.process(input);
        assertThat(result).isEqualTo("Using JavaScript with TypeScript and Node.js.");
    }
    
    @Test
    void testWordBoundaries() {
        // Should not replace within words
        String input = "githubproject should not change.";
        String result = processor.process(input);
        assertThat(result).isEqualTo("githubproject should not change.");
    }
    
    @Test
    void testCustomDictionary() {
        Map<String, String> custom = new HashMap<>();
        custom.put("testword", "REPLACED");
        custom.put("oldterm", "newterm");
        DictionaryProcessor customProcessor = new DictionaryProcessor(custom);
        
        String input = "This testword and oldterm should change.";
        String result = customProcessor.process(input);
        assertThat(result).isEqualTo("This REPLACED and newterm should change.");
    }
    
    @Test
    void testAbbreviations() {
        String input = "The api uses json and xml formats.";
        String result = processor.process(input);
        assertThat(result).isEqualTo("The API uses JSON and XML formats.");
    }
    
    @Test
    void testCloudProviders() {
        String input = "We deploy to aws and gcp with kubernetes.";
        String result = processor.process(input);
        assertThat(result).isEqualTo("We deploy to AWS and GCP with Kubernetes.");
    }
    
    @Test
    void testAITerms() {
        String input = "Using llm and ml for ai applications with chatgpt.";
        String result = processor.process(input);
        assertThat(result).isEqualTo("Using LLM and ML for AI applications with ChatGPT.");
    }
    
    @Test
    void testOperatingSystems() {
        String input = "Runs on macos, linux, and ios.";
        String result = processor.process(input);
        assertThat(result).isEqualTo("Runs on macOS, Linux, and iOS.");
    }
    
    @Test
    void testFrameworks() {
        String input = "Built with react, vue, and springboot.";
        String result = processor.process(input);
        assertThat(result).isEqualTo("Built with React, Vue, and Spring Boot.");
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
    void testNoReplacements() {
        String input = "This text has no replaceable words.";
        String result = processor.process(input);
        assertThat(result).isEqualTo("This text has no replaceable words.");
    }
    
    @Test
    void testPunctuationPreserved() {
        String input = "Using github, typescript, and nodejs!";
        String result = processor.process(input);
        assertThat(result).isEqualTo("Using GitHub, TypeScript, and Node.js!");
    }
    
    @Test
    void testMixedContent() {
        String input = "The javascript API returns json data from github.";
        String result = processor.process(input);
        assertThat(result).isEqualTo("The JavaScript API returns JSON data from GitHub.");
    }
}
