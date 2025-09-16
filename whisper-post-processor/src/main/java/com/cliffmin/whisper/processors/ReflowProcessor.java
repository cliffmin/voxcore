package com.cliffmin.whisper.processors;

import com.cliffmin.whisper.pipeline.TextProcessor;
import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import java.util.ArrayList;
import java.util.List;

/**
 * Reflows Whisper segments into readable text with proper paragraph breaks.
 * Handles both JSON segments and plain text input.
 */
public class ReflowProcessor implements TextProcessor {
    
    private final double gapNewlineSec;
    private final double gapDoubleNewlineSec;
    private final boolean dropLowConfidence;
    private final double lowConfNoSpeechProb;
    private final double lowConfAvgLogprob;
    
    public ReflowProcessor() {
        this(1.75, 2.50, true, 0.5, -1.0);
    }
    
    public ReflowProcessor(double gapNewlineSec, double gapDoubleNewlineSec,
                          boolean dropLowConfidence, double lowConfNoSpeechProb, 
                          double lowConfAvgLogprob) {
        this.gapNewlineSec = gapNewlineSec;
        this.gapDoubleNewlineSec = gapDoubleNewlineSec;
        this.dropLowConfidence = dropLowConfidence;
        this.lowConfNoSpeechProb = lowConfNoSpeechProb;
        this.lowConfAvgLogprob = lowConfAvgLogprob;
    }
    
    @Override
    public String process(String input) {
        if (input == null || input.isEmpty()) {
            return input;
        }
        
        // Try to parse as JSON first
        try {
            JsonElement element = JsonParser.parseString(input);
            if (element.isJsonObject()) {
                JsonObject root = element.getAsJsonObject();
                
                if (root.has("segments") || root.has("transcription")) {
                    JsonArray segments = root.has("segments") 
                        ? root.getAsJsonArray("segments") 
                        : root.getAsJsonArray("transcription");
                    return processSegments(segments);
                }
                
                // If JSON but no segments, treat as plain text
                if (root.has("text")) {
                    return processPlainText(root.get("text").getAsString());
                }
            }
        } catch (Exception e) {
            // Not JSON, process as plain text
        }
        
        return processPlainText(input);
    }
    
    private String processSegments(JsonArray segments) {
        List<Segment> filtered = new ArrayList<>();
        
        // Filter low-confidence segments if enabled
        for (JsonElement elem : segments) {
            if (!elem.isJsonObject()) continue;
            JsonObject seg = elem.getAsJsonObject();
            boolean keep = true;
            
            if (dropLowConfidence) {
                double noSpeechProb = seg.has("no_speech_prob") 
                    ? seg.get("no_speech_prob").getAsDouble() : 0.0;
                double avgLogprob = seg.has("avg_logprob") 
                    ? seg.get("avg_logprob").getAsDouble() : 0.0;
                    
                if (noSpeechProb >= lowConfNoSpeechProb || avgLogprob <= lowConfAvgLogprob) {
                    keep = false;
                }
            }
            
            if (keep && seg.has("text")) {
                Segment segment = new Segment();
                segment.text = seg.get("text").getAsString().trim();
                segment.start = seg.has("start") ? seg.get("start").getAsDouble() : 0;
                segment.end = getSegmentEnd(seg);
                filtered.add(segment);
            }
        }
        
        if (filtered.isEmpty()) {
            return "";
        }
        
        // Join segments with gap-based formatting
        StringBuilder result = new StringBuilder();
        Double lastEnd = null;
        
        for (Segment seg : filtered) {
            if (lastEnd != null && seg.start > 0) {
                double gap = seg.start - lastEnd;
                String prev = result.toString();
                boolean sentenceEnd = prev.matches(".*[.!?]\\s*$");
                
                if (gap >= gapDoubleNewlineSec) {
                    result.append("\n\n");
                } else if (sentenceEnd || gap >= gapNewlineSec) {
                    result.append("\n");
                } else if (result.length() > 0 && !prev.endsWith(" ") 
                        && !seg.text.matches("^[,.:;!?].*")) {
                    result.append(" ");
                }
            }
            
            result.append(seg.text);
            lastEnd = seg.end;
        }
        
        String text = result.toString();
        
        // Normalize spacing
        text = text.replaceAll("\\s+([,.:;!?])", "$1");
        text = text.replaceAll("\\s+\\n", "\n");
        text = text.replaceAll("\\n\\s+", "\n");
        text = text.replaceAll("\\n{3,}", "\n\n");
        
        return text.trim();
    }
    
    private double getSegmentEnd(JsonObject seg) {
        if (seg.has("end")) return seg.get("end").getAsDouble();
        if (seg.has("e")) return seg.get("e").getAsDouble();
        if (seg.has("t1")) return seg.get("t1").getAsDouble();
        if (seg.has("offset_to")) return seg.get("offset_to").getAsDouble();
        if (seg.has("start")) return seg.get("start").getAsDouble();
        return 0;
    }
    
    private String processPlainText(String text) {
        // Simple reflow for plain text
        text = text.replaceAll("\\r\\n", "\n");
        
        // Mark double newlines, collapse singles, restore doubles
        text = text.replaceAll("\\n\\n", "<P>\n");
        text = text.replaceAll("\\n", " ");
        text = text.replaceAll("<P>\n", "\n\n");
        
        // Normalize spacing
        text = text.replaceAll("\\s+([,.:;!?])", "$1");
        text = text.replaceAll("[ \\t]+", " ");
        text = text.replaceAll("[ \\t]+\\n", "\n");
        
        return text.trim();
    }
    
    @Override
    public int getPriority() {
        return 5; // Run first, before other processors
    }
    
    private static class Segment {
        String text;
        double start;
        double end;
    }
}