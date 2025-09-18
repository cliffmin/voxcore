package com.cliffmin.whisper.processors;

import com.cliffmin.whisper.pipeline.TextProcessor;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;
import java.util.regex.Pattern;

/**
 * Removes disfluencies (filler words) from transcripts.
 * Handles both beginning disfluencies and standalone fillers.
 */
public class DisfluencyProcessor implements TextProcessor {
    
    private final Set<String> standaloneDisfluencies;
    private final Set<String> beginningDisfluencies;
    private final boolean stripBeginning;
    
    public DisfluencyProcessor() {
        this(
            new HashSet<>(Arrays.asList(
                "uh", "um", "uhh", "uhm", "er", "erm",
                "you know", "i mean", "like", "sort of", "kind of",
                "actually", "basically", "literally", "obviously",
                "I guess", "I suppose"
            )),
            new HashSet<>(Arrays.asList(
                "um", "uh", "uhh", "uhm", "er", "erm",
                "well", "you know", "i mean", "actually",
                "basically", "literally"
            )),
            true
        );
    }
    
    public DisfluencyProcessor(Set<String> standaloneDisfluencies,
                               Set<String> beginningDisfluencies,
                               boolean stripBeginning) {
        this.standaloneDisfluencies = standaloneDisfluencies;
        this.beginningDisfluencies = beginningDisfluencies;
        this.stripBeginning = stripBeginning;
    }
    
    @Override
    public String process(String input) {
        if (input == null || input.isEmpty()) {
            return input;
        }
        
        String result = input;
        
        // Strip beginning disfluencies
        if (stripBeginning) {
            result = stripBeginningDisfluencies(result);
        }
        
        // Remove standalone disfluencies throughout
        result = removeStandaloneDisfluencies(result);
        
        // Remove immediate repeats
        result = dedupeImmediateRepeats(result);
        
        // Cleanup awkward punctuation (e.g., ",?" -> "?")
        result = result.replaceAll(",\\s*([!?])", "$1");
        
        // Capitalize after sentence endings
        result = capitalizeAfterSentenceEnds(result);
        
        // Ensure the first character is capitalized if it starts with a letter
        if (!result.isEmpty() && Character.isLowerCase(result.charAt(0))) {
            result = Character.toUpperCase(result.charAt(0)) + result.substring(1);
        }
        
        return result;
    }
    
    private String stripBeginningDisfluencies(String text) {
        if (text == null || text.isEmpty()) {
            return text;
        }
        
        String result = text.trim();
        boolean found = true;
        
        // Keep removing beginning disfluencies until none found
        while (found) {
            found = false;
            String lower = result.toLowerCase();
            
            for (String disfluency : beginningDisfluencies) {
                // Build pattern for this disfluency
                String escapedDisfluency = Pattern.quote(disfluency);
                String pattern = "(?i)^" + escapedDisfluency + "(\\s*[,.]?\\s+|[,.]?$)";
                Pattern p = Pattern.compile(pattern);
                
                if (p.matcher(result).find()) {
                    // Remove the disfluency
                    result = result.replaceFirst(pattern, "").trim();
                    found = true;
                    break;
                }
            }
        }
        
        // Capitalize first letter if needed
        if (!result.isEmpty() && Character.isLowerCase(result.charAt(0))) {
            result = Character.toUpperCase(result.charAt(0)) + result.substring(1);
        }
        
        return result;
    }
    
    private String capitalizeAfterSentenceEnds(String text) {
        java.util.regex.Pattern sentenceEnd = java.util.regex.Pattern.compile("([.!?]\\s+)([a-z])");
        java.util.regex.Matcher matcher = sentenceEnd.matcher(text);
        StringBuffer sb = new StringBuffer();
        while (matcher.find()) {
            matcher.appendReplacement(sb, matcher.group(1) + matcher.group(2).toUpperCase());
        }
        matcher.appendTail(sb);
        return sb.toString();
    }
    
    private String removeStandaloneDisfluencies(String text) {
        if (text == null || text.isEmpty()) {
            return text;
        }
        
        for (String disfluency : standaloneDisfluencies) {
            // Handle multi-word disfluencies differently
            if (disfluency.contains(" ")) {
                // For phrases, ensure word boundaries around the entire phrase
                String pattern = "\\b" + Pattern.quote(disfluency) + "\\b\\s*[,.]?";
                text = text.replaceAll("(?i)" + pattern, " ");
            } else if ("like".equalsIgnoreCase(disfluency)) {
                // Only remove filler "like" when it's clearly filler:
                // 1) "like," with trailing comma
                text = text.replaceAll("(?i)\\blike\\s*,\\s*", "");
                // 2) preceded by a comma: ", like <word>" -> ", <word>"
                text = text.replaceAll("(?i),\\s*like\\b\\s*", ", ");
            } else {
                // For other single words, standard word boundary matching
                String pattern = "\\b" + Pattern.quote(disfluency) + "\\b\\s*[,.]?";
                text = text.replaceAll("(?i)" + pattern, " ");
            }
        }
        
        // Handle stuttering patterns (e.g., "Th-th-this" or "t-t-test") case-insensitively
        text = text.replaceAll("(?i)\\b(\\w{1,2})-(\\1-)+", "");
        
        // Clean up extra spaces and punctuation
        text = text.replaceAll("\\s+", " ");
        text = text.replaceAll("\\s+([,.:;!?])", "$1");
        text = text.replaceAll(",\\s*,+", ","); // Remove duplicate commas
        text = text.replaceAll("^\\s*,\\s*", ""); // Remove leading comma
        text = text.replaceAll(",\\s*$", ""); // Remove trailing comma
        
        return text.trim();
    }
    
    private String dedupeImmediateRepeats(String text) {
        // Split into words
        String[] words = text.split("\\s+");
        if (words.length <= 1) {
            return text;
        }
        
        StringBuilder result = new StringBuilder();
        String lastWord = "";
        
        for (String word : words) {
            // Clean word for comparison (remove trailing punctuation)
            String cleanWord = word.replaceAll("[,.:;!?]+$", "");
            
            // Check if it's a repeat
            if (!cleanWord.equalsIgnoreCase(lastWord)) {
                if (result.length() > 0) {
                    result.append(" ");
                }
                result.append(word);
                lastWord = cleanWord;
            }
        }
        
        return result.toString();
    }
    
    @Override
    public int getPriority() {
        return 15; // Run after reflow but before other processors
    }
}