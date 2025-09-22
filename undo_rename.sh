#!/opt/homebrew/opt/bash/bin/bash
# undo_rename.sh
# Reverts renames based on rename_log.txt

LOGFILE="rename_log.txt"

if [ ! -f "$LOGFILE" ]; then
  echo "❌ No rename_log.txt found. Cannot undo."
  exit 1
fi

while IFS='|' read -r newname oldname; do
  if [ -f "$newname" ]; then
    echo "Reverting: $newname → $oldname"
    mv "$newname" "$oldname"
  fi
done < "$LOGFILE"

echo "✅ Undo complete."
