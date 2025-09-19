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
        
        // First handle the special apostrophe patterns (e.g., "that'slike" -> "that's like")
        result = fixApostropheContractions(result);
        
        // Heuristic tech compound split (e.g., "githubactions" -> "github actions")
        result = fixTechCompounds(result);
        
        // Then handle the curated replacements
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
    
    /**
     * Split common technical compounds where two words are merged without spaces.
     * This is a conservative, stateless heuristic with a small suffix list to avoid false positives.
     */
    private String fixTechCompounds(String text) {
        // Suffixes commonly seen as the second word in merged pairs (lowercase transcripts)
        String[] suffixes = new String[]{
            "actions","config","layer","module","service","manager","provider",
            "adapter","handler","bridge","queue","cache","store","class","field","tests","test"
        };
        // For each suffix, split pattern like: \b([a-z]{3,})suffix\b -> $1 suffix
        // Use case-insensitive matching and preserve leading capitalization if present
        String result = text;
        for (String suf : suffixes) {
            Pattern p = Pattern.compile("\\b([a-z]{3,})" + Pattern.quote(suf) + "\\b", Pattern.CASE_INSENSITIVE);
            Matcher m = p.matcher(result);
            StringBuffer sb = new StringBuffer();
            while (m.find()) {
                String prefix = m.group(1);
                String replacement = prefix + " " + suf;
                // Preserve capitalization if original token started with uppercase
                String token = m.group(0);
                if (!token.isEmpty() && Character.isUpperCase(token.charAt(0))) {
                    replacement = Character.toUpperCase(replacement.charAt(0)) + replacement.substring(1);
                }
                m.appendReplacement(sb, Matcher.quoteReplacement(replacement));
            }
            m.appendTail(sb);
            result = sb.toString();
        }
        // Targeted known pairs that are frequent in logs/domains
        result = result.replaceAll("\\bgithubactions\\b", "github actions");
        result = result.replaceAll("\\bjsonapi\\b", "JSON API");
        return result;
    }
    
    @Override
    public int getPriority() {
        return 10; // Run early in the pipeline
    }
}
