package com.cliffmin.whisper;

import com.cliffmin.whisper.pipeline.ProcessingPipeline;
import com.cliffmin.whisper.processors.*;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import picocli.CommandLine;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;
import picocli.CommandLine.Parameters;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.concurrent.Callable;

/**
 * Command-line interface for the Whisper post-processor.
 */
@Command(
    name = "whisper-post",
    mixinStandardHelpOptions = true,
version = "0.4.0",
    description = "Post-processes Whisper transcription output to fix common issues."
)
public class WhisperPostProcessorCLI implements Callable<Integer> {
    
    @Parameters(index = "0", arity = "0..1", 
                description = "Input text to process. If not provided, reads from stdin.")
    private String inputText;
    
    @Option(names = {"-f", "--file"}, 
            description = "Input file to process")
    private Path inputFile;
    
    @Option(names = {"-o", "--output"}, 
            description = "Output file (default: stdout)")
    private Path outputFile;
    
    @Option(names = {"-d", "--debug"}, 
            description = "Enable debug output")
    private boolean debug;
    
    @Option(names = {"--disable-merged-words"}, 
            description = "Disable merged word fixing")
    private boolean disableMergedWords;
    
    @Option(names = {"--disable-sentences"}, 
            description = "Disable sentence boundary fixing")
    private boolean disableSentences;
    
    @Option(names = {"--disable-capitalization"}, 
            description = "Disable capitalization fixing")
    private boolean disableCapitalization;
    
    @Option(names = {"--disable-punctuation"}, 
            description = "Disable punctuation normalization")
    private boolean disablePunctuation;
    
    @Option(names = {"--disable-reflow"}, 
            description = "Disable segment reflow")
    private boolean disableReflow;
    
    @Option(names = {"--disable-disfluency"}, 
            description = "Disable disfluency removal")
    private boolean disableDisfluency;
    
    @Option(names = {"--disable-dictionary"}, 
            description = "Disable dictionary replacements")
    private boolean disableDictionary;
    
    @Option(names = {"--disable-punctuation-restoration"}, 
            description = "Disable punctuation restoration (adds missing punctuation)")
    private boolean disablePunctuationRestoration;
    
@Option(names = {"--json"}, 
            description = "Input is JSON with segments")
    private boolean jsonInput;

    @Option(names = {"--print-config"},
            description = "Print effective config and exit")
    private boolean printConfig;
    
    private final ProcessingPipeline pipeline = new ProcessingPipeline();

    // Optional: Defaults via config (non-breaking)
    private com.cliffmin.whisper.config.Configuration cfg = null;
    
    @Override
    public Integer call() throws Exception {
        // Optional: load configuration to set defaults
        try {
            var cm = new com.cliffmin.whisper.config.ConfigurationManager();
            var override = System.getProperty("ptt.config.file");
            java.nio.file.Path path;
            if (override != null && !override.isBlank()) {
                path = java.nio.file.Path.of(override);
            } else {
                var home = System.getProperty("user.home");
                path = java.nio.file.Path.of(home, ".config", "ptt-dictation", "config.json");
            }
            cfg = cm.load(path);
        } catch (Exception ignored) {}

        if (printConfig) {
            var g = new com.google.gson.GsonBuilder().setPrettyPrinting().create();
            System.out.println(g.toJson(new java.util.LinkedHashMap<String,Object>() {{
                put("language", cfg != null ? cfg.getLanguage() : "en");
                put("whisperModel", cfg != null ? cfg.getWhisperModel() : "base.en");
                put("llmEnabled", cfg != null && cfg.isLlmEnabled());
                put("llmModel", cfg != null ? cfg.getLlmModel() : null);
                put("llmTimeoutMs", cfg != null ? cfg.getLlmTimeoutMs() : 30000);
            }}));
            return 0;
        }

        // Configure pipeline based on options
        configurePipeline();
        
        // Get input text
        String input = getInputText();
        
        if (input == null || input.isEmpty()) {
            System.err.println("No input text provided");
            return 1;
        }
        
        String result;
        if (jsonInput) {
            result = processJson(input);
        } else {
            result = pipeline.process(input);
        }
        
        // Output the result
        outputResult(result);
        
        return 0;
    }
    
