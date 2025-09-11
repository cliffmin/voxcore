package com.cliffmin.whisper.processors;

import com.cliffmin.whisper.pipeline.TextProcessor;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Ensures proper capitalization of sentences and proper nouns.
 */
public class CapitalizationProcessor implements TextProcessor {
    
    // Pattern for sentence starts (after punctuation)
    private static final Pattern SENTENCE_START = Pattern.compile("(^|[.!?]\\s+)([a-z])");
    
    @Override
    public String process(String input) {
        if (input == null || input.isEmpty()) {
            return input;
        }
        
        String result = input;
        
        // Capitalize first letter of text
        if (Character.isLowerCase(result.charAt(0))) {
            result = Character.toUpperCase(result.charAt(0)) + result.substring(1);
        }
        
        // Capitalize after sentence endings
        result = capitalizeSentenceStarts(result);
        
        // Fix "i" to "I"
        result = result.replaceAll("\\bi\\b", "I");
        
        return result;
    }
    
    private String capitalizeSentenceStarts(String text) {
        Matcher matcher = SENTENCE_START.matcher(text);
        StringBuffer sb = new StringBuffer();
        
        while (matcher.find()) {
            String prefix = matcher.group(1);
            String letter = matcher.group(2);
            matcher.appendReplacement(sb, prefix + letter.toUpperCase());
        }
        matcher.appendTail(sb);
        
        return sb.toString();
    }
    
    @Override
    public int getPriority() {
        return 30; // Run after sentence boundary fixes
    }
}
