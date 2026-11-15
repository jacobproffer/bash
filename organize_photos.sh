#!/usr/bin/env bash
# organize_photos.sh
#
# Moves photos into month folders based on the date at the start of each
# filename. Trips get one named folder inside the month they started in:
#
#   <target>/2026-11/2026-11-01 16.33.26.jpg          everyday photos
#   <target>/2026-11/2026-11-14_japan/...              --trip=japan
#
# Expected filename format: YYYY-MM-DD... (e.g. "2024-05-19 16.33.26.jpg" or
# "2024-05-19_kyoto_ricoh-gr-ii_01.jpg"), or YYYY-MM... when the day isn't
# known ("2018-07_marquette_iphone-6_14.jpg").
#
# Without --trip, every dated file is moved into its month folder, including
# files in old YYYY-MM/YYYY-MM-DD day folders. Their rename_log.txt is merged
# into the month folder's log (so undo_rename still works) and the empty day
# folder is removed. Files already inside a trip folder (YYYY-MM-DD_name, or
# the older YYYY-MM-DD-name) are never touched.
#
# With --trip, only files that are not yet in a month folder are moved, all
# into one folder named after the earliest date among them.
#
# Usage:
#   organize_photos [--dry-run] [--trip=NAME] /path/to/Camera\ Uploads
#
# Options:
#   -n, --dry-run    Preview what would happen without moving any files
#       --trip=NAME  Put this batch into a <date>_<name> trip folder
#   -h, --help       Show this help

set -euo pipefail

LOGFILE="rename_log.txt"

usage() { sed -n '/^# Usage:/,/^# *-h/p' "$0" | sed 's/^# \{0,1\}//'; }

slugify() {
    local s
    s=$(printf '%s' "$1" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null) || s="$1"
    printf '%s' "$s" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

# ── argument parsing ────────────────────────────────────────────────────────
DRY_RUN=false
TRIP=""
TARGET_DIR=""

for arg in "$@"; do
    case "$arg" in
        -n|--dry-run) DRY_RUN=true ;;
        --trip=*)     TRIP=$(slugify "${arg#*=}")
                      [[ -z "$TRIP" ]] && { echo "--trip needs a name, e.g. --trip=japan"; exit 1; } ;;
        -h|--help)    usage; exit 0 ;;
        -*)           echo "Unknown option: $arg"; usage; exit 1 ;;
        *)            TARGET_DIR="$arg" ;;
    esac
done

if [[ -z "$TARGET_DIR" ]]; then
    usage
    exit 1
fi

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Error: '$TARGET_DIR' is not a directory."
    exit 1
fi

TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"   # normalise to absolute path

DATE_RE='^([0-9]{4})-([0-9]{2})(-[0-9]{2})?([-_ .]|$)'   # YYYY-MM-DD or YYYY-MM
MONTH_RE='^[0-9]{4}-[0-9]{2}$'
DAY_RE='^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
# Trip folders: YYYY-MM-DD_name, old YYYY-MM-DD-name, or YYYY-MM-name.
TRIP_DIR_RE='^[0-9]{4}-[0-9]{2}/[0-9]{4}-[0-9]{2}(-[0-9]{2})?[-_][a-z][^/]*/'

