package com.cliffmin.whisper.processors;

import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.*;

class ContractionNormalizerTest {

    @Test
    void splitsAndNormalizesIm() {
        ContractionNormalizer p = new ContractionNormalizer();
        assertThat(p.process("im glad")).isEqualTo("I'm glad");
        assertThat(p.process("sooni'm glad")).isEqualTo("soon I'm glad");
    }

    @Test
    void leavesNonContractionsAlone() {
        ContractionNormalizer p = new ContractionNormalizer();
        assertThat(p.process("victim")).isEqualTo("victim");
        assertThat(p.process("give")).isEqualTo("give");
        assertThat(p.process("illness")).isEqualTo("illness");
    }
}
