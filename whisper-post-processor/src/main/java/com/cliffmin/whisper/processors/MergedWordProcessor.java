package com.cliffmin.whisper.processors;

import com.cliffmin.whisper.pipeline.TextProcessor;
import java.util.HashMap;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Fixes common merged word patterns that Whisper produces.
 */
public class MergedWordProcessor implements TextProcessor {
    
    private final Map<Pattern, String> replacements = new HashMap<>();
    
    public MergedWordProcessor() {
        initializeReplacements();
    }
    
    private void initializeReplacements() {
        // Contractions that get merged
        addReplacement("that'slike", "that's like");
        addReplacement("it'slike", "it's like");
        addReplacement("there'slike", "there's like");
        addReplacement("what'sthe", "what's the");
        addReplacement("that'sthe", "that's the");
        addReplacement("it'sthe", "it's the");
        addReplacement("i'mjust", "I'm just");
        addReplacement("i'mgoing", "I'm going");
        addReplacement("can'tjust", "can't just");
        addReplacement("won'tbe", "won't be");
        addReplacement("don'tknow", "don't know");
        addReplacement("didn'twork", "didn't work");
        
        // Common "they" mergers
        addReplacement("theyconfigure", "they configure");
        addReplacement("theydon't", "they don't");
        addReplacement("theycan't", "they can't");
        addReplacement("theywere", "they were");
        addReplacement("theyhave", "they have");
        addReplacement("theyneed", "they need");
        addReplacement("theyshould", "they should");
        addReplacement("theywould", "they would");
        addReplacement("theycould", "they could");
        addReplacement("theymight", "they might");
        addReplacement("theyare", "they are");
        addReplacement("theywill", "they will");
        
        // Preposition mergers
        addReplacement("withthe", "with the");
        addReplacement("withthat", "with that");
        addReplacement("withthis", "with this");
        addReplacement("withthese", "with these");
        addReplacement("tothe", "to the");
        addReplacement("andthe", "and the");
        addReplacement("ofthe", "of the");
        addReplacement("inthe", "in the");
        addReplacement("onthe", "on the");
        addReplacement("forthe", "for the");
        addReplacement("fromthe", "from the");
        addReplacement("atthe", "at the");
        addReplacement("bythe", "by the");
        
        // Specific merges seen in field data
        addReplacement("doneit", "done it");
        addReplacement("thisall", "this all");
        addReplacement("yeahsets", "yeah sets");
        addReplacement("willbe", "will be");
        addReplacement("bothbecause", "both because");
        addReplacement("theintegration", "the integration");
        addReplacement("theperformance", "the performance");
        addReplacement("kindof", "kind of");
        addReplacement("typeof", "type of");
        addReplacement("sortof", "sort of");
        addReplacement("alot", "a lot");
        addReplacement("aswell", "as well");
        addReplacement("infact", "in fact");
        addReplacement("atleast", "at least");
        addReplacement("sofar", "so far");
        addReplacement("inthat", "in that");
        addReplacement("sothat", "so that");
        addReplacement("suchthat", "such that");
        addReplacement("likethe", "like the");
        addReplacement("justthe", "just the");
        addReplacement("butthe", "but the");
        addReplacement("orthe", "or the");
        addReplacement("becausethe", "because the");
        addReplacement("sincethe", "since the");
        addReplacement("whenthe", "when the");
        addReplacement("wherethe", "where the");
        addReplacement("shouldbe", "should be");
        addReplacement("wouldbe", "would be");
        addReplacement("couldbe", "could be");
        addReplacement("mightbe", "might be");
        addReplacement("mustbe", "must be");
        addReplacement("canbe", "can be");
        
        // Technical terms
        addReplacement("apikey", "API key");
        addReplacement("apikeys", "API keys");
        addReplacement("textfield", "text field");
        addReplacement("servicelayer", "service layer");
        addReplacement("dblayer", "DB layer");
        addReplacement("usecase", "use case");
        addReplacement("usecases", "use cases");
        
        // Add pattern for "word'sword" where second word is common
        // Note: Using a custom handler instead of simple replacement to avoid issues
    }
    
    private void addReplacement(String from, String to) {
        // Create case-insensitive pattern with word boundaries
        Pattern pattern = Pattern.compile("\\b" + Pattern.quote(from) + "\\b", 
            Pattern.CASE_INSENSITIVE);
        replacements.put(pattern, to);
    }
    
