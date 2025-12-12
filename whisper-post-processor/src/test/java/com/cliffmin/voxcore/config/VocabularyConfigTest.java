package com.cliffmin.voxcore.config;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Tests for vocabulary file configuration and path expansion.
 */
class VocabularyConfigTest {

    @Test
    void testDefaultVocabularyPath() {
        VoxCoreConfig config = new VoxCoreConfig();
        config.validate();

        // Default path should be ~/.config/voxcompose/vocabulary.txt
        Path vocabPath = config.getVocabularyPath();
        String expectedPath = System.getProperty("user.home") + "/.config/voxcompose/vocabulary.txt";
        assertThat(vocabPath).hasToString(expectedPath);
    }

    @Test
    void testVocabularyEnabled_byDefault() {
        VoxCoreConfig config = new VoxCoreConfig();
        assertThat(config.isEnableDynamicVocab()).isTrue();
    }

    @Test
    void testLoadConfig_withCustomVocabularyPath(@TempDir Path tempDir) throws IOException {
        // Create config JSON with custom vocabulary path using tilde
        Path configFile = tempDir.resolve("config.json");
        String json = """
            {
              "vocabulary_file": "~/custom/vocab.txt",
              "enable_dynamic_vocab": true
            }
            """;
        Files.writeString(configFile, json);

        // Load config
        VoxCoreConfig config = VoxCoreConfig.load(configFile);
        config.validate();

        // Verify vocabulary path expanded correctly
        Path vocabPath = config.getVocabularyPath();
        String expectedPath = System.getProperty("user.home") + "/custom/vocab.txt";
        assertThat(vocabPath).hasToString(expectedPath);
        assertThat(config.isEnableDynamicVocab()).isTrue();
    }

    @Test
    void testLoadConfig_withEnvVarPath(@TempDir Path tempDir) throws IOException {
        // Create config JSON with environment variable path
        Path configFile = tempDir.resolve("config.json");
        String json = """
            {
              "vocabulary_file": "$HOME/.vocab/words.txt"
            }
            """;
        Files.writeString(configFile, json);

        // Load config
        VoxCoreConfig config = VoxCoreConfig.load(configFile);
        config.validate();

        // Verify vocabulary path expanded correctly
        Path vocabPath = config.getVocabularyPath();
        String expectedPath = System.getProperty("user.home") + "/.vocab/words.txt";
        assertThat(vocabPath).hasToString(expectedPath);
    }

    @Test
    void testLoadConfig_vocabularyDisabled(@TempDir Path tempDir) throws IOException {
        // Create config with vocabulary disabled
        Path configFile = tempDir.resolve("config.json");
        String json = """
            {
              "enable_dynamic_vocab": false
            }
            """;
        Files.writeString(configFile, json);

        // Load config
        VoxCoreConfig config = VoxCoreConfig.load(configFile);
        config.validate();

        // Verify vocabulary disabled (should not expand path)
        assertThat(config.isEnableDynamicVocab()).isFalse();
        assertThat(config.getVocabularyPath()).isNull();
    }

    @Test
    void testLoadConfig_nullVocabularyFile(@TempDir Path tempDir) throws IOException {
        // Create config with explicit null vocabulary file
        Path configFile = tempDir.resolve("config.json");
        String json = """
            {
              "vocabulary_file": null
            }
            """;
        Files.writeString(configFile, json);

        // Load config
        VoxCoreConfig config = VoxCoreConfig.load(configFile);
        config.validate();

        // Should handle null gracefully
        assertThat(config.getVocabularyPath()).isNull();
    }

    @Test
    void testLoadConfig_emptyVocabularyFile(@TempDir Path tempDir) throws IOException {
        // Create config with empty vocabulary file path
        Path configFile = tempDir.resolve("config.json");
        String json = """
            {
              "vocabulary_file": ""
            }
            """;
        Files.writeString(configFile, json);

        // Load config
        VoxCoreConfig config = VoxCoreConfig.load(configFile);
        config.validate();

        // Empty string should be treated as null (PathExpander.expandToPath returns null)
        assertThat(config.getVocabularyPath()).isNull();
    }

    @Test
    void testVocabularyFile_missingFile_noError(@TempDir Path tempDir) throws IOException {
        // Create config pointing to non-existent vocabulary file
        Path configFile = tempDir.resolve("config.json");
        String json = String.format("""
            {
              "vocabulary_file": "%s/nonexistent/vocab.txt",
              "enable_dynamic_vocab": true
            }
            """, tempDir);
        Files.writeString(configFile, json);

        // Load config
        VoxCoreConfig config = VoxCoreConfig.load(configFile);
        boolean valid = config.validate();

        // Missing vocabulary file should NOT cause validation failure (it's optional)
        assertThat(valid).isTrue();
        assertThat(config.getValidationErrors()).isEmpty();

        // Path should still be expanded, just not exist
        Path vocabPath = config.getVocabularyPath();
        assertThat(vocabPath).isNotNull();
        assertThat(Files.exists(vocabPath)).isFalse();
    }

    @Test
    void testVocabularyFile_existingFile(@TempDir Path tempDir) throws IOException {
        // Create actual vocabulary file
        Path vocabFile = tempDir.resolve("vocab.txt");
        Files.writeString(vocabFile, "GitHub, JSON, API");

        // Create config pointing to it
        Path configFile = tempDir.resolve("config.json");
        String json = String.format("""
            {
              "vocabulary_file": "%s",
              "enable_dynamic_vocab": true
            }
            """, vocabFile);
        Files.writeString(configFile, json);

        // Load config
        VoxCoreConfig config = VoxCoreConfig.load(configFile);
        config.validate();

        // Verify vocabulary file found
        Path vocabPath = config.getVocabularyPath();
        assertThat(vocabPath).isEqualTo(vocabFile);
        assertThat(Files.exists(vocabPath)).isTrue();
    }
}
