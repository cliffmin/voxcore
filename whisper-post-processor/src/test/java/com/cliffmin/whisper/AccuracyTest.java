package com.cliffmin.whisper;

import com.cliffmin.whisper.pipeline.ProcessingPipeline;
import com.cliffmin.whisper.processors.*;
import com.google.gson.Gson;
import com.google.gson.JsonObject;
import com.google.gson.JsonArray;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;
import static org.assertj.core.api.Assertions.*;

import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.*;

class AccuracyTest {
    
    private static ProcessingPipeline pipeline;
    private static JsonArray testCases;
    
    @BeforeAll
    static void setUp() throws IOException {
        // Set up the pipeline
        pipeline = new ProcessingPipeline()
            .addProcessor(new MergedWordProcessor())
            .addProcessor(new SentenceBoundaryProcessor())
            .addProcessor(new CapitalizationProcessor())
            .addProcessor(new PunctuationNormalizer());
        
        // Load golden dataset
        try (InputStream is = AccuracyTest.class.getResourceAsStream("/golden-dataset.json")) {
            Gson gson = new Gson();
            JsonObject dataset = gson.fromJson(new InputStreamReader(is), JsonObject.class);
            testCases = dataset.getAsJsonArray("test_cases");
        }
    }
    
    @Test
    @DisplayName("Test accuracy against golden dataset")
    void testGoldenDataset() {
        int totalCases = testCases.size();
        int passedCases = 0;
        List<String> failures = new ArrayList<>();
        
        for (int i = 0; i < testCases.size(); i++) {
            JsonObject testCase = testCases.get(i).getAsJsonObject();
            String id = testCase.get("id").getAsString();
            String input = testCase.get("input").getAsString();
            String expected = testCase.get("expected").getAsString();
            String category = testCase.get("category").getAsString();
            
            String actual = pipeline.process(input);
            
            if (actual.equals(expected)) {
                passedCases++;
                System.out.printf("✅ %s: PASS%n", id);
            } else {
                failures.add(String.format("%s (%s):%n  Input:    %s%n  Expected: %s%n  Actual:   %s",
                    id, category, input, expected, actual));
                System.out.printf("❌ %s: FAIL%n", id);
            }
        }
        
        // Calculate metrics
        double accuracy = (double) passedCases / totalCases * 100;
        
        // Print summary
        System.out.println("\n=== ACCURACY REPORT ===");
        System.out.printf("Total test cases: %d%n", totalCases);
        System.out.printf("Passed: %d%n", passedCases);
        System.out.printf("Failed: %d%n", totalCases - passedCases);
        System.out.printf("Accuracy: %.1f%%%n", accuracy);
        
        if (!failures.isEmpty()) {
            System.out.println("\n=== FAILURES ===");
            failures.forEach(System.out::println);
        }
        
        // Assert minimum accuracy threshold
        assertThat(accuracy)
            .as("Accuracy should be at least 80%")
            .isGreaterThanOrEqualTo(80.0);
    }
    
    @Test
    @DisplayName("Calculate Word Error Rate (WER)")
    void testWordErrorRate() {
        double totalWER = 0;
        int count = 0;
        
        for (int i = 0; i < testCases.size(); i++) {
            JsonObject testCase = testCases.get(i).getAsJsonObject();
            String input = testCase.get("input").getAsString();
            String expected = testCase.get("expected").getAsString();
            
            String actual = pipeline.process(input);
            double wer = calculateWER(expected, actual);
            totalWER += wer;
            count++;
            
            System.out.printf("%s: WER = %.2f%%%n", 
                testCase.get("id").getAsString(), wer);
        }
        
        double averageWER = totalWER / count;
        System.out.printf("\nAverage WER: %.2f%%%n", averageWER);
        
        // Assert WER is reasonable
        assertThat(averageWER)
            .as("Average WER should be less than 20%")
            .isLessThan(20.0);
    }
    
    private double calculateWER(String reference, String hypothesis) {
        String[] refWords = reference.toLowerCase().split("\\s+");
        String[] hypWords = hypothesis.toLowerCase().split("\\s+");
        
        int[][] dp = new int[refWords.length + 1][hypWords.length + 1];
        
        // Initialize
        for (int i = 0; i <= refWords.length; i++) {
            dp[i][0] = i;
        }
        for (int j = 0; j <= hypWords.length; j++) {
            dp[0][j] = j;
        }
        
        // Calculate edit distance
        for (int i = 1; i <= refWords.length; i++) {
            for (int j = 1; j <= hypWords.length; j++) {
                if (refWords[i-1].equals(hypWords[j-1])) {
                    dp[i][j] = dp[i-1][j-1];
                } else {
                    dp[i][j] = 1 + Math.min(
                        dp[i-1][j],    // deletion
                        Math.min(
                            dp[i][j-1],    // insertion
                            dp[i-1][j-1]   // substitution
                        )
                    );
                }
            }
        }
        
        int editDistance = dp[refWords.length][hypWords.length];
        return (double) editDistance / refWords.length * 100;
    }
    
    @Test
    @DisplayName("Performance benchmark")
    void testPerformance() {
        // Prepare test data
        String longText = String.join(" ", Collections.nCopies(100, 
            "theyconfigure the system withthe apikey"));
        
        // Warm up
        for (int i = 0; i < 10; i++) {
            pipeline.process(longText);
        }
        
        // Measure
        long startTime = System.nanoTime();
        int iterations = 100;
        
        for (int i = 0; i < iterations; i++) {
            pipeline.process(longText);
        }
        
        long endTime = System.nanoTime();
        double avgTimeMs = (endTime - startTime) / 1_000_000.0 / iterations;
        
        System.out.printf("Average processing time: %.2f ms%n", avgTimeMs);
        System.out.printf("Throughput: %.0f ops/sec%n", 1000.0 / avgTimeMs);
        
        // Assert performance threshold
        assertThat(avgTimeMs)
            .as("Processing should take less than 100ms on average")
            .isLessThan(100.0);
    }
}
