package com.cliffmin.whisper.daemon;

import org.junit.jupiter.api.*;

import java.io.IOException;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;

import static org.junit.jupiter.api.Assertions.*;

@Tag("integration")
class PTTServiceDaemonTest {

    private PTTServiceDaemon daemon;

    @BeforeEach
    void setup() {
        daemon = new PTTServiceDaemon();
        daemon.start(8876);
    }

    @AfterEach
    void teardown() {
        daemon.stop();
    }

    @Test
    void healthEndpoint() throws Exception {
        URL url = new URL("http://127.0.0.1:8876/health");
        HttpURLConnection conn = (HttpURLConnection) url.openConnection();
        conn.setRequestMethod("GET");
        assertEquals(200, conn.getResponseCode());
    }

    @Test
    void transcribeEndpoint_missingFile() throws Exception {
        URL url = new URL("http://127.0.0.1:8876/transcribe");
        HttpURLConnection conn = (HttpURLConnection) url.openConnection();
        conn.setRequestMethod("POST");
        conn.setDoOutput(true);
        conn.setRequestProperty("Content-Type", "application/json");
        byte[] body = "{\"path\":\"/no/such/file.wav\"}".getBytes(StandardCharsets.UTF_8);
        conn.getOutputStream().write(body);
        assertEquals(400, conn.getResponseCode());
    }
}
