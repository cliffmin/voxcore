package com.cliffmin.whisper.daemon;

import com.cliffmin.whisper.service.WhisperService;
import com.cliffmin.whisper.service.WhisperCppAdapter;
import com.cliffmin.whisper.audio.AudioProcessor;
import com.google.gson.Gson;
import io.undertow.Undertow;
import io.undertow.server.HttpHandler;
import io.undertow.server.HttpServerExchange;
import io.undertow.util.Headers;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.Deque;
import java.util.HashMap;
import java.util.Map;

/**
 * Minimal HTTP daemon to expose transcription to Hammerspoon.
 * Endpoints:
 *  - GET /health -> { status: "ok" }
 *  - POST /transcribe (multipart/form-data or JSON with path)
 */
public class PTTServiceDaemon {
    private final Gson gson = new Gson();
    private final WhisperService whisper = new WhisperCppAdapter();
    private final AudioProcessor audio = new AudioProcessor();
    private Undertow server;

    public void start(int port) {
        server = Undertow.builder()
                .addHttpListener(port, "127.0.0.1")
                .setHandler(this::route)
                .build();
        server.start();
    }

    public void stop() {
        if (server != null) server.stop();
    }

    private void route(HttpServerExchange exchange) throws Exception {
        exchange.getResponseHeaders().put(Headers.CONTENT_TYPE, "application/json");
        String path = exchange.getRequestPath();
        if ("/health".equals(path)) {
            handleHealth(exchange);
        } else if ("/transcribe".equals(path) && exchange.getRequestMethod().equalToString("POST")) {
            handleTranscribe(exchange);
        } else {
            exchange.setStatusCode(404);
            exchange.getResponseSender().send("{\"error\":\"not found\"}");
        }
    }

    private void handleHealth(HttpServerExchange exchange) {
        Map<String, Object> resp = new HashMap<>();
        resp.put("status", "ok");
        resp.put("whisperAvailable", whisper.isAvailable());
        exchange.getResponseSender().send(gson.toJson(resp));
    }

    private void handleTranscribe(HttpServerExchange exchange) {
        exchange.startBlocking();
        try {
            // For simplicity, accept a JSON body: { "path": "/abs/path.wav", "model":"base.en" }
            String body = new String(exchange.getInputStream().readAllBytes());
            Map<?,?> req = gson.fromJson(body, Map.class);
            String audioPathStr = (String) req.get("path");
            String model = (String) req.getOrDefault("model", "base.en");

            Path audioPath = Path.of(audioPathStr);
            if (!Files.exists(audioPath)) {
                exchange.setStatusCode(400);
                exchange.getResponseSender().send("{\"error\":\"audio file not found\"}");
                return;
            }

            // Normalize to Whisper format
            Path normalized = Files.createTempFile("ptt_norm_", ".wav");
            audio.normalizeForWhisper(audioPath, normalized);

            // Detect model based on duration if not provided
            double duration = audio.getDuration(normalized);
            String selectedModel = (model == null || model.isBlank()) ? whisper.detectModel(duration) : model;

            WhisperService.TranscriptionOptions options = new WhisperService.TranscriptionOptions.Builder()
                    .model(selectedModel)
                    .language("en")
                    .timestamps(true)
                    .build();

            WhisperService.TranscriptionResult result = whisper.transcribe(normalized, options);

            Map<String, Object> resp = new HashMap<>();
            resp.put("text", result.getText());
            resp.put("language", result.getLanguage());
            resp.put("duration", result.getDuration());
            resp.put("segments", result.getSegments());
            resp.put("metadata", result.getMetadata());

            exchange.getResponseSender().send(gson.toJson(resp));
            Files.deleteIfExists(normalized);
        } catch (Exception e) {
            exchange.setStatusCode(500);
            exchange.getResponseSender().send(gson.toJson(Map.of("error", e.getMessage())));
        }
    }

    public static void main(String[] args) {
        int port = 8765;
        new PTTServiceDaemon().start(port);
        System.out.println("PTTServiceDaemon started on http://127.0.0.1:" + port);
    }
}
