package com.cliffmin.whisper.processors;

import com.cliffmin.whisper.pipeline.TextProcessor;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Normalizes common I-contractions and repairs simple merges around them.
 * Examples:
 *   "im" -> "I'm", "ive" -> "I've", "ill" -> "I'll", "id" -> "I'd"
 *   "sooni'm" -> "soon I'm"
 */
public class ContractionNormalizer implements TextProcessor {

    private static final Pattern MERGED_IM_PATTERN = Pattern.compile("(?i)\\b([a-z]{3,})(i['’]m)\\b");
    // Note: do NOT generically split *im/ive/ill/id at token end (e.g., victim/give) — too risky
    private static final Pattern I_CONTRACTION_TOKEN = Pattern.compile("(?i)\\b(i['’]?(?:m|ve|ll|d))\\b");

    @Override
    public String process(String input) {
        if (input == null || input.isEmpty()) return input;
        String result = input;

        // 1) Split glued "...i'm" cases (e.g., "sooni'm" -> "soon i'm")
        result = replaceWithGroups(result, MERGED_IM_PATTERN, (g1, g2) -> g1 + " " + g2);

        // 2) (intentionally omitted) generic suffix splitting like soonim -> soon im can over-split real words
        
        // 2) Normalize tokens to proper capitalization/apostrophes
        Matcher m = I_CONTRACTION_TOKEN.matcher(result);
        StringBuffer sb = new StringBuffer();
        while (m.find()) {
            String tok = m.group(1).toLowerCase().replace("’", "'");
            String rep;
            switch (tok) {
                case "i'm" -> rep = "I'm";
                case "im" -> rep = "I'm";
                case "i've", "ive" -> rep = "I've";
                case "i'll", "ill" -> rep = "I'll";
                case "i'd", "id" -> rep = "I'd";
                default -> rep = m.group(1);
            }
            m.appendReplacement(sb, Matcher.quoteReplacement(rep));
        }
        m.appendTail(sb);
        result = sb.toString();

        return result;
    }

    @Override
    public int getPriority() {
        return 11; // run shortly after Disfluency and before merged-word fixes
    }

    private interface Replacer { String apply(String g1, String g2); }

    private String replaceWithGroups(String text, Pattern p, Replacer fn) {
        Matcher m = p.matcher(text);
        StringBuffer out = new StringBuffer();
        while (m.find()) {
            m.appendReplacement(out, Matcher.quoteReplacement(fn.apply(m.group(1), m.group(2))));
        }
        m.appendTail(out);
        return out.toString();
    }
}
