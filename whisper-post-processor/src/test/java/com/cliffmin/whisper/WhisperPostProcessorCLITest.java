package com.cliffmin.whisper;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.assertj.core.api.Assertions.assertThat;

class WhisperPostProcessorCLITest {

    @TempDir
    Path tmp;

    @Test
    void printsConfigFromOverride() throws Exception {
        Path cfgFile = tmp.resolve("config.json");
        Files.writeString(cfgFile, "{\n  \"language\": \"fr\", \n  \"whisperModel\": \"small.en\"\n}\n");

        ProcessBuilder pb = new ProcessBuilder(
            "java", "-cp", "build/libs/whisper-post.jar",
            "com.cliffmin.whisper.WhisperPostProcessorCLI",
            "--print-config"
        );
        pb.environment().put("JAVA_TOOL_OPTIONS", "");
        pb.environment().put("_JAVA_OPTIONS", "");
        pb.environment().put("PTT_LANG", "en"); // Will be overridden by file due to explicit override property
        pb.environment().put("PTT_WHISPER_MODEL", "base.en");
        pb.command().add(0, "bash");
        pb.command().add(1, "-lc");
        pb.command().add(2, String.format("java -Dptt.config.file=%s -cp build/libs/whisper-post.jar com.cliffmin.whisper.WhisperPostProcessorCLI --print-config", cfgFile.toString()));
        pb.directory(tmp.getParent().getParent().resolve("whisper-post-processor").toFile());

        Process p = pb.start();
        p.waitFor();
        try (BufferedReader br = new BufferedReader(new InputStreamReader(p.getInputStream()))) {
            String out = br.lines().reduce("", (a,b) -> a + b);
            assertThat(out).contains("\"language\":\"fr\"");
            assertThat(out).contains("\"whisperModel\":\"small.en\"");
        }
    }
}
