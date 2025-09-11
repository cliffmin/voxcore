package com.cliffmin.whisper.processors;

import com.cliffmin.whisper.pipeline.TextProcessor;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Fixes sentence boundaries and splits run-on sentences.
 */
public class SentenceBoundaryProcessor implements TextProcessor {
    
    // Pattern to detect lowercase followed by uppercase with little/no space
    private static final Pattern SENTENCE_BOUNDARY = Pattern.compile("([a-z])\\s?([A-Z])");
    
    // Pattern to detect very long sentences that could be split
    private static final Pattern LONG_SENTENCE = Pattern.compile("[^.!?]{200,}");
    
    @Override
    public String process(String input) {
        String result = input;
        
        // Fix missing sentence boundaries
        result = fixMissingSentenceBoundaries(result);
        
        // Split very long run-on sentences
        result = splitLongSentences(result);
        
        // Ensure sentences end with punctuation
        result = ensureSentenceEndings(result);
        
        return result;
    }
    
    private String fixMissingSentenceBoundaries(String text) {
        Matcher matcher = SENTENCE_BOUNDARY.matcher(text);
        StringBuffer sb = new StringBuffer();
        
        while (matcher.find()) {
            String lastChar = matcher.group(1);
            String nextChar = matcher.group(2);
            
            // Don't add period after "I" or in known acronyms
            if (!"i".equals(lastChar) && !isLikelyAcronym(text, matcher.start())) {
                matcher.appendReplacement(sb, lastChar + ". " + nextChar);
            } else {
                matcher.appendReplacement(sb, lastChar + " " + nextChar);
            }
        }
        matcher.appendTail(sb);
        
        return sb.toString();
    }
    
    private boolean isLikelyAcronym(String text, int position) {
        // Check if we're in the middle of an acronym like "API", "URL", "JSON"
        if (position < 2) return false;
        
        String context = text.substring(Math.max(0, position - 5), 
                                       Math.min(text.length(), position + 5));
        return context.matches(".*\\b[A-Z]{2,}.*");
    }
    
    private String splitLongSentences(String text) {
        String[] sentences = text.split("(?<=[.!?])\\s+");
        StringBuilder result = new StringBuilder();
        
        for (String sentence : sentences) {
            if (sentence.length() > 150) {
                // Try to split at conjunctions
                sentence = splitAtConjunctions(sentence);
            }
            result.append(sentence).append(" ");
        }
        
        return result.toString().trim();
    }
    
    private String splitAtConjunctions(String sentence) {
        // Split at ", and" or ", so" if both parts are substantial
        String result = sentence;
        
        // Pattern for ", and" with substantial text on both sides
        Pattern andPattern = Pattern.compile("(.{40,}), and (.{40,})");
        Matcher andMatcher = andPattern.matcher(result);
        if (andMatcher.find()) {
            result = andMatcher.replaceFirst("$1. And $2");
        }
        
        // Pattern for ", so" with substantial text on both sides
        Pattern soPattern = Pattern.compile("(.{40,}), so (.{40,})");
        Matcher soMatcher = soPattern.matcher(result);
        if (soMatcher.find()) {
            result = soMatcher.replaceFirst("$1. So $2");
        }
        
        return result;
    }
    
    private String ensureSentenceEndings(String text) {
        // Add period at the end if missing
        if (!text.matches(".*[.!?]\\s*$")) {
            text = text.trim() + ".";
        }
        return text;
    }
    
    @Override
    public int getPriority() {
        return 20; // Run after merged word fixes
    }
}
