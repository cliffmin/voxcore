package com.cliffmin.whisper.processors;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

public class DictionaryProcessorTest {
    private DictionaryProcessor processor;
    
    @TempDir
    Path tempDir;
    
    @BeforeEach
    void setUp() {
        processor = new DictionaryProcessor();
    }
    
    @Test
    void testDefaultReplacements() {
        // Test some default technical term replacements
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
    void testCustomDictionaryFile() throws IOException {
        // Create a custom dictionary file
        Path configDir = tempDir.resolve(".config/ptt-dictation");
        Files.createDirectories(configDir);
        Path dictFile = configDir.resolve("dictionary.json");
        
        String customDict = """
            {
                "replacements": {
                    "testword": "REPLACED",
                    "oldterm": "newterm"
                }
            }
            """;
        Files.writeString(dictFile, customDict);
        
        // Create processor with custom dictionary location
        System.setProperty("user.home", tempDir.toString());
        DictionaryProcessor customProcessor = new DictionaryProcessor();
        
        String input = "This testword and oldterm should change.";
        String result = customProcessor.process(input);
        assertThat(result).isEqualTo("This REPLACED and newterm should change.");
        
        // Reset system property
        System.clearProperty("user.home");
    }
    
    @Test
    void testAbbreviations() {
        String input = "The api uses json and xml formats.";
        String result = processor.process(input);
        assertThat(result).isEqualTo("The API uses JSON and XML formats.");
    }
    
    @Test
    void testPreserveOriginalCase() {
        String input = "Python python PYTHON";
        String result = processor.process(input);
        assertThat(result).isEqualTo("Python Python Python");
    }
    
    @Test
    void testPhraseReplacement() {
        // If the processor supports phrase replacements
        String input = "machine learning and artificial intelligence";
        String result = processor.process(input);
        // Default dictionary may have ML and AI mappings
        assertThat(result).contains("machine learning", "artificial intelligence");
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
    
    @Test
    void testInvalidDictionary() throws IOException {
        // Create an invalid dictionary file
        Path configDir = tempDir.resolve(".config/ptt-dictation");
        Files.createDirectories(configDir);
        Path dictFile = configDir.resolve("dictionary.json");
        
        Files.writeString(dictFile, "invalid json content");
        
        System.setProperty("user.home", tempDir.toString());
        DictionaryProcessor customProcessor = new DictionaryProcessor();
        
        // Should fall back to defaults on error
        String input = "Testing github fallback.";
        String result = customProcessor.process(input);
        assertThat(result).isEqualTo("Testing GitHub fallback.");
        
        System.clearProperty("user.home");
    }
}