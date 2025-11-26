package com.cliffmin.whisper.processors;

import com.cliffmin.whisper.pipeline.TextProcessor;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Fixes sentence boundaries and splits run-on sentences.
 */
public class SentenceBoundaryProcessor implements TextProcessor {
    
    // Pattern to detect lowercase followed DIRECTLY by uppercase (no space) - indicates merged sentence
    // If there's already a space, don't add a period
    private static final Pattern MERGED_SENTENCE_BOUNDARY = Pattern.compile("([a-z])([A-Z])");
    
    // Pattern to detect very long sentences that could be split
    private static final Pattern LONG_SENTENCE = Pattern.compile("[^.!?]{200,}");
    
    @Override
    public String process(String input) {
        String result = input;
        
        // Fix missing sentence boundaries
        result = fixMissingSentenceBoundaries(result);
        
        // Split very long run-on sentences
        result = splitLongSentences(result);
        
        // Insert boundaries at common conjunction patterns (minimal heuristic)
        result = insertBoundaryAtConjunctions(result);
        
        // Ensure sentences end with punctuation
        result = ensureSentenceEndings(result);
        
        return result;
    }
    
    // Common short words that precede nouns - should not get periods
    private static final java.util.Set<String> ARTICLES_AND_PREPOSITIONS = java.util.Set.of(
        "the", "a", "an", "this", "that", "these", "those",
        "my", "your", "his", "her", "its", "our", "their",
        "some", "any", "no", "every", "each", "all", "both",
        "in", "on", "at", "by", "for", "with", "of", "from", "to",
        "and", "or", "but", "so", "if", "as", "like"
    );
    
    private String fixMissingSentenceBoundaries(String text) {
        Matcher matcher = MERGED_SENTENCE_BOUNDARY.matcher(text);
        StringBuffer sb = new StringBuffer();
        
        while (matcher.find()) {
            String lastChar = matcher.group(1);
            String nextChar = matcher.group(2);
            int matchStart = matcher.start();
            
            // Don't add period after "I" or in known acronyms
            if (!"i".equals(lastChar) && !isLikelyAcronym(text, matchStart)) {
                // Check if the preceding word is an article/preposition
                String precedingWord = extractPrecedingWord(text, matchStart);
                if (precedingWord != null && ARTICLES_AND_PREPOSITIONS.contains(precedingWord.toLowerCase())) {
                    // Just add space, not a period (article + proper noun)
                    matcher.appendReplacement(sb, lastChar + " " + nextChar);
                } else if (isLikelyCamelCase(text, matchStart)) {
                    // Looks like camelCase (e.g., VoxCore) - just add space
                    matcher.appendReplacement(sb, lastChar + " " + nextChar);
                } else {
                    // Likely a sentence boundary (e.g., "works.Now")
                    matcher.appendReplacement(sb, lastChar + ". " + nextChar);
                }
            } else {
                matcher.appendReplacement(sb, lastChar + " " + nextChar);
            }
        }
        matcher.appendTail(sb);
        
        return sb.toString();
    }
    
    /**
     * Check if this looks like camelCase (part of a compound word/name).
     * Returns true if the word starts with uppercase (likely proper noun compound).
     */
    private boolean isLikelyCamelCase(String text, int position) {
        // Find the start of the word containing the match
        int wordStart = position;
        while (wordStart > 0 && Character.isLetter(text.charAt(wordStart - 1))) {
            wordStart--;
        }
        // If the word starts with uppercase, it's likely a proper noun compound like VoxCore
        return wordStart < text.length() && Character.isUpperCase(text.charAt(wordStart));
    }
    
    /**
     * Extract the word ending at (or just before) the given position.
     */
    private String extractPrecedingWord(String text, int position) {
        // Find the start of the word containing position
        int end = position + 1; // include the matched lowercase char
        int start = position;
        while (start > 0 && Character.isLetter(text.charAt(start - 1))) {
            start--;
        }
        if (start < end && end <= text.length()) {
            return text.substring(start, end);
        }
        return null;
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
    
    private String insertBoundaryAtConjunctions(String text) {
        // Minimal rule: replace " and <pronoun>" with ". <Pronoun>" when mid-sentence
        java.util.regex.Pattern p = java.util.regex.Pattern.compile("(?i)\\band\\s+(this|that|it|we|i|you|they)\\b");
        java.util.regex.Matcher m = p.matcher(text);
        StringBuffer sb = new StringBuffer();
        while (m.find()) {
            String pronoun = m.group(1);
            String cap = Character.toUpperCase(pronoun.charAt(0)) + pronoun.substring(1);
            m.appendReplacement(sb, ". " + cap);
        }
        m.appendTail(sb);
        return sb.toString();
    }
    
    @Override
    public int getPriority() {
        return 20; // Run after merged word fixes
    }
}
