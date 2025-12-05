package com.cliffmin.voxcore.config;

import org.junit.jupiter.api.Test;

import java.nio.file.Path;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Tests for PathExpander (replaces Lua path expansion tests).
 */
class PathExpanderTest {

    private static final String HOME = System.getProperty("user.home");
    private static final String USER = System.getenv("USER");

    @Test
    void testTildeExpansion() {
        // ~/Documents/VoiceNotes → /Users/user/Documents/VoiceNotes
        String result = PathExpander.expandPath("~/Documents/VoiceNotes");
        assertThat(result).isEqualTo(HOME + "/Documents/VoiceNotes");

        // ~/test → /Users/user/test
        result = PathExpander.expandPath("~/test");
        assertThat(result).isEqualTo(HOME + "/test");

        // ~/.config/voxcore → /Users/user/.config/voxcore
        result = PathExpander.expandPath("~/.config/voxcore");
        assertThat(result).isEqualTo(HOME + "/.config/voxcore");

        // Just ~ → /Users/user
        result = PathExpander.expandPath("~");
        assertThat(result).isEqualTo(HOME);
    }

    @Test
    void testEnvironmentVariableExpansion() {
        // $HOME/Documents → /Users/user/Documents
        String result = PathExpander.expandPath("$HOME/Documents");
        assertThat(result).isEqualTo(HOME + "/Documents");

        // ${HOME}/Documents → /Users/user/Documents
        result = PathExpander.expandPath("${HOME}/Documents");
        assertThat(result).isEqualTo(HOME + "/Documents");

        // /Users/$USER/Documents → /Users/username/Documents
        if (USER != null) {
            result = PathExpander.expandPath("/Users/$USER/Documents");
            assertThat(result).isEqualTo("/Users/" + USER + "/Documents");
        }
    }

    @Test
    void testUnknownVariableRemainsUnchanged() {
        // $UNKNOWN_VAR/test → $UNKNOWN_VAR/test (unchanged)
        String result = PathExpander.expandPath("$UNKNOWN_VAR/test");
        assertThat(result).isEqualTo("$UNKNOWN_VAR/test");

        // ${UNKNOWN_VAR}/test → ${UNKNOWN_VAR}/test (unchanged)
        result = PathExpander.expandPath("${UNKNOWN_VAR}/test");
        assertThat(result).isEqualTo("${UNKNOWN_VAR}/test");
    }

    @Test
    void testMixedExpansion() {
        // ~/Documents/$USER → /Users/user/Documents/username
        if (USER != null) {
            String result = PathExpander.expandPath("~/Documents/$USER");
            assertThat(result).isEqualTo(HOME + "/Documents/" + USER);

            // ~/${USER}/test → /Users/user/username/test
            result = PathExpander.expandPath("~/${USER}/test");
            assertThat(result).isEqualTo(HOME + "/" + USER + "/test");
        }
    }

    @Test
    void testAbsolutePathsUnchanged() {
        // /Users/test/Documents → /Users/test/Documents (unchanged)
        String result = PathExpander.expandPath("/Users/test/Documents");
        assertThat(result).isEqualTo("/Users/test/Documents");

        // /tmp/test → /tmp/test (unchanged)
        result = PathExpander.expandPath("/tmp/test");
        assertThat(result).isEqualTo("/tmp/test");
    }

    @Test
    void testEdgeCases() {
        // Empty string → empty string
        String result = PathExpander.expandPath("");
        assertThat(result).isEmpty();

        // null → null
        result = PathExpander.expandPath(null);
        assertThat(result).isNull();

        // Relative path → unchanged
        result = PathExpander.expandPath("relative/path");
        assertThat(result).isEqualTo("relative/path");
    }

    @Test
    void testExpandToPath() {
        // ~/Documents → Path object
        Path result = PathExpander.expandToPath("~/Documents");
        assertThat(result).isNotNull();
        assertThat(result.toString()).isEqualTo(HOME + "/Documents");

        // null → null
        result = PathExpander.expandToPath(null);
        assertThat(result).isNull();

        // empty → null
        result = PathExpander.expandToPath("");
        assertThat(result).isNull();
    }

    @Test
    void testCustomEnvironmentVariables() {
        Map<String, String> env = Map.of(
            "HOME", "/custom/home",
            "USER", "testuser",
            "CUSTOM_VAR", "customvalue"
        );

        // ~/test with custom HOME
        String result = PathExpander.expandPathWithEnv("~/test", env);
        assertThat(result).isEqualTo("/custom/home/test");

        // $USER with custom USER
        result = PathExpander.expandPathWithEnv("/users/$USER", env);
        assertThat(result).isEqualTo("/users/testuser");

        // ${CUSTOM_VAR} with custom var
        result = PathExpander.expandPathWithEnv("/path/${CUSTOM_VAR}", env);
        assertThat(result).isEqualTo("/path/customvalue");

        // Unknown var stays unchanged
        result = PathExpander.expandPathWithEnv("$UNKNOWN", env);
        assertThat(result).isEqualTo("$UNKNOWN");
    }

    @Test
    void testMultipleVariablesInPath() {
        if (USER != null) {
            // $HOME/users/$USER/documents
            String result = PathExpander.expandPath("$HOME/users/$USER/documents");
            assertThat(result).isEqualTo(HOME + "/users/" + USER + "/documents");
        }
    }

    @Test
    void testGetHomeDir() {
        Path homeDir = PathExpander.getHomeDir();
        assertThat(homeDir).isNotNull();
        assertThat(homeDir.toString()).isEqualTo(HOME);
    }
}
