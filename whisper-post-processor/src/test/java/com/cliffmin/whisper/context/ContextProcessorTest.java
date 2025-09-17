package com.cliffmin.whisper.context;

import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.assertThat;

class ContextProcessorTest {
    @Test
    void learnsAndAppliesCasing() {
        ContextProcessor cp = new ContextProcessor(100);
        cp.learn("GitHub API JavaScript");
        String out = cp.process("github api javascript and rust");
        assertThat(out).contains("GitHub");
        assertThat(out).contains("API");
        assertThat(out).contains("JavaScript");
    }
}
