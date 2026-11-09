#!/opt/homebrew/opt/bash/bin/bash
# rename_files_structured.sh
#
# Renames photos in the current directory to:
#   <date>-<location>-<camera>-<NN>.<ext>
#
#   date      EXIF DateTimeOriginal → CreateDate → file modified date
#   location  argument → City / Location metadata tags → GPS reverse lookup
#             → most common location found in the folder → asks you
#   camera    EXIF Make + Model (e.g. "ricoh-gr-ii"), shortened via CAMERA_ALIASES
#
# Files from the same shot (e.g. DSCF1234.JPG + DSCF1234.RAF) share a number.
# Each run is appended to rename_log.txt; `undo_rename` reverts the latest run.
#
# GPS lookup sends photo coordinates to OpenStreetMap Nominatim
# (https://nominatim.openstreetmap.org). Use --no-gps to stay offline.
#
# Usage:
#   rename_files_structured [options] [location]
#
# Options:
#   -n, --dry-run        Show the planned renames without changing anything
#   -y, --yes            Don't ask for confirmation
#       --no-gps         Skip the online GPS → place name lookup
#       --date=Y-M-D     Use this date for every file instead of EXIF
#       --camera=NAME    Use this camera name for every file instead of EXIF
#   -h, --help           Show this help

set -uo pipefail

# Camera name overrides: key is the auto-generated name, value is what you want.
declare -A CAMERA_ALIASES=(
  ["sony-ilce-7m4"]="sony-a7iv"
  ["fujifilm-x100v"]="fujifilm-x100v"
)

IMAGE_EXTS=(jpg jpeg heic heif png tif tiff dng raf arw cr2 cr3 nef orf rw2)
LOGFILE="rename_log.txt"
USER_AGENT="rename_files_structured.sh (personal photo renaming script)"
SEP=$'\x1f'   # field separator that never appears in metadata or filenames

usage() { sed -n '/^# Usage:/,/^# *-h/p' "$0" | sed 's/^# \{0,1\}//'; }

# ── arguments ───────────────────────────────────────────────────────────────
DRY_RUN=false
ASSUME_YES=false
USE_GPS=true
LOCATION_ARG=""
DATE_ARG=""
CAMERA_ARG=""

for arg in "$@"; do
  case "$arg" in
    -n|--dry-run) DRY_RUN=true ;;
    -y|--yes)     ASSUME_YES=true ;;
    --no-gps)     USE_GPS=false ;;
    --date=*)     DATE_ARG="${arg#*=}" ;;
    --camera=*)   CAMERA_ARG="${arg#*=}" ;;
    -h|--help)    usage; exit 0 ;;
    -*)           echo "Unknown option: $arg"; usage; exit 1 ;;
    *)
      if [[ -n "$LOCATION_ARG" ]]; then
        echo "Only one location argument is allowed (quote it if it has spaces)."
        echo "The old '<date> <topic> <camera>' form is now: --date=... --camera=... <topic>"
        exit 1
      fi
      LOCATION_ARG="$arg"
      ;;
  esac
done

