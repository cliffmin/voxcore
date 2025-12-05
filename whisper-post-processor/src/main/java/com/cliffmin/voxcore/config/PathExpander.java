package com.cliffmin.voxcore.config;

import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Utility for expanding paths with tilde (~) and environment variables.
 * Replaces Lua path expansion logic from push_to_talk.lua.
 */
public class PathExpander {

    private static final Pattern ENV_VAR_PATTERN = Pattern.compile("\\$(?:(\\w+)|\\{([^}]+)\\})");
    private static final String HOME_DIR = System.getProperty("user.home");

    /**
     * Expand path with tilde and environment variable substitution.
     *
     * Examples:
     *   ~/Documents/VoiceNotes → /Users/user/Documents/VoiceNotes
     *   $HOME/notes → /Users/user/notes
     *   ${HOME}/notes → /Users/user/notes
     *   /absolute/path → /absolute/path (unchanged)
     *
     * @param path Path to expand (may be null or empty)
     * @return Expanded path, or original if null/empty
     */
    public static String expandPath(String path) {
        if (path == null || path.isEmpty()) {
            return path;
        }

        // Expand tilde to home directory
        if (path.startsWith("~/")) {
            path = HOME_DIR + path.substring(1);
        } else if (path.equals("~")) {
            path = HOME_DIR;
        }

        // Expand environment variables ($VAR or ${VAR})
        Matcher matcher = ENV_VAR_PATTERN.matcher(path);
        StringBuffer result = new StringBuffer();

        while (matcher.find()) {
            String varName = matcher.group(1) != null ? matcher.group(1) : matcher.group(2);
            String value = System.getenv(varName);

            if (value != null) {
                // Escape backslashes for appendReplacement
                matcher.appendReplacement(result, Matcher.quoteReplacement(value));
            } else {
                // Keep original if variable not found
                matcher.appendReplacement(result, Matcher.quoteReplacement(matcher.group(0)));
            }
        }
        matcher.appendTail(result);

        return result.toString();
    }

    /**
     * Expand path and convert to Path object.
     *
     * @param pathStr Path string to expand
     * @return Expanded Path object, or null if input is null/empty
     */
    public static Path expandToPath(String pathStr) {
        if (pathStr == null || pathStr.isEmpty()) {
            return null;
        }
        return Paths.get(expandPath(pathStr));
    }

    /**
     * Get home directory path.
     *
     * @return User's home directory
     */
    public static Path getHomeDir() {
        return Paths.get(HOME_DIR);
    }

    /**
     * Expand path with custom environment variables (for testing).
     *
     * @param path Path to expand
     * @param envVars Custom environment variables
     * @return Expanded path
     */
    static String expandPathWithEnv(String path, Map<String, String> envVars) {
        if (path == null || path.isEmpty()) {
            return path;
        }

        // Expand tilde
        if (path.startsWith("~/")) {
            String home = envVars.getOrDefault("HOME", HOME_DIR);
            path = home + path.substring(1);
        }

        // Expand environment variables
        Matcher matcher = ENV_VAR_PATTERN.matcher(path);
        StringBuffer result = new StringBuffer();

        while (matcher.find()) {
            String varName = matcher.group(1) != null ? matcher.group(1) : matcher.group(2);
            String value = envVars.get(varName);

            if (value != null) {
                matcher.appendReplacement(result, Matcher.quoteReplacement(value));
            } else {
                matcher.appendReplacement(result, Matcher.quoteReplacement(matcher.group(0)));
            }
        }
        matcher.appendTail(result);

        return result.toString();
    }
}
