package com.cliffmin.whisper.processors;

import com.cliffmin.whisper.pipeline.ProcessingPipeline;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class ConjunctionFollowerSplitterTest {

    @Test
    void splitsLeadingAndTrailingConjunctionGlue() {
        ConjunctionFollowerSplitter p = new ConjunctionFollowerSplitter();
        assertThat(p.process("hopefullyandgonna crash")).isEqualTo("hopefully and gonna crash");
        assertThat(p.process("betterand not broken")).isEqualTo("better and not broken");
        assertThat(p.process("andgonna do it")).isEqualTo("and gonna do it");
        assertThat(p.process("andim glad")).isEqualTo("and im glad");
        assertThat(p.process("yeahsets now")).isEqualTo("yeah sets now");
    }

    @Test
    void pipelineHandlesUserSample() {
        String input = "this is testing with the newuh... word separator and it should be much betterand not broken hopefullyandgonna crash sooni'm glad i got thisall this cleanup and organization doneit uh... yeahsets me up on a stronger foundation to continue forward";
        ProcessingPipeline pipe = new ProcessingPipeline()
                .addProcessor(new ContractionNormalizer())
                .addProcessor(new ConjunctionFollowerSplitter())
                .addProcessor(new MergedWordProcessor());

        String out = pipe.process(input);
        assertThat(out)
                .contains("better and")
                .contains("hopefully and gonna")
                .contains("soon I'm")
                .contains("this all")
                .contains("done it")
                .contains("yeah sets");
    }
}