    @Override
    public String process(String input) {
        if (input == null) return null;
        if (input.isEmpty()) return input;
        String result = input;
        
        // First fix sentence boundary merging (word.Word -> word. Word)
        result = fixSentenceBoundaryMerging(result);
        
        // Then handle the special apostrophe patterns
        result = fixApostropheContractions(result);
        
        // Handle generic word+conjunction patterns
        result = fixWordConjunctionMerging(result);
        
        // Handle the+word patterns
        result = fixTheWordMerging(result);
        
        // Handle missing sentence boundaries (toThen -> to. Then)
        result = fixMissingSentenceBoundary(result);
        
        // Then handle the regular replacements
        for (Map.Entry<Pattern, String> entry : replacements.entrySet()) {
            Matcher matcher = entry.getKey().matcher(result);
            
            // Handle case preservation for simple replacements
            StringBuffer sb = new StringBuffer();
            while (matcher.find()) {
                String matched = matcher.group();
                String replacement = entry.getValue();
                
                // Preserve case if original was capitalized
                if (Character.isUpperCase(matched.charAt(0)) && 
                    Character.isLowerCase(replacement.charAt(0))) {
                    replacement = Character.toUpperCase(replacement.charAt(0)) + 
                                  replacement.substring(1);
                }
                
                matcher.appendReplacement(sb, Matcher.quoteReplacement(replacement));
            }
            matcher.appendTail(sb);
            result = sb.toString();
        }
        
        return result;
    }
    
    /**
     * Fix sentence boundary merging: word.Word -> word. Word
     * Handles period, question mark, and exclamation point.
     */
    private String fixSentenceBoundaryMerging(String text) {
        // Pattern: word followed by sentence-ending punctuation followed immediately by capital letter
        Pattern pattern = Pattern.compile("(\\w)([.!?])([A-Z])");
        
        Matcher matcher = pattern.matcher(text);
        StringBuffer sb = new StringBuffer();
        
        while (matcher.find()) {
            String lastChar = matcher.group(1);
            String punct = matcher.group(2);
            String nextChar = matcher.group(3);
            String replacement = lastChar + punct + " " + nextChar;
            matcher.appendReplacement(sb, Matcher.quoteReplacement(replacement));
        }
        matcher.appendTail(sb);
        
        return sb.toString();
    }
    
    /**
     * Fix word+conjunction merging: statementand -> statement and
     * Handles common conjunctions: and, or, but, then, so
     */
    private String fixWordConjunctionMerging(String text) {
        // Pattern: 3+ letter word followed by common conjunction/pronoun
        Pattern pattern = Pattern.compile("\\b(\\w{3,})(and|or|but|you)\\b", 
            Pattern.CASE_INSENSITIVE);
        
        Matcher matcher = pattern.matcher(text);
        StringBuffer sb = new StringBuffer();
        
        while (matcher.find()) {
            String word1 = matcher.group(1);
            String word2 = matcher.group(2);
            
            // Skip if combined is a known word
            if (isLikelyFalsePositive(word1, word2)) {
                continue;
            }
            
            String replacement = word1 + " " + word2;
            matcher.appendReplacement(sb, Matcher.quoteReplacement(replacement));
        }
        matcher.appendTail(sb);
        
        return sb.toString();
    }
    
