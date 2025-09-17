package com.cliffmin.whisper.config;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.nio.file.Files;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.*;

class ConfigurationManagerTest {

    @TempDir
    Path tmp;

    @Test
    void loadsDefaults() {
        Configuration cfg = new ConfigurationManager().load(null);
        assertEquals("en", cfg.getLanguage());
        assertEquals("base.en", cfg.getWhisperModel());
        assertTrue(cfg.isLlmEnabled());
        assertEquals(30000, cfg.getLlmTimeoutMs());
    }

    @Test
    void loadsFromFile() throws Exception {
        Path file = tmp.resolve("config.json");
        Files.writeString(file, "{\n  \"language\": \"de\", \n  \"llmEnabled\": false, \n  \"cacheEnabled\": true\n}\n");
        Configuration cfg = new ConfigurationManager().load(file);
        assertEquals("de", cfg.getLanguage());
        assertFalse(cfg.isLlmEnabled());
        assertTrue(cfg.isCacheEnabled());
    }
}
