#!/opt/homebrew/opt/bash/bin/bash
# rename_underscores_to_dashes.sh
# Recursively renames directories, replacing underscores with dashes

# Safety: stop on error
set -e

# Find all directories with underscores, deepest first
find . -depth -type d -name "*_*" | while read -r dir; do
  newdir="$(dirname "$dir")/$(basename "$dir" | tr '_' '-')"
  if [[ "$dir" != "$newdir" ]]; then
    echo "Renaming: $dir → $newdir"
    mv "$dir" "$newdir"
  fi
done

echo "✅ Done renaming directories."