    /**
     * Fix lowercase word followed by capitalized word (sentence boundary without punctuation)
     * Example: toThen -> to. Then
     * BUT NOT: theVox -> the Vox (that's an article, not a sentence boundary)
     */
    private String fixMissingSentenceBoundary(String text) {
        // Pattern: lowercase word ending, immediately followed by capitalized word
        Pattern pattern = Pattern.compile("\\b([a-z]+)([A-Z][a-z]+)\\b");
        
        Matcher matcher = pattern.matcher(text);
        StringBuffer sb = new StringBuffer();
        
        // Common short words that precede nouns (not sentence boundaries)
        java.util.Set<String> articles = java.util.Set.of(
            "the", "a", "an", "this", "that", "these", "those",
            "my", "your", "his", "her", "its", "our", "their",
            "some", "any", "no", "every", "each", "all", "both",
            "in", "on", "at", "by", "for", "with", "of", "from",
            "and", "or", "but", "so", "if", "as", "like"
        );
        
        // Words that typically start new sentences (sentence boundaries)
        java.util.Set<String> sentenceStarters = java.util.Set.of(
            "Then", "Now", "However", "Therefore", "Thus", "Hence",
            "Also", "First", "Second", "Third", "Finally", "Next",
            "Meanwhile", "Otherwise", "Instead"
        );
        
        while (matcher.find()) {
            String word1 = matcher.group(1);
            String word2 = matcher.group(2);
            
            // If word2 is a sentence starter, always add period (even after "to")
            if (sentenceStarters.contains(word2)) {
                String replacement = word1 + ". " + word2;
                matcher.appendReplacement(sb, Matcher.quoteReplacement(replacement));
                continue;
            }
            
            // Skip if word1 is an article/determiner/preposition - just add space, not period
            if (articles.contains(word1.toLowerCase())) {
                // This is "theVox" -> "the Vox", not a sentence boundary
                String replacement = word1 + " " + word2;
                matcher.appendReplacement(sb, Matcher.quoteReplacement(replacement));
                continue;
            }
            
            // Skip camelCase technical terms (both parts long)
            if (word1.length() > 5 && word2.length() > 3) {
                continue;
            }
            
            // This looks like a missing sentence boundary
            String replacement = word1 + ". " + word2;
            matcher.appendReplacement(sb, Matcher.quoteReplacement(replacement));
        }
        matcher.appendTail(sb);
        
        return sb.toString();
    }
    
    /**
     * Fix the+word merging: thecustom -> the custom
     * Only handles patterns NOT already covered by the hardcoded replacements.
     */
    private String fixTheWordMerging(String text) {
        // Pattern: "the" followed by lowercase word (not already handled)
        Pattern pattern = Pattern.compile("\\bthe([a-z]{3,})\\b");
        
        Matcher matcher = pattern.matcher(text);
        StringBuffer sb = new StringBuffer();
        
        while (matcher.find()) {
            String word = matcher.group(1);
            String lower = word.toLowerCase();
            
            // Skip known words that legitimately start with "the"
            if (lower.equals("m") || lower.equals("n") || lower.equals("re") || 
                lower.equals("se") || lower.equals("y") || lower.equals("ir") ||
                lower.equals("ory") || lower.equals("sis") || lower.equals("me") ||
                lower.equals("mes") || lower.equals("ater") || lower.equals("atre") ||
                lower.equals("sis") || lower.equals("ater")) {
                continue;
            }
            
            // Skip patterns already handled by hardcoded replacements
            // (they*, with*, in*, for*, from*, at*, by*, to*, and*, of*)
            if (lower.startsWith("y") || // they*
                lower.startsWith("configure") || lower.startsWith("don") || 
                lower.startsWith("can") || lower.startsWith("were") ||
                lower.startsWith("have") || lower.startsWith("need") ||
                lower.startsWith("should") || lower.startsWith("would") ||
                lower.startsWith("could") || lower.startsWith("might") ||
                lower.startsWith("are") || lower.startsWith("will")) {
                continue;
            }
            
            String replacement = "the " + word;
            matcher.appendReplacement(sb, Matcher.quoteReplacement(replacement));
        }
        matcher.appendTail(sb);
        
        return sb.toString();
    }
    
    private boolean isLikelyFalsePositive(String word1, String word2) {
        String combined = (word1 + word2).toLowerCase();
        // Known words that look like merged words but aren't
        return combined.equals("brand") || combined.equals("grandor") ||
               combined.equals("wander") || combined.equals("pander") ||
               combined.equals("banter") || combined.equals("cantor") ||
               combined.equals("mentor") || combined.equals("render");
    }
    
    private String fixApostropheContractions(String text) {
        // Fix patterns like "that'slike" -> "that's like"
        Pattern pattern = Pattern.compile("(\\w+)'s(like|just|been|going|the|all|really|very)\\b", 
            Pattern.CASE_INSENSITIVE);
        
        Matcher matcher = pattern.matcher(text);
        StringBuffer sb = new StringBuffer();
        
        while (matcher.find()) {
            String word1 = matcher.group(1);
            String word2 = matcher.group(2);
            String replacement = word1 + "'s " + word2;
            matcher.appendReplacement(sb, Matcher.quoteReplacement(replacement));
        }
        matcher.appendTail(sb);
        
        return sb.toString();
    }
    
    @Override
    public int getPriority() {
        return 10; // Run early in the pipeline
    }
}
