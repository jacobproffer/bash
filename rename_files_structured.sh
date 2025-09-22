#!/opt/homebrew/opt/bash/bin/bash
# rename_files_structured.sh
# Renames photos using EXIF DateTimeOriginal (fallback: file date)
# Unique sequence per file type
# Includes camera name in filename
# Logs changes for undo

if [ $# -lt 3 ]; then
  echo "Usage: $0 <date> <topic> <camera>"
  exit 1
fi

DATE="$1"
TOPIC="$2"
CAMERA="$3"

LOGFILE="rename_log.txt"
> "$LOGFILE"

declare -A COUNT  # associative array: key = extension, value = sequence number

# Find all image files
shopt -s nullglob
FILES=( *.jpg *.JPG *.jpeg *.JPEG *.dng *.DNG *.heic *.HEIC *.png *.PNG *.tif *.TIF *.tiff *.TIFF )

if [ ${#FILES[@]} -eq 0 ]; then
  echo "No image files found in the current directory."
  exit 0
fi

# Get EXIF date (or fallback) and sort
for f in "${FILES[@]}"; do
  datetime=$(exiftool -DateTimeOriginal -d '%Y-%m-%d %H:%M:%S' -s3 "$f" 2>/dev/null)
  if [ -z "$datetime" ]; then
    datetime=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$f")
  fi
  echo "$datetime|$f"
done | sort | while IFS='|' read -r datetime filename; do
  EXT="${filename##*.}"
  EXT_LOWER=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')

  # Increment counter for this extension
  SEQ=${COUNT[$EXT_LOWER]:-1}
  PAD=$(printf "%02d" $SEQ)
  COUNT[$EXT_LOWER]=$((SEQ+1))

  # Include camera name in filename
  NEWNAME="${DATE}-${TOPIC}-${CAMERA}-${PAD}.${EXT_LOWER}"
  echo "Renaming: $filename → $NEWNAME"
  echo "$NEWNAME|$filename" >> "$LOGFILE"
  mv "$filename" "$NEWNAME"
done

echo "✅ Done renaming files. Log saved to $LOGFILE"
