#!/bin/bash
# Organize existing recordings by version (retroactive)
# Usage: organize_by_version.sh [--dry-run]

set -euo pipefail

DRY_RUN=false
if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=true
    echo "=== DRY RUN MODE - No files will be moved ==="
fi

VOICE_NOTES="$HOME/Documents/VoiceNotes"
TX_LOGS="$VOICE_NOTES/tx_logs"
BY_VERSION="$VOICE_NOTES/by_version"

# Create version directories
if [ "$DRY_RUN" = false ]; then
    mkdir -p "$BY_VERSION"
    mkdir -p "$TX_LOGS/by_version"
fi

# Function to extract version from date (based on CHANGELOG.md)
# This is a heuristic - adjust dates based on your actual release history
get_version_from_date() {
    local dir_name="$1"
    
    # Extract date from directory name: YYYY-MMM-DD_HH.MM.SS_AM
    local date_part=$(echo "$dir_name" | sed 's/\([0-9]\{4\}-[A-Z][a-z][a-z]-[0-9]\{2\}\).*/\1/')
    
    # Convert to comparable format (YYYY-MM-DD)
    local date_stamp=$(echo "$date_part" | awk '{
        split($0, a, "-")
        months["Jan"]=1; months["Feb"]=2; months["Mar"]=3; months["Apr"]=4
        months["May"]=5; months["Jun"]=6; months["Jul"]=7; months["Aug"]=8
        months["Sep"]=9; months["Oct"]=10; months["Nov"]=11; months["Dec"]=12
        printf "%s-%02d-%s\n", a[1], months[a[2]], a[3]
    }')
    
    # Version history based on CHANGELOG.md
    # Adjust these dates based on your actual git tags
    if [[ "$date_stamp" < "2024-09-01" ]]; then
        echo "0.1.0"
    elif [[ "$date_stamp" < "2024-09-15" ]]; then
        echo "0.2.0"
    elif [[ "$date_stamp" < "2024-09-17" ]]; then
        echo "0.3.0"
    elif [[ "$date_stamp" < "2024-09-18" ]]; then
        echo "0.4.0"
    else
        echo "0.4.3"  # Current version
    fi
}

# Function to check if directory has version metadata
has_version_metadata() {
    local dir="$1"
    [ -f "$dir/.version" ] && return 0 || return 1
}

# Function to read version from metadata
read_version_metadata() {
    local dir="$1"
    if has_version_metadata "$dir"; then
        grep "^voxcore=" "$dir/.version" | cut -d'=' -f2
    else
        echo ""
    fi
}

echo "Analyzing recordings in $VOICE_NOTES..."
echo ""

# Count sessions by version (macOS bash 3.2 compatible)
version_list=""
total=0

for dir in "$VOICE_NOTES"/????-*-??_*; do
    [ -d "$dir" ] || continue
    
    dir_name=$(basename "$dir")
    
    # Try to read version from metadata first
    version=$(read_version_metadata "$dir")
    
    # Fall back to date-based heuristic
    if [ -z "$version" ]; then
        version=$(get_version_from_date "$dir_name")
    fi
    
    version_list="$version_list$version
"
    total=$((total + 1))
done

echo "Found $total recording sessions:"
# Count and display unique versions
if [ -n "$version_list" ]; then
    echo "$version_list" | sort -V | uniq -c | while read count version; do
        echo "  v$version: $count sessions"
    done
fi
echo ""

# Ask for confirmation unless dry-run
if [ "$DRY_RUN" = false ]; then
    read -p "Proceed with organizing recordings by version? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi

# Move recordings to versioned directories
echo ""
echo "Organizing recordings..."

moved=0
for dir in "$VOICE_NOTES"/????-*-??_*; do
    [ -d "$dir" ] || continue
    
    dir_name=$(basename "$dir")
    
    # Determine version
    version=$(read_version_metadata "$dir")
    if [ -z "$version" ]; then
        version=$(get_version_from_date "$dir_name")
        
        # Create version metadata for future
        if [ "$DRY_RUN" = false ]; then
            cat > "$dir/.version" <<EOF
voxcore=$version
voxcompose=unknown
model=unknown
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
inferred=true
EOF
            chmod 444 "$dir/.version"
        fi
    fi
    
    target_dir="$BY_VERSION/voxcore-$version"
    
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] Would move: $dir_name -> $target_dir/"
    else
        mkdir -p "$target_dir"
        mv "$dir" "$target_dir/"
        moved=$((moved + 1))
    fi
done

if [ "$DRY_RUN" = false ]; then
    echo ""
    echo "✓ Moved $moved recording sessions to versioned directories"
    echo "✓ Recordings organized in: $BY_VERSION"
    echo ""
    echo "Next steps:"
    echo "  1. Verify organization: ls -la $BY_VERSION"
    echo "  2. Update analysis scripts to use versioned paths"
    echo "  3. Run version recording script going forward (auto-integrated in push_to_talk.lua)"
fi

