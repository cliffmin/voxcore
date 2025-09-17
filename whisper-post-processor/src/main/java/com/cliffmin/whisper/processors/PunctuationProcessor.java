package com.cliffmin.whisper.processors;

import com.cliffmin.whisper.pipeline.TextProcessor;
import java.util.regex.Pattern;
import java.util.regex.Matcher;

/**
 * Adds punctuation to unpunctuated or poorly punctuated text.
 * Replaces the Python deepmultilingualpunctuation dependency.
 */
public class PunctuationProcessor implements TextProcessor {
    
    // Common abbreviations that should keep their periods
    private static final Pattern ABBREVIATION = Pattern.compile(
        "\\b(Mr|Mrs|Ms|Dr|Prof|Sr|Jr|Inc|Ltd|Corp|Co|vs|etc|i\\.e|e\\.g|Ph\\.D|M\\.D|B\\.A|M\\.A|B\\.S|M\\.S)\\.",
        Pattern.CASE_INSENSITIVE
    );
    
    // Question words that typically start questions
    private static final Pattern QUESTION_START = Pattern.compile(
        "^(who|what|when|where|why|how|which|whose|whom|is|are|do|does|did|can|could|would|should|will|won't|isn't|aren't|doesn't|didn't|can't|couldn't|wouldn't|shouldn't)\\b",
        Pattern.CASE_INSENSITIVE
    );
    
    @Override
    public String process(String input) {
        if (input == null || input.isEmpty()) {
            return input;
        }
        
        String result = input;
        
        // Step 1: Add sentence-ending punctuation
        result = addSentenceEndings(result);
        
        // Step 2: Add commas for common patterns
        result = addCommas(result);
        
        // Step 3: Fix spacing around punctuation
        result = fixPunctuationSpacing(result);
        
        // Step 4: Capitalize sentences
        result = capitalizeSentences(result);
        
        return result;
    }
    
    private String addSentenceEndings(String text) {
        // Split into potential sentences
        String[] lines = text.split("\\n");
        StringBuilder result = new StringBuilder();
        
        for (String line : lines) {
            if (line.trim().isEmpty()) {
                result.append(line).append("\n");
                continue;
            }
            
            // Check if line already ends with punctuation
            String trimmed = line.trim();
            if (!trimmed.matches(".*[.!?]$")) {
                // Check if it looks like a question
                if (QUESTION_START.matcher(trimmed).find()) {
                    line = trimmed + "?";
                } else {
                    // Add period unless it's likely an abbreviation
                    if (!ABBREVIATION.matcher(trimmed).find()) {
                        line = trimmed + ".";
                    }
                }
            }
            
            if (result.length() > 0) {
                result.append("\n");
            }
            result.append(line);
        }
        
        return result.toString();
    }
    
    private String addCommas(String text) {
        // Add commas after common introductory adverbs
        text = text.replaceAll("\\b(However|Therefore|Moreover|Furthermore|Additionally|Also|Next|Then|Finally)\\s+", "$1, ");
        
        // Add commas after enumerators only when followed by a pronoun (to avoid 'First sentence' false positives)
        text = text.replaceAll("(?m)^(First|Second|Third)\\s+(?=(I|We|You|They|He|She|It)\\b)", "$1, ");
        
        // Add commas before coordinating conjunctions in compound sentences
        text = text.replaceAll("\\s+(but|and|or|nor|for|yet|so)\\s+(?=[A-Z])", ", $1 ");
        
        // Add commas in lists (simplified - just handles "X Y and Z" pattern)
        text = text.replaceAll("\\b(\\w+)\\s+(\\w+)\\s+and\\s+(\\w+)\\b", "$1, $2, and $3");
        
        return text;
    }
    
    private String fixPunctuationSpacing(String text) {
        // Remove spaces before punctuation
        text = text.replaceAll("\\s+([.!?,;:])", "$1");
        
        // Ensure space after punctuation (except at end of string)
        text = text.replaceAll("([.!?,;:])(?=\\S)", "$1 ");
        
        // Remove duplicate punctuation
        text = text.replaceAll("([.!?])+", "$1");
        
        // Fix comma before question/exclamation (",?" -> "?")
        text = text.replaceAll(",\\s*([!?])", "$1");
        
        // Fix multiple commas
        text = text.replaceAll(",\\s*,+", ",");
        
        return text;
    }
    
    private String capitalizeSentences(String text) {
        // Capitalize first letter of text
        if (!text.isEmpty() && Character.isLowerCase(text.charAt(0))) {
            text = Character.toUpperCase(text.charAt(0)) + text.substring(1);
        }
        
        // Capitalize after sentence endings
        Pattern sentenceEnd = Pattern.compile("([.!?]\\s+)([a-z])");
        Matcher matcher = sentenceEnd.matcher(text);
        
        StringBuffer sb = new StringBuffer();
        while (matcher.find()) {
            matcher.appendReplacement(sb, matcher.group(1) + matcher.group(2).toUpperCase());
        }
        matcher.appendTail(sb);
        
        return sb.toString();
    }
    
    @Override
    public int getPriority() {
        return 25; // Run after other processors but before final cleanup
    }
}