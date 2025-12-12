package com.cliffmin.voxcore.exception;

import com.google.gson.JsonObject;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Tests for VoxCoreException - focused on real-world use cases.
 *
 * Critical: JSON serialization must work correctly for Hammerspoon integration.
 */
class VoxCoreExceptionTest {

    @Test
    void testJsonSerialization_withoutDetails() {
        // Use case: CLI outputs JSON error, Hammerspoon parses it
        VoxCoreException error = new VoxCoreException(
            ErrorCode.ERR_AUDIO_NOT_FOUND,
            "Audio file not found: /path/to/file.wav"
        );

        JsonObject json = error.toJson();

        assertThat(json.get("error").getAsString()).isEqualTo("ERR_AUDIO_NOT_FOUND");
        assertThat(json.get("message").getAsString()).isEqualTo("Audio file not found: /path/to/file.wav");
        assertThat(json.has("details")).isFalse();
    }

    @Test
    void testJsonSerialization_withDetails() {
        // Use case: Whisper fails with stderr output
        VoxCoreException error = new VoxCoreException(
            ErrorCode.ERR_WHISPER_FAILED,
            "Whisper failed with exit code 1",
            "whisper: error: model not found"
        );

        JsonObject json = error.toJson();

        assertThat(json.get("error").getAsString()).isEqualTo("ERR_WHISPER_FAILED");
        assertThat(json.get("message").getAsString()).isEqualTo("Whisper failed with exit code 1");
        assertThat(json.get("details").getAsString()).isEqualTo("whisper: error: model not found");
    }

    @Test
    void testFormattedString_humanReadable() {
        // Use case: CLI --debug flag for debugging
        VoxCoreException error = new VoxCoreException(
            ErrorCode.ERR_CONFIG_INVALID,
            "Configuration validation failed",
            "Notes directory not writable"
        );

        String formatted = error.toFormattedString();

        assertThat(formatted).contains("[ERR_CONFIG_INVALID]");
        assertThat(formatted).contains("Configuration validation failed");
        assertThat(formatted).contains("Details: Notes directory not writable");
    }

    @Test
    void testFormattedString_withoutDetails() {
        VoxCoreException error = new VoxCoreException(
            ErrorCode.ERR_EMPTY_TRANSCRIPT,
            "Whisper returned empty transcript"
        );

        String formatted = error.toFormattedString();

        assertThat(formatted).contains("[ERR_EMPTY_TRANSCRIPT]");
        assertThat(formatted).contains("Whisper returned empty transcript");
        assertThat(formatted).doesNotContain("Details:");
    }
}
