package com.cliffmin.voxcore.config;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Tests for DirectoryValidator (replaces Lua directory validation tests).
 */
class DirectoryValidatorTest {

    @TempDir
    Path tempDir;

    @Test
    void testEnsureDirectoryCreatesIfMissing() {
        Path testDir = tempDir.resolve("new_directory");
        assertThat(Files.exists(testDir)).isFalse();

        Path result = DirectoryValidator.ensureDirectory(testDir, "TEST_DIR");

        assertThat(result).isNotNull();
        assertThat(result).isEqualTo(testDir);
        assertThat(Files.exists(testDir)).isTrue();
        assertThat(Files.isDirectory(testDir)).isTrue();
    }

    @Test
    void testEnsureDirectoryWithExistingDirectory() {
        // Use existing temp directory
        Path result = DirectoryValidator.ensureDirectory(tempDir, "EXISTING_DIR");

        assertThat(result).isNotNull();
        assertThat(result).isEqualTo(tempDir);
        assertThat(Files.isDirectory(tempDir)).isTrue();
    }

    @Test
    void testEnsureDirectoryValidatesWritability() throws IOException {
        Path testDir = tempDir.resolve("writable_dir");
        Files.createDirectories(testDir);

        Path result = DirectoryValidator.ensureDirectory(testDir, "WRITABLE_DIR");

        assertThat(result).isNotNull();
        assertThat(result).isEqualTo(testDir);

        // Verify test file was created and deleted
        Path testFile = testDir.resolve(".voxcore_write_test");
        assertThat(Files.exists(testFile)).isFalse();
    }

    @Test
    void testEnsureDirectoryWithPathExpansion() {
        // Create directory under temp using expansion
        String pathStr = tempDir.toString() + "/test_expansion";
        Path result = DirectoryValidator.ensureDirectory(pathStr, "EXPANDED_DIR");

        assertThat(result).isNotNull();
        assertThat(Files.exists(result)).isTrue();
        assertThat(Files.isDirectory(result)).isTrue();
    }

    @Test
    void testEnsureDirectoryReturnsNullForNullPath() {
        Path result = DirectoryValidator.ensureDirectory((Path) null, "NULL_PATH");
        assertThat(result).isNull();
    }

    @Test
    void testEnsureDirectoryReturnsNullForEmptyString() {
        Path result = DirectoryValidator.ensureDirectory("", "EMPTY_PATH");
        assertThat(result).isNull();

        result = DirectoryValidator.ensureDirectory((String) null, "NULL_STRING");
        assertThat(result).isNull();
    }

    @Test
    void testEnsureDirectoryReturnsNullForFile() throws IOException {
        // Create a file, not a directory
        Path testFile = tempDir.resolve("not_a_directory.txt");
        Files.writeString(testFile, "test");

        Path result = DirectoryValidator.ensureDirectory(testFile, "NOT_A_DIR");

        assertThat(result).isNull();
    }

    @Test
    void testValidateDirectoryForExistingDirectory() {
        boolean result = DirectoryValidator.validateDirectory(tempDir, "VALID_DIR");
        assertThat(result).isTrue();
    }

    @Test
    void testValidateDirectoryForMissingDirectory() {
        Path missing = tempDir.resolve("does_not_exist");

        boolean result = DirectoryValidator.validateDirectory(missing, "MISSING_DIR");
        assertThat(result).isFalse();
    }

    @Test
    void testValidateDirectoryForFile() throws IOException {
        Path testFile = tempDir.resolve("file.txt");
        Files.writeString(testFile, "test");

        boolean result = DirectoryValidator.validateDirectory(testFile, "FILE_NOT_DIR");
        assertThat(result).isFalse();
    }

    @Test
    void testValidateDirectoryForNull() {
        boolean result = DirectoryValidator.validateDirectory(null, "NULL_DIR");
        assertThat(result).isFalse();
    }

    @Test
    void testIsWritable() {
        // Existing writable directory
        boolean result = DirectoryValidator.isWritable(tempDir);
        assertThat(result).isTrue();
    }

    @Test
    void testIsWritableForNonExistent() {
        Path missing = tempDir.resolve("does_not_exist");
        boolean result = DirectoryValidator.isWritable(missing);
        assertThat(result).isFalse();
    }

    @Test
    void testIsWritableForNull() {
        boolean result = DirectoryValidator.isWritable(null);
        assertThat(result).isFalse();
    }

    @Test
    void testNestedDirectoryCreation() {
        Path nested = tempDir.resolve("level1/level2/level3");
        assertThat(Files.exists(nested)).isFalse();

        Path result = DirectoryValidator.ensureDirectory(nested, "NESTED_DIR");

        assertThat(result).isNotNull();
        assertThat(result).isEqualTo(nested);
        assertThat(Files.exists(nested)).isTrue();
        assertThat(Files.isDirectory(nested)).isTrue();
    }

    @Test
    void testWithTildeExpansion() {
        // Test with tilde (will expand to actual home)
        String pathWithTilde = "~/Documents";  // Will expand to user's home
        Path result = DirectoryValidator.ensureDirectory(pathWithTilde, "HOME_DOCS");

        // Should succeed if home documents exists (which it usually does)
        // Or create it if it doesn't
        assertThat(result).isNotNull();
        assertThat(result.toString()).contains("Documents");
        assertThat(result.toString()).doesNotContain("~");
    }
}