# ── collect the files to move ───────────────────────────────────────────────
FILES=()
skipped=0
while IFS= read -r -d '' file; do
    filename="$(basename "$file")"
    rel="${file#"$TARGET_DIR"/}"

    # Housekeeping files: handled with their folder, never moved on their own.
    [[ "$filename" == .* || "$filename" == "$LOGFILE" ]] && continue

    if [[ ! "$filename" =~ $DATE_RE ]]; then
        echo "SKIP (no date in name): $rel"
        skipped=$((skipped + 1))
        continue
    fi

    # Trip folders are finished; leave them alone.
    [[ "$rel" =~ $TRIP_DIR_RE ]] && continue

    # A trip only takes files that aren't sorted into a month yet.
    if [[ -n "$TRIP" && "${rel%%/*}" =~ $MONTH_RE && "$rel" == */* ]]; then
        continue
    fi

    FILES+=("$file")
done < <(find "$TARGET_DIR" -type f -print0)

# A trip folder is named after the earliest date in the batch.
TRIP_DIR=""
if [[ -n "$TRIP" && ${#FILES[@]} -gt 0 ]]; then
    first=$(for f in "${FILES[@]}"; do basename "$f" | sed -E 's/^([0-9]{4}-[0-9]{2}(-[0-9]{2})?).*/\1/'; done | sort | head -1)
    TRIP_DIR="${first:0:7}/${first}_${TRIP}"
fi

# ── move ────────────────────────────────────────────────────────────────────
moved=0
errors=0
for file in ${FILES[@]+"${FILES[@]}"}; do
    filename="$(basename "$file")"
    [[ "$filename" =~ $DATE_RE ]]
    month="${BASH_REMATCH[1]}-${BASH_REMATCH[2]}"

    if [[ -n "$TRIP_DIR" ]]; then
        dest_dir="$TARGET_DIR/$TRIP_DIR"
    else
        dest_dir="$TARGET_DIR/$month"
    fi
    dest_file="$dest_dir/$filename"

    [[ "$(dirname "$file")" == "$dest_dir" ]] && continue   # already in place

    if [[ -e "$dest_file" ]]; then
        echo "SKIP (destination exists): ${file#"$TARGET_DIR"/}  →  ${dest_file#"$TARGET_DIR"/}"
        skipped=$((skipped + 1))
        continue
    fi

    echo "MOVE: ${file#"$TARGET_DIR"/}  →  ${dest_file#"$TARGET_DIR"/}"

    if [[ "$DRY_RUN" == false ]]; then
        mkdir -p "$dest_dir"
        if mv -n "$file" "$dest_file"; then
            moved=$((moved + 1))
        else
            echo "ERROR moving: $file"
            errors=$((errors + 1))
        fi
    else
        moved=$((moved + 1))   # count as "would move" in dry-run
    fi
done

# ── tidy old day folders (YYYY-MM/YYYY-MM-DD) ───────────────────────────────
# Once a day folder holds nothing but its rename log, merge the log into the
# month folder (the logged names are plain filenames, so undo still works
# there) and remove the folder.
removed=0
if [[ -z "$TRIP" ]]; then
    for day_dir in "$TARGET_DIR"/*/*/; do
        day_dir="${day_dir%/}"
        [[ -d "$day_dir" ]] || continue
        day="$(basename "$day_dir")"
        month_dir="$(dirname "$day_dir")"
        [[ "$day" =~ $DAY_RE && "$(basename "$month_dir")" =~ $MONTH_RE ]] || continue

        # In a dry run the photos haven't moved yet, so don't count them.
        # ._* files are macOS metadata companions on exFAT/FAT drives.
        ignore=(! -name .DS_Store ! -name '._*' ! -name "$LOGFILE")
        [[ "$DRY_RUN" == true ]] && ignore+=(! -name '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*')
        if [[ -n "$(find "$day_dir" -mindepth 1 "${ignore[@]}" | head -1)" ]]; then
            echo "KEEP (not empty): ${day_dir#"$TARGET_DIR"/}"
            continue
        fi

        if [[ -f "$day_dir/$LOGFILE" ]]; then
            echo "MERGE LOG: ${day_dir#"$TARGET_DIR"/}/$LOGFILE  →  ${month_dir#"$TARGET_DIR"/}/$LOGFILE"
            [[ "$DRY_RUN" == false ]] && cat "$day_dir/$LOGFILE" >> "$month_dir/$LOGFILE"
        fi
        echo "REMOVE FOLDER: ${day_dir#"$TARGET_DIR"/}"
        if [[ "$DRY_RUN" == false ]]; then
            rm -f "$day_dir/$LOGFILE" "$day_dir/.DS_Store"
            find "$day_dir" -mindepth 1 -maxdepth 1 -name '._*' -delete
            rmdir "$day_dir"
        fi
        removed=$((removed + 1))
    done
fi

# ── summary ─────────────────────────────────────────────────────────────────
echo ""
if [[ "$DRY_RUN" == true ]]; then
    echo "=== DRY RUN complete — no files were moved ==="
else
    echo "=== Done ==="
fi
[[ -n "$TRIP_DIR" ]] && echo "  Trip folder        : $TRIP_DIR"
echo "  Would move / moved : $moved"
echo "  Day folders removed: $removed"
echo "  Skipped            : $skipped"
echo "  Errors             : $errors"
