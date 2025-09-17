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
public class StreamingWebSocket {
    private final Map<WebSocketChannel, Boolean> clients = new ConcurrentHashMap<>();

    public WebSocketConnectionCallback handler() {
        return (WebSocketHttpExchange exchange, WebSocketChannel channel) -> {
            clients.put(channel, true);
            channel.getReceiveSetter().set(new AbstractReceiveListener() {
                @Override
                protected void onFullTextMessage(WebSocketChannel channel, BufferedTextMessage message) {
                    String text = message.getData();
                    // TODO: run through pipeline incrementally; stub echo for now
                    WebSockets.sendText(text, channel, null);
                }
            });
            channel.resumeReceives();
        };
    }
}