    private String processJson(String jsonInput) {
        try {
            Gson gson = new GsonBuilder().setPrettyPrinting().create();
            JsonObject root = JsonParser.parseString(jsonInput).getAsJsonObject();
            
            // Process the main text
            if (root.has("text")) {
                String text = root.get("text").getAsString();
                String processedText = pipeline.process(text);
                root.addProperty("text", processedText);
            }
            
            // Process segments if they exist
            if (root.has("segments")) {
                JsonArray segments = root.getAsJsonArray("segments");
                for (JsonElement element : segments) {
                    JsonObject segment = element.getAsJsonObject();
                    if (segment.has("text")) {
                        String segmentText = segment.get("text").getAsString();
                        String processedSegmentText = pipeline.process(segmentText);
                        segment.addProperty("text", processedSegmentText);
                    }
                }
            }
            
            return gson.toJson(root);
        } catch (Exception e) {
            System.err.println("Error processing JSON: " + e.getMessage());
            if (debug) {
                e.printStackTrace();
            }
            // Fall back to plain text processing
            return pipeline.process(jsonInput);
        }
    }
    
    private void configurePipeline() {
        pipeline.setDebugMode(debug);
        
        // Add reflow first if processing JSON
        if (!disableReflow) {
            pipeline.addProcessor(new ReflowProcessor());
        }
        
        // Add disfluency removal
        if (!disableDisfluency) {
            pipeline.addProcessor(new DisfluencyProcessor());
        }
        
        if (!disableMergedWords) {
            pipeline.addProcessor(new MergedWordProcessor());
        }
        
        if (!disableSentences) {
            pipeline.addProcessor(new SentenceBoundaryProcessor());
        }
        
        if (!disableCapitalization) {
            pipeline.addProcessor(new CapitalizationProcessor());
        }
        
        // Add punctuation restoration (before dictionary for better results)
        if (!disablePunctuationRestoration) {
            pipeline.addProcessor(new PunctuationProcessor());
        }
        
        // If config exists, apply pipeline toggles as defaults (flags still override)
        if (cfg != null) {
            if (!cfg.isEnableReflow()) disableReflow = true;
            if (!cfg.isEnableDisfluency()) disableDisfluency = true;
            if (!cfg.isEnableMergedWords()) disableMergedWords = true;
            if (!cfg.isEnableSentences()) disableSentences = true;
            if (!cfg.isEnableCapitalization()) disableCapitalization = true;
            if (!cfg.isEnableDictionary()) disableDictionary = true;
            if (!cfg.isEnablePunctuationNormalization()) disablePunctuation = true;
            if (!cfg.isEnablePunctuationRestoration()) disablePunctuationRestoration = true;
        }
        
        // Add dictionary replacements
        if (!disableDictionary) {
            pipeline.addProcessor(new DictionaryProcessor());
        }
        
        if (!disablePunctuation) {
            pipeline.addProcessor(new PunctuationNormalizer());
        }
    }
    
    private String getInputText() throws IOException {
        if (inputFile != null) {
            return Files.readString(inputFile);
        } else if (inputText != null) {
            return inputText;
        } else {
            // Read from stdin
            StringBuilder sb = new StringBuilder();
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(System.in))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    sb.append(line).append("\n");
                }
            }
            return sb.toString().trim();
        }
    }
    
    private void outputResult(String result) throws IOException {
        if (outputFile != null) {
            Files.writeString(outputFile, result);
        } else {
            System.out.println(result);
        }
    }
    
    public static void main(String[] args) {
        int exitCode = new CommandLine(new WhisperPostProcessorCLI()).execute(args);
        System.exit(exitCode);
    }
}
