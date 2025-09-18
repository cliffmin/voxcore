package com.cliffmin.whisper;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.ByteArrayOutputStream;
import java.io.PrintStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

import static org.assertj.core.api.Assertions.assertThat;

class WhisperPostProcessorCLITest {

    @TempDir
    Path tmp;

    @Test
    void printsConfigFromOverride() throws Exception {
        Path cfgFile = tmp.resolve("config.json");
        Files.writeString(cfgFile, "{\n  \"language\": \"fr\", \n  \"whisperModel\": \"small.en\"\n}\n");

        // Run CLI in-process to avoid external jar dependency
        System.setProperty("ptt.config.file", cfgFile.toString());
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        PrintStream origOut = System.out;
        try {
            System.setOut(new PrintStream(baos));
            int exit = new picocli.CommandLine(new com.cliffmin.whisper.WhisperPostProcessorCLI())
                    .execute("--print-config");
        } finally {
            System.setOut(origOut);
        }
        String out = baos.toString().trim();
        assertThat(out).contains("\"language\":\"fr\"");
        assertThat(out).contains("\"whisperModel\":\"small.en\"");
    }
}
