package com.cliffmin.voxcore.exception;

import com.google.gson.JsonObject;

/**
 * VoxCore exception with structured error codes.
 * Enables JSON error output for Hammerspoon integration.
 */
public class VoxCoreException extends Exception {

    private final ErrorCode errorCode;
    private final String details;

    public VoxCoreException(ErrorCode errorCode, String message) {
        super(message);
        this.errorCode = errorCode;
        this.details = null;
    }

    public VoxCoreException(ErrorCode errorCode, String message, String details) {
        super(message);
        this.errorCode = errorCode;
        this.details = details;
    }

    public VoxCoreException(ErrorCode errorCode, String message, Throwable cause) {
        super(message, cause);
        this.errorCode = errorCode;
        this.details = cause != null ? cause.getMessage() : null;
    }

    public ErrorCode getErrorCode() {
        return errorCode;
    }

    public String getDetails() {
        return details;
    }

    /**
     * Convert exception to JSON for structured error output.
     * Format: {"error": "ERR_CODE", "message": "...", "details": "..."}
     */
    public JsonObject toJson() {
        JsonObject json = new JsonObject();
        json.addProperty("error", errorCode.getCode());
        json.addProperty("message", getMessage());
        if (details != null && !details.isEmpty()) {
            json.addProperty("details", details);
        }
        return json;
    }

    /**
     * Format error as human-readable string.
     */
    public String toFormattedString() {
        StringBuilder sb = new StringBuilder();
        sb.append("[").append(errorCode.getCode()).append("] ");
        sb.append(getMessage());
        if (details != null && !details.isEmpty()) {
            sb.append("\nDetails: ").append(details);
        }
        return sb.toString();
    }
}
