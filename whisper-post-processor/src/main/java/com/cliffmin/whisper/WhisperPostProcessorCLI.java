package com.cliffmin.whisper;

import com.cliffmin.whisper.pipeline.ProcessingPipeline;
import com.cliffmin.whisper.processors.*;
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
    version = "1.0.0",
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
    
    private final ProcessingPipeline pipeline = new ProcessingPipeline();
    
    @Override
    public Integer call() throws Exception {
        // Configure pipeline based on options
        configurePipeline();
        
        // Get input text
        String text = getInputText();
        
        if (text == null || text.isEmpty()) {
            System.err.println("No input text provided");
            return 1;
        }
        
        // Process the text
        String processed = pipeline.process(text);
        
        // Output the result
        outputResult(processed);
        
        return 0;
    }
    
    private void configurePipeline() {
        pipeline.setDebugMode(debug);
        
        if (!disableMergedWords) {
            pipeline.addProcessor(new MergedWordProcessor());
        }
        
        if (!disableSentences) {
            pipeline.addProcessor(new SentenceBoundaryProcessor());
        }
        
        if (!disableCapitalization) {
            pipeline.addProcessor(new CapitalizationProcessor());
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
