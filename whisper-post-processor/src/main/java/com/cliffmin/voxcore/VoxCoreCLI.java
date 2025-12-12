package com.cliffmin.voxcore;

import com.cliffmin.voxcore.config.VoxCoreConfig;
import com.cliffmin.voxcore.exception.ErrorCode;
import com.cliffmin.voxcore.exception.VoxCoreException;
import com.cliffmin.voxcore.transcription.TranscriptionService;
import picocli.CommandLine;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;
import picocli.CommandLine.Parameters;

import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.concurrent.Callable;

/**
 * Main VoxCore CLI - replaces Lua business logic.
 * Called by Hammerspoon for transcription.
 */
@Command(
    name = "voxcore",
    mixinStandardHelpOptions = true,
    version = "0.5.0",
    description = "VoxCore: Offline voice transcription with local processing",
    subcommands = {
        VoxCoreCLI.TranscribeCommand.class,
        VoxCoreCLI.ConfigCommand.class
    }
)
public class VoxCoreCLI implements Callable<Integer> {

    @Override
    public Integer call() {
        // Show help if no subcommand
        CommandLine.usage(this, System.out);
        return 0;
    }

    /**
     * Main entry point.
     */
    public static void main(String[] args) {
        int exitCode = new CommandLine(new VoxCoreCLI()).execute(args);
        System.exit(exitCode);
    }

    /**
     * Transcribe audio file command.
     */
    @Command(
        name = "transcribe",
        description = "Transcribe audio file to text"
    )
    static class TranscribeCommand implements Callable<Integer> {

        @Parameters(
            index = "0",
            description = "Audio file to transcribe (WAV format)"
        )
        private Path audioFile;

        @Option(
            names = {"-c", "--config"},
            description = "Config file (default: ~/.config/voxcore/config.json)"
        )
        private Path configFile;

        @Option(
            names = {"-m", "--model"},
            description = "Whisper model (default: base.en)"
        )
        private String model;

        @Option(
            names = {"--no-post-process"},
            description = "Skip post-processing"
        )
        private boolean noPostProcess;

        @Option(
            names = {"--debug"},
            description = "Enable debug output"
        )
        private boolean debug;

        @Override
        public Integer call() {
            try {
                // Load config
                VoxCoreConfig config = (configFile != null)
                    ? VoxCoreConfig.load(configFile)
                    : VoxCoreConfig.loadDefault();

                // Validate config
                if (!config.validate()) {
                    VoxCoreException error = new VoxCoreException(
                        ErrorCode.ERR_CONFIG_INVALID,
                        "Configuration validation failed",
                        String.join("; ", config.getValidationErrors())
                    );
                    outputError(error);
                    return 1;
                }

                // Override model if specified
                if (model != null) {
                    // TODO: Set model in config
                }

                // Create transcription service
                TranscriptionService service = new TranscriptionService(config);

                // Transcribe
                String result = service.transcribe(audioFile, !noPostProcess);

                // Output to stdout
                System.out.println(result);

                return 0;

            } catch (VoxCoreException e) {
                outputError(e);
                return 1;
            } catch (Exception e) {
                // Wrap unexpected exceptions
                VoxCoreException error = new VoxCoreException(
                    ErrorCode.ERR_UNKNOWN,
                    "Unexpected error: " + e.getMessage(),
                    e
                );
                outputError(error);
                return 1;
            }
        }

        /**
         * Output structured error to stderr (JSON format for Hammerspoon parsing).
         */
        private void outputError(VoxCoreException error) {
            if (debug) {
                // Human-readable format for debugging
                System.err.println(error.toFormattedString());
            } else {
                // JSON format for Hammerspoon parsing
                System.err.println(error.toJson().toString());
            }
        }
    }

    /**
     * Config validation and display command.
     */
    @Command(
        name = "config",
        description = "Manage VoxCore configuration",
        subcommands = {
            ConfigValidateCommand.class,
            ConfigShowCommand.class
        }
    )
    static class ConfigCommand implements Callable<Integer> {
        @Override
        public Integer call() {
            CommandLine.usage(this, System.out);
            return 0;
        }
    }

    /**
     * Validate config command.
     */
    @Command(
        name = "validate",
        description = "Validate configuration"
    )
    static class ConfigValidateCommand implements Callable<Integer> {

        @Option(
            names = {"-c", "--config"},
            description = "Config file to validate"
        )
        private Path configFile;

        @Override
        public Integer call() throws Exception {
            VoxCoreConfig config = (configFile != null)
                ? VoxCoreConfig.load(configFile)
                : VoxCoreConfig.loadDefault();

            boolean valid = config.validate();

            if (valid) {
                System.out.println("✓ Configuration is valid");
                System.out.println("  Notes dir: " + config.getNotesPath());
                System.out.println("  Logs dir:  " + config.getLogPath());
                if (config.getVocabularyPath() != null) {
                    System.out.println("  Vocab:     " + config.getVocabularyPath());
                }
                return 0;
            } else {
                System.err.println("✗ Configuration validation failed:");
                for (String error : config.getValidationErrors()) {
                    System.err.println("  - " + error);
                }
                return 1;
            }
        }
    }

    /**
     * Show effective config command.
     */
    @Command(
        name = "show",
        description = "Show effective configuration"
    )
    static class ConfigShowCommand implements Callable<Integer> {

        @Option(
            names = {"-c", "--config"},
            description = "Config file to show"
        )
        private Path configFile;

        @Option(
            names = {"--json"},
            description = "Output as JSON"
        )
        private boolean json;

        @Override
        public Integer call() throws Exception {
            VoxCoreConfig config = (configFile != null)
                ? VoxCoreConfig.load(configFile)
                : VoxCoreConfig.loadDefault();

            config.validate();

            if (json) {
                System.out.println(config.toJson());
            } else {
                System.out.println("VoxCore Configuration");
                System.out.println("====================");
                System.out.println("Notes directory:    " + config.getNotesPath());
                System.out.println("Logs directory:     " + config.getLogPath());
                System.out.println("Whisper model:      " + config.getWhisperModel());
                System.out.println("Vocabulary file:    " + config.getVocabularyPath());
                System.out.println("VoxCompose enabled: " + config.isVoxcomposeEnabled());
                System.out.println("Dynamic vocab:      " + config.isEnableDynamicVocab());
            }

            return 0;
        }
    }
}
