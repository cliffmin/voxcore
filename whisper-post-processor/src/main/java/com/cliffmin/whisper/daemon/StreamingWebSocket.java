package com.cliffmin.whisper.daemon;

import io.undertow.Undertow;
import io.undertow.server.handlers.PathHandler;
import io.undertow.server.handlers.BlockingHandler;
import io.undertow.server.handlers.resource.ClassPathResourceManager;
import io.undertow.server.HttpServerExchange;
import io.undertow.util.Headers;
import io.undertow.websockets.core.WebSocketChannel;
import io.undertow.websockets.core.WebSockets;
import io.undertow.websockets.spi.WebSocketHttpExchange;
import io.undertow.websockets.WebSocketConnectionCallback;
import io.undertow.websockets.core.AbstractReceiveListener;
import io.undertow.websockets.core.BufferedTextMessage;

import java.util.Deque;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Minimal WebSocket endpoint for streaming partial text refinements.
 * URL: ws://127.0.0.1:8765/ws
 * Protocol: client sends text chunks; server echoes refined text (stub) for now.
 */
import com.cliffmin.whisper.pipeline.ProcessingPipeline;

public class StreamingWebSocket {
    private final Map<WebSocketChannel, StringBuilder> buffers = new ConcurrentHashMap<>();
    private final ProcessingPipeline pipeline;
    private final java.util.function.Consumer<Void> onMessageHook;

    public StreamingWebSocket(ProcessingPipeline pipeline, java.util.function.Consumer<Void> onMessageHook) {
        this.pipeline = pipeline;
        this.onMessageHook = onMessageHook;
    }

    public WebSocketConnectionCallback handler() {
        return (WebSocketHttpExchange exchange, WebSocketChannel channel) -> {
            buffers.put(channel, new StringBuilder());
            channel.addCloseTask(ch -> buffers.remove(ch));
            channel.getReceiveSetter().set(new AbstractReceiveListener() {
                @Override
                protected void onFullTextMessage(WebSocketChannel channel, BufferedTextMessage message) {
                    String chunk = message.getData();
                    StringBuilder buf = buffers.getOrDefault(channel, new StringBuilder());
                    buf.append(chunk);
                    buffers.put(channel, buf);

                    // Process accumulated buffer through pipeline
                    String processed = pipeline.process(buf.toString());
                    // Return JSON with processed text
                    String json = "{\"processed\":" + com.google.gson.internal.bind.TypeAdapters.STRING.toJsonTree(processed).toString() + "}";
                    WebSockets.sendText(json, channel, null);
                    if (onMessageHook != null) onMessageHook.accept(null);
                }
            });
            channel.resumeReceives();
        };
    }
}
