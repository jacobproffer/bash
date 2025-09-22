# bash

Collection of rename bash scripts for renaming folders and files.

## Rename Folders

This script will rename all folders (recursively) from underscores (\_) to dashes (-) inside whatever directory you run it in.

### Make Rename Folders Script Executable

```bash
chmod +x rename_underscores_to_dashes.sh
```

### Move Rename Folders Script to User Local Bin

```bash
sudo mv rename_underscores_to_dashes.sh /usr/local/bin/rename_underscores_to_dashes
```

### Execute Rename Folders Script

```bash
rename_underscores_to_dashes
```

## Rename Files

This script renames photos using EXIF DateTimeOriginal (fallback: file date).

### Make Rename Files Script Executable

```bash
chmod +x rename_files_structured.sh
```

### Move Rename Files Script to User Local Bin

```bash
sudo mv rename_files_structured.sh /usr/local/bin/rename_files_structured
```

### Execute Rename Files Script

```bash
rename_files_structured 2024-10-31 japan ricoh-gr-ii
```

## Undo Rename

This script reads `rename_log.txt` and reverses all renames.

### Make Undo Rename Script Executable

```bash
chmod +x undo_rename.sh
```

### Move Undo Rename Script to User Local Bin

```bash
sudo mv undo_rename.sh /usr/local/bin/undo_rename
```

### Execute Undo Script

```bash
undo_rename
```
