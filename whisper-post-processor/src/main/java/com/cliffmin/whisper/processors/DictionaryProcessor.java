package com.cliffmin.whisper.processors;

import com.cliffmin.whisper.pipeline.TextProcessor;
import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;
import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.HashMap;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Applies dictionary-based word replacements from external configuration.
 * Loads corrections from user config or VoxCompose learned corrections.
 */
public class DictionaryProcessor implements TextProcessor {
    
    private final Map<String, String> replacements;
    
    public DictionaryProcessor() {
        this.replacements = loadDictionary();
    }
    
    public DictionaryProcessor(Map<String, String> replacements) {
        this.replacements = replacements != null ? replacements : new HashMap<>();
    }
    
    @Override
    public String process(String input) {
        if (input == null || input.isEmpty() || replacements.isEmpty()) {
            return input;
        }
        
        String result = input;
        
        for (Map.Entry<String, String> entry : replacements.entrySet()) {
            String pattern = entry.getKey();
            String replacement = entry.getValue();
            
            // Create word boundary pattern (case-insensitive)
            String regex = "\\b" + Pattern.quote(pattern) + "\\b";
            Pattern p = Pattern.compile(regex, Pattern.CASE_INSENSITIVE);
            
            result = p.matcher(result).replaceAll(replacement);
        }
        
        return result;
    }
    
    private Map<String, String> loadDictionary() {
        Map<String, String> dict = new HashMap<>();
        
        // Try loading from multiple sources
        String[] paths = {
            System.getProperty("user.home") + "/.config/ptt-dictation/corrections.json",
            System.getProperty("user.home") + "/.config/voxcompose/corrections.json",
            "/usr/local/share/ptt-dictation/corrections.json"
        };
        
        for (String pathStr : paths) {
            Path path = Paths.get(pathStr);
            if (Files.exists(path)) {
                try {
                    dict = loadJsonDictionary(path);
                    if (!dict.isEmpty()) {
                        System.err.println("Loaded dictionary from: " + pathStr);
                        break;
                    }
                } catch (IOException e) {
                    // Try next source
                }
            }
        }
        
        // Also check for environment variable
        String customDict = System.getenv("PTT_DICTIONARY_PATH");
        if (customDict != null) {
            try {
                Map<String, String> custom = loadJsonDictionary(Paths.get(customDict));
                dict.putAll(custom);
            } catch (IOException e) {
                System.err.println("Failed to load custom dictionary: " + e.getMessage());
            }
        }
        
        return dict;
    }
    
    private Map<String, String> loadJsonDictionary(Path path) throws IOException {
        Gson gson = new Gson();
        String content = new String(Files.readAllBytes(path));
        
        // Try to parse as simple map first
        try {
            TypeToken<Map<String, String>> typeToken = new TypeToken<Map<String, String>>() {};
            return gson.fromJson(content, typeToken.getType());
        } catch (Exception e) {
            // Try VoxCompose format
            try {
                VoxComposeDict voxDict = gson.fromJson(content, VoxComposeDict.class);
                Map<String, String> result = new HashMap<>();
                if (voxDict.corrections != null) {
                    for (Map.Entry<String, VoxCorrection> entry : voxDict.corrections.entrySet()) {
                        if (entry.getValue().confidence > 0.8) {
                            result.put(entry.getKey(), entry.getValue().to);
                        }
                    }
                }
                return result;
            } catch (Exception e2) {
                return new HashMap<>();
            }
        }
    }
    
    @Override
    public int getPriority() {
        return 35; // Run after structural processors but before final cleanup
    }
    
    // VoxCompose dictionary format
    private static class VoxComposeDict {
        public Map<String, VoxCorrection> corrections;
    }
    
    private static class VoxCorrection {
        public String to;
        public double confidence;
        public int count;
    }
}