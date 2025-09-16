#!/bin/bash
# Migrate personal dictionary corrections from ptt_config.lua to external file

set -euo pipefail

CONFIG_FILE="$HOME/.hammerspoon/ptt_config.lua"
TARGET_DIR="$HOME/.config/ptt-dictation"
TARGET_FILE="$TARGET_DIR/corrections.lua"

echo "=== Dictionary Migration Tool ==="
echo ""

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "No ptt_config.lua found at $CONFIG_FILE"
    echo "Nothing to migrate."
    exit 0
fi

# Check if DICTIONARY_REPLACE exists in config
if ! grep -q "DICTIONARY_REPLACE" "$CONFIG_FILE"; then
    echo "No DICTIONARY_REPLACE found in config."
    echo "Nothing to migrate."
    exit 0
fi

# Check if target already exists
if [ -f "$TARGET_FILE" ]; then
    echo "⚠️  Target file already exists: $TARGET_FILE"
    read -p "Overwrite? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Migration cancelled."
        exit 1
    fi
fi

# Create target directory
mkdir -p "$TARGET_DIR"

# Extract DICTIONARY_REPLACE section
echo "Extracting dictionary from $CONFIG_FILE..."

# Use awk to extract the DICTIONARY_REPLACE table
awk '
/DICTIONARY_REPLACE = \{/ {
    print "-- Migrated from ptt_config.lua on " strftime("%Y-%m-%d")
    print "-- Personal corrections dictionary"
    print ""
    print "return {"
    in_dict = 1
    next
}
in_dict && /^\s*\}/ {
    print "}"
    in_dict = 0
}
in_dict {
    print
}
' "$CONFIG_FILE" > "$TARGET_FILE"

if [ -s "$TARGET_FILE" ]; then
    echo "✅ Successfully migrated dictionary to $TARGET_FILE"
    echo ""
    echo "Next steps:"
    echo "1. Review the migrated file: $TARGET_FILE"
    echo "2. Remove DICTIONARY_REPLACE from $CONFIG_FILE"
    echo "3. Set DICTIONARY_REPLACE = nil in your config"
    echo "4. Reload Hammerspoon"
else
    echo "❌ Migration failed or no dictionary found"
    rm -f "$TARGET_FILE"
    exit 1
fi

# Offer to backup and clean the config
read -p "Create backup and remove DICTIONARY_REPLACE from config? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Backup
    BACKUP="$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$CONFIG_FILE" "$BACKUP"
    echo "✅ Backup created: $BACKUP"
    
    # Comment out DICTIONARY_REPLACE
    sed -i.tmp '/DICTIONARY_REPLACE = {/,/^  }/s/^/-- MIGRATED: /' "$CONFIG_FILE"
    rm -f "$CONFIG_FILE.tmp"
    
    # Add migration note
    cat >> "$CONFIG_FILE" << 'EOF'

  -- Dictionary corrections have been migrated to external file
  -- See: ~/.config/ptt-dictation/corrections.lua
  DICTIONARY_REPLACE = nil,  -- Auto-loads from external sources
EOF
    
    echo "✅ Config updated. DICTIONARY_REPLACE has been disabled."
    echo ""
    echo "Please reload Hammerspoon for changes to take effect."
fi