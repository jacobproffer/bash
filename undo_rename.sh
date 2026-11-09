#!/opt/homebrew/opt/bash/bin/bash
# undo_rename.sh
# Reverts the most recent run recorded in rename_log.txt.
# Runs are separated by lines starting with "#". Run again to undo the run before.

LOGFILE="rename_log.txt"

if [ ! -f "$LOGFILE" ]; then
  echo "❌ No rename_log.txt found. Cannot undo."
  exit 1
fi

mapfile -t LINES < "$LOGFILE"

# Find where the latest run starts (logs from the old script have no markers).
start=0
for i in "${!LINES[@]}"; do
  [[ "${LINES[$i]}" == \#* ]] && start=$i
done

# Revert in reverse order.
for (( i=${#LINES[@]}-1; i>=start; i-- )); do
  line="${LINES[$i]}"
  [[ -z "$line" || "$line" == \#* ]] && continue
  IFS='|' read -r newname oldname <<< "$line"
  if [ ! -f "$newname" ]; then
    echo "⚠️  $newname not found; skipped."
  elif [ -e "$oldname" ]; then
    echo "⚠️  $oldname already exists; left $newname unchanged."
  else
    echo "Reverting: $newname → $oldname"
    mv -n "$newname" "$oldname"
  fi
done

# Drop the undone run from the log.
if (( start == 0 )); then
  rm "$LOGFILE"
else
  printf '%s\n' "${LINES[@]:0:start}" > "$LOGFILE"
fi

echo "✅ Undo complete."
