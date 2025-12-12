package com.cliffmin.voxcore.exception;

/**
 * Structured error codes for VoxCore CLI.
 * Enables better error categorization and debugging in Hammerspoon integration.
 */
public enum ErrorCode {

    /** Audio file not found or inaccessible */
    ERR_AUDIO_NOT_FOUND("ERR_AUDIO_NOT_FOUND", "Audio file not found"),

    /** Whisper binary not found (not installed or not in PATH) */
    ERR_WHISPER_NOT_FOUND("ERR_WHISPER_NOT_FOUND", "Whisper binary not found"),

    /** Whisper execution failed (non-zero exit code) */
    ERR_WHISPER_FAILED("ERR_WHISPER_FAILED", "Whisper transcription failed"),

    /** Configuration validation failed */
    ERR_CONFIG_INVALID("ERR_CONFIG_INVALID", "Configuration validation failed"),

    /** Transcription produced empty output */
    ERR_EMPTY_TRANSCRIPT("ERR_EMPTY_TRANSCRIPT", "Whisper returned empty transcript"),

    /** Post-processing pipeline failed */
    ERR_POST_PROCESSING_FAILED("ERR_POST_PROCESSING_FAILED", "Post-processing failed"),

    /** Model file not found */
    ERR_MODEL_NOT_FOUND("ERR_MODEL_NOT_FOUND", "Whisper model file not found"),

    /** Unknown or unexpected error */
    ERR_UNKNOWN("ERR_UNKNOWN", "Unknown error");

    private final String code;
    private final String description;

    ErrorCode(String code, String description) {
        this.code = code;
        this.description = description;
    }

    public String getCode() {
        return code;
    }

    public String getDescription() {
        return description;
    }

    @Override
    public String toString() {
        return code;
    }
}
