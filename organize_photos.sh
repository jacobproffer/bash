#!/usr/bin/env bash
# organize_photos.sh
#
# Scans all files (recursively) in a target directory and moves them into
# YYYY-MM/DD subfolders based on the date found at the start of the filename.
#
# Expected filename format: YYYY-MM-DD ...  (e.g. "2024-05-19 16.33.26.jpg")
#
# Usage:
#   ./organize_photos.sh [--dry-run] /path/to/Camera\ Uploads
#
# Options:
#   --dry-run   Preview what would happen without moving any files.

set -euo pipefail

# ── argument parsing ────────────────────────────────────────────────────────
DRY_RUN=false
TARGET_DIR=""

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        *)         TARGET_DIR="$arg" ;;
    esac
done

if [[ -z "$TARGET_DIR" ]]; then
    echo "Usage: $0 [--dry-run] /path/to/Camera\ Uploads"
    exit 1
fi

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Error: '$TARGET_DIR' is not a directory."
    exit 1
fi

TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"   # normalise to absolute path

# ── counters ────────────────────────────────────────────────────────────────
moved=0
skipped=0
errors=0

# ── main loop ───────────────────────────────────────────────────────────────
# Find every regular file, at any depth, whose name starts with YYYY-MM-DD.
while IFS= read -r -d '' file; do
    filename="$(basename "$file")"

    # Extract date components from the filename (must start with YYYY-MM-DD).
    if [[ "$filename" =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2}) ]]; then
        year="${BASH_REMATCH[1]}"
        month="${BASH_REMATCH[2]}"
        day="${BASH_REMATCH[3]}"
    else
        echo "SKIP (no date in name): $file"
        (( skipped++ )) || true
        continue
    fi

    dest_dir="$TARGET_DIR/${year}-${month}/${year}-${month}-${day}"
    dest_file="$dest_dir/$filename"

    # Skip if the file is already in the correct folder.
    if [[ "$(dirname "$file")" == "$dest_dir" ]]; then
        echo "OK   (already in place): $file"
        (( skipped++ )) || true
        continue
    fi

    # Guard against overwriting an existing file with a different path.
    if [[ -e "$dest_file" && "$dest_file" != "$file" ]]; then
        echo "SKIP (destination exists): $file  →  $dest_file"
        (( skipped++ )) || true
        continue
    fi

    echo "MOVE: $file"
    echo "   →  $dest_file"

    if [[ "$DRY_RUN" == false ]]; then
        mkdir -p "$dest_dir"
        if mv "$file" "$dest_file"; then
            (( moved++ )) || true
        else
            echo "ERROR moving: $file"
            (( errors++ )) || true
        fi
    else
        (( moved++ )) || true   # count as "would move" in dry-run
    fi

done < <(find "$TARGET_DIR" -type f -print0)

# ── summary ─────────────────────────────────────────────────────────────────
echo ""
if [[ "$DRY_RUN" == true ]]; then
    echo "=== DRY RUN complete — no files were moved ==="
else
    echo "=== Done ==="
fi
echo "  Would move / moved : $moved"
echo "  Skipped            : $skipped"
echo "  Errors             : $errors"
