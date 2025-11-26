package com.cliffmin.whisper.processors;

import com.cliffmin.whisper.pipeline.TextProcessor;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Splits common glued patterns where a conjunction/connector is stuck to the next word.
 * Examples: "andgonna" -> "and gonna", "andim" -> "and im", "butyeah" -> "but yeah".
 * Also splits suffix merges: "betterand" -> "better and".
 */
public class ConjunctionFollowerSplitter implements TextProcessor {

    // and|or|but|so|then glued to these short common followers
    private static final Pattern LEADING_CONJ_GLUE = Pattern.compile(
            "(?i)\\b(and|or|but|so|then)(gonna|going|goin|yeah|yep|i['’]?m|im|it|this|that|all)\\b");

    // word+conj+follower glued: hopefullyandgonna -> hopefully and gonna
    private static final Pattern WORD_CONJ_FOLLOWER_GLUE = Pattern.compile(
            "(?i)\\b([a-z]{3,})(and|or|but|so|then)(gonna|going|goin|yeah|yep|i['’]?m|im|it|this|that|all)\\b");

    // trailing 'and' glued to previous word, restricted to safer bases (er|ly|ful|tt|ter)
    private static final Pattern TRAILING_AND_GLUE_SAFE = Pattern.compile(
            "(?i)\\b([a-z]+(?:er|ly|ful|tt|ter))(and)\\b");

    @Override
    public String process(String input) {
        if (input == null || input.isEmpty()) return input;
        String result = input;

        // three-way split first
        result = replaceWithGroups3(result, WORD_CONJ_FOLLOWER_GLUE, (w, c, f) -> w + " " + c + " " + f);
        // then simpler two-part cases
        result = replaceWithGroups(result, LEADING_CONJ_GLUE, (c, f) -> c + " " + f);
        result = replaceWithGroups(result, TRAILING_AND_GLUE_SAFE, (w, c) -> w + " " + c);

        // Determiner/affirmative stuck to short followers: thisall, yeahsets
        result = result.replaceAll("(?i)\\b(this|that|yeah)(all|sets)\\b", "$1 $2");

        return result;
    }

    @Override
    public int getPriority() {
        return 12; // after ContractionNormalizer, before MergedWordProcessor
    }

    private interface Replacer { String apply(String g1, String g2); }
    private interface Replacer3 { String apply(String g1, String g2, String g3); }

    private String replaceWithGroups(String text, Pattern p, Replacer fn) {
        Matcher m = p.matcher(text);
        StringBuffer out = new StringBuffer();
        while (m.find()) {
            m.appendReplacement(out, Matcher.quoteReplacement(fn.apply(m.group(1), m.group(2))));
        }
        m.appendTail(out);
        return out.toString();
    }

    private String replaceWithGroups3(String text, Pattern p, Replacer3 fn) {
        Matcher m = p.matcher(text);
        StringBuffer out = new StringBuffer();
        while (m.find()) {
            m.appendReplacement(out, Matcher.quoteReplacement(fn.apply(m.group(1), m.group(2), m.group(3))));
        }
        m.appendTail(out);
        return out.toString();
    }
}
