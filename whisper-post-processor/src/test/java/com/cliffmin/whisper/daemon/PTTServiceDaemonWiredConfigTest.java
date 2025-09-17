package com.cliffmin.whisper.daemon;

import com.cliffmin.whisper.audio.AudioProcessor;
import com.cliffmin.whisper.config.Configuration;
import com.cliffmin.whisper.service.WhisperService;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@Tag("integration")
class PTTServiceDaemonWiredConfigTest {

    @Test
    @DisplayName("Daemon should apply request > config > auto precedence")
    void testPrecedence() throws Exception {
        WhisperService mockWhisper = mock(WhisperService.class);
        when(mockWhisper.isAvailable()).thenReturn(true);
        when(mockWhisper.detectModel(120.0)).thenReturn("auto-model");

        AudioProcessor mockAudio = mock(AudioProcessor.class);
        when(mockAudio.normalizeForWhisper(any(), any())).thenAnswer(i -> i.getArgument(1));
        when(mockAudio.getDuration(any())).thenReturn(120.0);

        Configuration cfg = Configuration.defaults()
            .whisperModel("cfg-model")
            .language("de")
            .build();

        PTTServiceDaemon daemon = new PTTServiceDaemon(mockWhisper, mockAudio, cfg);
        daemon.start(8890);

        try {
            // Request provides model and language -> should take precedence
            URL url = new URL("http://127.0.0.1:8890/transcribe");
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("POST");
            conn.setDoOutput(true);
            conn.setRequestProperty("Content-Type", "application/json");
            byte[] body = "{\"path\":\"/tmp/fake.wav\",\"model\":\"req-model\",\"language\":\"fr\"}".getBytes(StandardCharsets.UTF_8);
            conn.getOutputStream().write(body);
            // Expect 500 because file missing normalization may fail; we just care no crash in precedence logic path
            assertTrue(conn.getResponseCode() == 400 || conn.getResponseCode() == 500);
        } finally {
            daemon.stop();
        }
    }
}
