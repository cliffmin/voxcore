package com.cliffmin.voxcore.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

/**
 * Validates and ensures directories exist and are writable.
 * Replaces Lua ensureDirectory logic from push_to_talk.lua.
 */
public class DirectoryValidator {

    private static final Logger log = LoggerFactory.getLogger(DirectoryValidator.class);

    /**
     * Ensure directory exists and is writable.
     * Creates directory if it doesn't exist.
     *
     * @param path Path to directory
     * @param name Descriptive name for logging
     * @return The validated path, or null if validation fails
     */
    public static Path ensureDirectory(Path path, String name) {
        if (path == null) {
            log.warn("{} is not set", name);
            return null;
        }

        try {
            // Create directory if it doesn't exist
            if (!Files.exists(path)) {
                log.info("Creating {}: {}", name, path);
                Files.createDirectories(path);
            }

            // Verify it's a directory
            if (!Files.isDirectory(path)) {
                log.error("{} is not a directory: {}", name, path);
                return null;
            }

            // Test writability by creating a temporary file
            Path testFile = path.resolve(".voxcore_write_test");
            try {
                Files.writeString(testFile, "test");
                Files.delete(testFile);
                log.info("{} = {} (writable)", name, path);
                return path;
            } catch (IOException e) {
                log.error("{} = {} (NOT writable): {}", name, path, e.getMessage());
                return null;
            }

        } catch (IOException e) {
            log.error("Failed to create {}: {} - {}", name, path, e.getMessage());
            return null;
        }
    }

    /**
     * Ensure directory exists and is writable, expanding path first.
     *
     * @param pathStr Path string to expand and validate
     * @param name Descriptive name for logging
     * @return The validated path, or null if validation fails
     */
    public static Path ensureDirectory(String pathStr, String name) {
        if (pathStr == null || pathStr.isEmpty()) {
            log.warn("{} is not set", name);
            return null;
        }

        Path expanded = PathExpander.expandToPath(pathStr);
        return ensureDirectory(expanded, name);
    }

    /**
     * Validate directory exists and is writable (doesn't create).
     *
     * @param path Path to validate
     * @param name Descriptive name for logging
     * @return true if valid and writable
     */
    public static boolean validateDirectory(Path path, String name) {
        if (path == null) {
            log.warn("{} is not set", name);
            return false;
        }

        if (!Files.exists(path)) {
            log.error("{} does not exist: {}", name, path);
            return false;
        }

        if (!Files.isDirectory(path)) {
            log.error("{} is not a directory: {}", name, path);
            return false;
        }

        if (!Files.isWritable(path)) {
            log.error("{} is not writable: {}", name, path);
            return false;
        }

        log.info("{} = {} (valid)", name, path);
        return true;
    }

    /**
     * Check if path is writable (for existing directories).
     *
     * @param path Path to check
     * @return true if writable
     */
    public static boolean isWritable(Path path) {
        if (path == null || !Files.exists(path)) {
            return false;
        }

        // Test by creating a temporary file
        Path testFile = path.resolve(".voxcore_write_test_" + System.currentTimeMillis());
        try {
            Files.writeString(testFile, "test");
            Files.delete(testFile);
            return true;
        } catch (IOException e) {
            return false;
        }
    }
}
