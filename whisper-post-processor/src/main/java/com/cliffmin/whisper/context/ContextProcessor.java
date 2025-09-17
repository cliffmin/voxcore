package com.cliffmin.whisper.context;

import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * ContextProcessor: learns preferred casing for terms based on recent transcripts.
 * Simple LRU of last N terms -> canonical casing; applies replacements.
 */
public class ContextProcessor implements com.cliffmin.whisper.pipeline.TextProcessor {
    private final int capacity;
    private final Map<String, String> casingMap;

    public ContextProcessor(int capacity) {
        this.capacity = capacity;
        this.casingMap = Collections.synchronizedMap(new LinkedHashMap<>(capacity, 0.75f, true) {
            @Override
            protected boolean removeEldestEntry(Map.Entry<String, String> eldest) {
                return size() > ContextProcessor.this.capacity;
            }
        });
    }

    public void learn(String text) {
        if (text == null) return;
        for (String token : text.split("\\s+")) {
            if (token.length() < 2) continue;
            String lower = token.toLowerCase();
            // Prefer tokens with any uppercase letters as canonical
            if (token.chars().anyMatch(Character::isUpperCase)) {
                casingMap.put(lower, token);
            } else {
                casingMap.putIfAbsent(lower, token);
            }
        }
    }

    @Override
    public String process(String input) {
        if (input == null || input.isEmpty()) return input;
        StringBuilder out = new StringBuilder(input.length());
        for (String token : input.split("(\\b)")) { // split keeping boundaries
            String lower = token.toLowerCase();
            String repl = casingMap.get(lower);
            out.append(repl != null ? repl : token);
        }
        return out.toString();
    }

    @Override
    public int getPriority() {
        return 5; // early in pipeline, before punctuation
    }
}
