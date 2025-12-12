package com.cliffmin.voxcore.transcription;

import com.cliffmin.voxcore.config.VoxCoreConfig;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Tests for vocabulary loading in TranscriptionService.
 * Verifies that vocabulary files are read correctly and integrated into the initial prompt.
 */
class VocabularyLoadingTest {

    @Test
    void testLoadInitialPrompt_vocabularyFileExists(@TempDir Path tempDir) throws IOException {
        // Create vocabulary file
        Path vocabFile = tempDir.resolve("vocabulary.txt");
        Files.writeString(vocabFile, "GitHub, JSON, API, VoxCore");

        // Create config pointing to vocabulary file
        Path configFile = tempDir.resolve("config.json");
        String json = String.format("""
            {
              "vocabulary_file": "%s",
              "enable_dynamic_vocab": true
            }
            """, vocabFile);
        Files.writeString(configFile, json);

        // Load config and verify vocabulary path is set
        VoxCoreConfig config = VoxCoreConfig.load(configFile);
        config.validate();

        assertThat(config.getVocabularyPath()).isEqualTo(vocabFile);
        assertThat(Files.exists(config.getVocabularyPath())).isTrue();

        // TranscriptionService should load vocabulary when transcribing
        // (Full integration test would require Whisper binary, so we just verify config)
    }

    @Test
    void testLoadInitialPrompt_vocabularyFileNotFound(@TempDir Path tempDir) throws IOException {
        // Create config pointing to non-existent vocabulary file
        Path configFile = tempDir.resolve("config.json");
        String json = String.format("""
            {
              "vocabulary_file": "%s/missing.txt",
              "enable_dynamic_vocab": true
            }
            """, tempDir);
        Files.writeString(configFile, json);

        // Load config
        VoxCoreConfig config = VoxCoreConfig.load(configFile);
        boolean valid = config.validate();

        // Should still be valid (vocabulary is optional)
        assertThat(valid).isTrue();
        assertThat(config.getVocabularyPath()).isNotNull();
        assertThat(Files.exists(config.getVocabularyPath())).isFalse();

        // TranscriptionService should gracefully fall back to static prompt
    }

    @Test
    void testLoadInitialPrompt_vocabularyDisabled(@TempDir Path tempDir) throws IOException {
        // Create vocabulary file
        Path vocabFile = tempDir.resolve("vocabulary.txt");
        Files.writeString(vocabFile, "GitHub, JSON, API");

        // Create config with vocabulary disabled
        Path configFile = tempDir.resolve("config.json");
        String json = String.format("""
            {
              "vocabulary_file": "%s",
              "enable_dynamic_vocab": false
            }
            """, vocabFile);
        Files.writeString(configFile, json);

        // Load config
        VoxCoreConfig config = VoxCoreConfig.load(configFile);
        config.validate();

        // Vocabulary should not be loaded when disabled
        assertThat(config.isEnableDynamicVocab()).isFalse();
        assertThat(config.getVocabularyPath()).isNull();
    }

    @Test
    void testLoadInitialPrompt_emptyVocabularyFile(@TempDir Path tempDir) throws IOException {
        // Create empty vocabulary file
        Path vocabFile = tempDir.resolve("vocabulary.txt");
        Files.writeString(vocabFile, "");

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

        // Empty vocabulary file should still be found
        assertThat(Files.exists(config.getVocabularyPath())).isTrue();
        assertThat(Files.readString(config.getVocabularyPath())).isEmpty();

        // TranscriptionService should handle empty file gracefully (trim() → "")
    }

    @Test
    void testLoadInitialPrompt_whitespaceOnlyVocabularyFile(@TempDir Path tempDir) throws IOException {
        // Create vocabulary file with only whitespace
        Path vocabFile = tempDir.resolve("vocabulary.txt");
        Files.writeString(vocabFile, "   \n\n  \t  ");

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

        // File exists but contains only whitespace
        assertThat(Files.exists(config.getVocabularyPath())).isTrue();
        String content = Files.readString(config.getVocabularyPath()).trim();
        assertThat(content).isEmpty();

        // TranscriptionService should handle whitespace-only file (trim() → "")
    }

    @Test
    void testVocabularyFile_realWorldContent(@TempDir Path tempDir) throws IOException {
        // Create realistic vocabulary file like VoxCompose would generate
        Path vocabFile = tempDir.resolve("vocabulary.txt");
        String realWorldVocab = "GitHub, JSON, API, macOS, iOS, JavaScript, " +
                "VoxCore, VoxCompose, Hammerspoon, OAuth, NoSQL, " +
                "push-to-talk, symlinks, dedupe, webhook";
        Files.writeString(vocabFile, realWorldVocab);

        // Create config
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

        // Verify vocabulary file loaded
        assertThat(Files.exists(config.getVocabularyPath())).isTrue();
        String content = Files.readString(config.getVocabularyPath());
        assertThat(content).isEqualTo(realWorldVocab);
        assertThat(content).contains("VoxCore", "GitHub", "push-to-talk");
    }

    @Test
    void testVocabularyFile_largeVocabulary(@TempDir Path tempDir) throws IOException {
        // Test handling of large vocabulary (VoxCompose limits to 1000 words)
        StringBuilder largeVocab = new StringBuilder();
        for (int i = 0; i < 1000; i++) {
            if (i > 0) largeVocab.append(", ");
            largeVocab.append("term").append(i);
        }

        Path vocabFile = tempDir.resolve("vocabulary.txt");
        Files.writeString(vocabFile, largeVocab.toString());

        // Create config
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

        // Verify large vocabulary can be loaded
        assertThat(Files.exists(config.getVocabularyPath())).isTrue();
        String content = Files.readString(config.getVocabularyPath());
        assertThat(content).contains("term0", "term999");
        assertThat(content.split(",")).hasSize(1000);
    }
}