if [[ -n "$DATE_ARG" && ! "$DATE_ARG" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "--date must look like YYYY-MM-DD"; exit 1
fi

command -v exiftool >/dev/null || { echo "exiftool is required: brew install exiftool"; exit 1; }
if $USE_GPS && [[ -z "$LOCATION_ARG" ]] && ! { command -v curl >/dev/null && command -v jq >/dev/null; }; then
  echo "⚠️  curl and jq are needed for GPS lookup; continuing without it."
  USE_GPS=false
fi

# ── helpers ─────────────────────────────────────────────────────────────────
slugify() {
  local s
  s=$(printf '%s' "$1" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null) || s="$1"
  printf '%s' "$s" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

camera_name() {   # camera_name <make> <model>
  local make model brand name
  make=$(slugify "$1"); model=$(slugify "$2")
  brand="${make%%-*}"                       # "ricoh-imaging-company-ltd" → "ricoh"
  if [[ -z "$model" ]]; then
    name="$brand"
  elif [[ -z "$brand" || "$brand" == "apple" || "$model" == "$brand"* ]]; then
    name="$model"                           # "iphone-15-pro", "canon-eos-r5"
  else
    name="$brand-$model"                    # "ricoh-gr-ii", "fujifilm-x100v"
  fi
  printf '%s' "${CAMERA_ALIASES[$name]:-$name}"
}

declare -A GEO_CACHE
GEO_CALLS=0
GEO_RESULT=""
reverse_geocode() {   # sets GEO_RESULT; caches per ~1 km grid cell
  local lat="$1" lon="$2" key json
  key=$(printf '%.2f,%.2f' "$lat" "$lon")
  if [[ -n "${GEO_CACHE[$key]+set}" ]]; then GEO_RESULT="${GEO_CACHE[$key]}"; return; fi
  (( GEO_CALLS > 0 )) && sleep 1          # Nominatim allows 1 request/second
  (( GEO_CALLS++ ))
  json=$(curl -fsS --max-time 10 -A "$USER_AGENT" -G "https://nominatim.openstreetmap.org/reverse" \
           --data-urlencode "format=jsonv2" --data-urlencode "zoom=10" \
           --data-urlencode "accept-language=en" \
           --data-urlencode "lat=$lat" --data-urlencode "lon=$lon" 2>/dev/null) || json=""
  GEO_RESULT=$(printf '%s' "$json" | jq -r \
    '.address // {} | (.city // .town // .village // .hamlet // .municipality // .county // .state // empty)' 2>/dev/null)
  GEO_CACHE[$key]="$GEO_RESULT"
}

# ── read metadata (one exiftool call for the whole folder) ──────────────────
EXT_ARGS=()
for e in "${IMAGE_EXTS[@]}"; do EXT_ARGS+=(-ext "$e"); done

FMT="\$DateTimeOriginal${SEP}\$CreateDate${SEP}\$FileModifyDate${SEP}\$Make${SEP}\$Model"
FMT+="${SEP}\$City${SEP}\$Location${SEP}\$Sub-location"
FMT+="${SEP}\$Composite:GPSLatitude#${SEP}\$Composite:GPSLongitude#${SEP}\$FileName"

declare -A SHOT_TIME SHOT_MAKE SHOT_MODEL SHOT_PLACE SHOT_LAT SHOT_LON SHOT_FILES
declare -a ALL_FILES=()

while IFS="$SEP" read -r dto cdate fmod make model city loc subloc lat lon fname; do
  [[ -z "$fname" ]] && continue
  ALL_FILES+=("$fname")
  shot="${fname%.*}"
  when="${dto:-${cdate:-$fmod}}"
  # A shot's time is its earliest file's time.
  if [[ -z "${SHOT_TIME[$shot]+set}" || ( -n "$when" && "$when" < "${SHOT_TIME[$shot]}" ) ]]; then
    SHOT_TIME[$shot]="$when"
  fi
  [[ -z "${SHOT_MODEL[$shot]:-}" && -n "$model$make" ]] && { SHOT_MAKE[$shot]="$make"; SHOT_MODEL[$shot]="$model"; }
  place="${city:-${loc:-$subloc}}"
  [[ -z "${SHOT_PLACE[$shot]:-}" && -n "$place" ]] && SHOT_PLACE[$shot]="$place"
  [[ -z "${SHOT_LAT[$shot]:-}" && -n "$lat" && -n "$lon" ]] && { SHOT_LAT[$shot]="$lat"; SHOT_LON[$shot]="$lon"; }
  SHOT_FILES[$shot]+="$fname$SEP"
done < <(exiftool -q -m -i HIDDEN -d '%Y-%m-%d %H:%M:%S' -p "$FMT" "${EXT_ARGS[@]}" . 2>/dev/null)

if (( ${#ALL_FILES[@]} == 0 )); then
  echo "No image files found in the current directory."
  exit 0
fi

# Shots in capture order
mapfile -t SHOTS < <(for s in "${!SHOT_TIME[@]}"; do printf '%s%s%s\n' "${SHOT_TIME[$s]}" "$SEP" "$s"; done \
                     | sort | cut -d"$SEP" -f2)

# ── resolve location per shot ───────────────────────────────────────────────
declare -A SHOT_LOC
if [[ -n "$LOCATION_ARG" ]]; then
  loc_slug=$(slugify "$LOCATION_ARG")
  for s in "${SHOTS[@]}"; do SHOT_LOC[$s]="$loc_slug"; done
else
  declare -A LOC_COUNT
  looked_up=false
  for s in "${SHOTS[@]}"; do
    name="${SHOT_PLACE[$s]:-}"
    if [[ -z "$name" && $USE_GPS == true && -n "${SHOT_LAT[$s]:-}" ]]; then
      $looked_up || { echo "📍 Looking up GPS locations…"; looked_up=true; }
      reverse_geocode "${SHOT_LAT[$s]}" "${SHOT_LON[$s]}"
      name="$GEO_RESULT"
    fi
    slug=$(slugify "$name")
    SHOT_LOC[$s]="$slug"
    [[ -n "$slug" ]] && LOC_COUNT[$slug]=$(( ${LOC_COUNT[$slug]:-0} + 1 ))
  done

  # Shots without a location borrow the folder's most common one.
  fallback=""; best=0
  for l in "${!LOC_COUNT[@]}"; do
    (( LOC_COUNT[$l] > best )) && { best=${LOC_COUNT[$l]}; fallback="$l"; }
  done
  missing=0
  for s in "${SHOTS[@]}"; do [[ -z "${SHOT_LOC[$s]}" ]] && (( missing++ )); done
  if (( missing > 0 )) && [[ -z "$fallback" ]] && [[ -t 0 ]]; then
    read -r -p "No location found in metadata for $missing shot(s). Location (blank to omit): " answer
    fallback=$(slugify "$answer")
  fi
  for s in "${SHOTS[@]}"; do [[ -z "${SHOT_LOC[$s]}" ]] && SHOT_LOC[$s]="$fallback"; done
fi

# ── build the plan ──────────────────────────────────────────────────────────
declare -A SHOT_PREFIX PREFIX_TOTAL PREFIX_SEQ
for s in "${SHOTS[@]}"; do
  date="${DATE_ARG:-${SHOT_TIME[$s]%% *}}"
  if [[ -n "$CAMERA_ARG" ]]; then cam=$(slugify "$CAMERA_ARG")
  else cam=$(camera_name "${SHOT_MAKE[$s]:-}" "${SHOT_MODEL[$s]:-}"); fi
  prefix=""
  for part in "$date" "${SHOT_LOC[$s]}" "$cam"; do
    [[ -n "$part" ]] && prefix+="${prefix:+-}$part"
  done
  SHOT_PREFIX[$s]="$prefix"
  PREFIX_TOTAL[$prefix]=$(( ${PREFIX_TOTAL[$prefix]:-0} + 1 ))
done

SRC=(); DST=()
for s in "${SHOTS[@]}"; do
  prefix="${SHOT_PREFIX[$s]}"
  seq=$(( ${PREFIX_SEQ[$prefix]:-0} + 1 )); PREFIX_SEQ[$prefix]=$seq
  width=${#PREFIX_TOTAL[$prefix]}; (( width < 2 )) && width=2
  num=$(printf "%0${width}d" "$seq")
  IFS="$SEP" read -r -a files <<< "${SHOT_FILES[$s]}"
  for f in "${files[@]}"; do
    [[ -z "$f" ]] && continue
    ext=$(printf '%s' "${f##*.}" | tr '[:upper:]' '[:lower:]')
    new="$prefix-$num.$ext"
    [[ "$f" == "$new" ]] && continue
    SRC+=("$f"); DST+=("$new")
  done
done

if (( ${#SRC[@]} == 0 )); then
  echo "✅ All ${#ALL_FILES[@]} files are already named correctly."
  exit 0
fi

for i in "${!SRC[@]}"; do echo "${SRC[$i]} → ${DST[$i]}"; done
echo ""
echo "${#SRC[@]} file(s) to rename."

if $DRY_RUN; then
  echo "Dry run: nothing was changed."
  exit 0
fi

if ! $ASSUME_YES && [[ -t 0 ]]; then
  read -r -p "Proceed? [Y/n] " answer
  [[ "$answer" =~ ^[Nn] ]] && { echo "Cancelled."; exit 0; }
fi

# ── rename (two phases, so names can be swapped without clobbering) ─────────
TMP=()
for i in "${!SRC[@]}"; do
  tmp=".renaming-$$-$i.${SRC[$i]##*.}"
  mv -n "${SRC[$i]}" "$tmp" && TMP[$i]="$tmp"
done

echo "# $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOGFILE"
renamed=0; skipped=0
for i in "${!SRC[@]}"; do
  [[ -z "${TMP[$i]:-}" ]] && { echo "⚠️  Could not move ${SRC[$i]}; skipped."; (( skipped++ )); continue; }
  if [[ -e "${DST[$i]}" ]]; then
    echo "⚠️  ${DST[$i]} already exists; left ${SRC[$i]} unchanged."
    mv -n "${TMP[$i]}" "${SRC[$i]}"
    (( skipped++ ))
    continue
  fi
  mv -n "${TMP[$i]}" "${DST[$i]}"
  echo "${DST[$i]}|${SRC[$i]}" >> "$LOGFILE"
  (( renamed++ ))
done

summary="✅ Renamed $renamed file(s)"
(( skipped > 0 )) && summary+=", skipped $skipped"
echo "$summary. Log: $LOGFILE (undo with undo_rename)"
