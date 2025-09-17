package com.cliffmin.whisper.config;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Locale;

/**
 * Loads configuration from defaults, file, and environment variables with precedence:
 * env > file > defaults
 */
public class ConfigurationManager {
    private final Gson gson = new Gson();

    public Configuration load(Path filePath) {
        Configuration.Builder b = Configuration.defaults();

        // 1) File
        if (filePath != null && Files.exists(filePath)) {
            try {
                String content = Files.readString(filePath);
                JsonObject json = JsonParser.parseString(content).getAsJsonObject();
                applyFile(b, json);
            } catch (IOException ignored) {}
        }

        // 2) Env
        applyEnv(b);

        return b.build();
    }

    private void applyFile(Configuration.Builder b, JsonObject json) {
        if (json.has("language")) b.language(json.get("language").getAsString());
        if (json.has("whisperModel")) b.whisperModel(json.get("whisperModel").getAsString());
        if (json.has("llmEnabled")) b.llmEnabled(json.get("llmEnabled").getAsBoolean());
        if (json.has("llmModel")) b.llmModel(json.get("llmModel").getAsString());
        if (json.has("llmTimeoutMs")) b.llmTimeoutMs(json.get("llmTimeoutMs").getAsInt());
        if (json.has("llmApiUrl")) b.llmApiUrl(json.get("llmApiUrl").getAsString());
        if (json.has("cacheEnabled")) b.cacheEnabled(json.get("cacheEnabled").getAsBoolean());
        if (json.has("cacheMaxSize")) b.cacheMaxSize(json.get("cacheMaxSize").getAsInt());
        if (json.has("notesDir")) b.notesDir(json.get("notesDir").getAsString());
        if (json.has("audioDeviceIndex")) b.audioDeviceIndex(json.get("audioDeviceIndex").getAsInt());
    }

    private void applyEnv(Configuration.Builder b) {
        String v;
        v = getenv("PTT_LANG"); if (v != null) b.language(v);
        v = getenv("PTT_WHISPER_MODEL"); if (v != null) b.whisperModel(v);
        v = getenv("VOX_REFINE"); if (v != null) b.llmEnabled(!isFalsey(v));
        v = getenv("AI_AGENT_MODEL"); if (v != null) b.llmModel(v);
        v = getenv("AI_AGENT_URL"); if (v != null) b.llmApiUrl(normalizeEndpoint(v));
        v = getenv("VOX_TIMEOUT_MS"); if (v != null) b.llmTimeoutMs(Integer.parseInt(v));
        v = getenv("VOX_CACHE_ENABLED"); if (v != null) b.cacheEnabled("1".equals(v));
        v = getenv("VOX_CACHE_SIZE"); if (v != null) b.cacheMaxSize(Integer.parseInt(v));
        v = getenv("PTT_NOTES_DIR"); if (v != null) b.notesDir(v);
        v = getenv("PTT_AUDIO_DEVICE"); if (v != null) b.audioDeviceIndex(Integer.parseInt(v));
    }

    private String normalizeEndpoint(String base) {
        String normalized = base.replaceAll("/+$$", "");
        if (!normalized.endsWith("/api/generate")) {
            return normalized + "/api/generate";
        }
        return normalized;
    }

    private boolean isFalsey(String s) {
        String v = s.trim().toLowerCase(Locale.ROOT);
        return v.equals("0") || v.equals("false") || v.equals("no") || v.equals("off");
    }

    private String getenv(String k) {
        String v = System.getenv(k);
        return (v == null || v.isBlank()) ? null : v;
    }
}
