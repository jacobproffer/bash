# Bash Rename Scripts

Collection of bash scripts for organizing files and folders.

- **rename_underscores_to_dashes**: Converts underscores (\_) to dashes (-) in folder names recursively.
- **rename_files_structured**: Renames image files to `<date>-<location>-<camera>-<NN>`, reading the date, camera and location (tags or GPS) from each photo's metadata. RAW+JPG pairs share a number.
- **undo_rename**: Reverts the most recent run of `rename_files_structured` using its log.

## Prerequisites

- macOS with Bash 3.x or newer (Bash 5+ recommended for `rename_files_structured`)
- [Homebrew](https://brew.sh/) to install a modern Bash version if needed
- `exiftool` installed for reading photo metadata:

```bash
brew install exiftool
```

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

This script renames every photo in the current directory to `<date>-<location>-<camera>-<NN>.<ext>`, for example `2024-10-31-kyoto-ricoh-gr-ii-01.jpg`.

- **Date:** EXIF `DateTimeOriginal`, falling back to `CreateDate`, then the file's modified date.
- **Camera:** EXIF make and model (`RICOH` + `GR II` → `ricoh-gr-ii`). Edit `CAMERA_ALIASES` at the top of the script to shorten names (e.g. `sony-ilce-7m4` → `sony-a7iv`).
- **Location:** the location argument if you pass one; otherwise the photo's City/Location tags; otherwise its GPS coordinates looked up through [OpenStreetMap Nominatim](https://nominatim.openstreetmap.org) (this sends the coordinates online; turn it off with `--no-gps`). Photos with no location borrow the most common location in the folder; if none is found, the script asks.
- **Numbering:** in capture order, restarting for each date + location + camera. Files from the same shot (`DSCF1234.JPG` + `DSCF1234.RAF`) share a number.

The script shows the planned renames and asks before changing anything (press Enter to continue). It never overwrites an existing file, and each run is appended to `rename_log.txt`.

GPS lookup also needs `curl` and `jq` (both come with recent macOS).

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
rename_files_structured
```

Set the location yourself (it overrides metadata):

```bash
rename_files_structured "blue ridge"
```

Preview without renaming:

```bash
rename_files_structured --dry-run
```

Other options: `-y` skips the confirmation, `--no-gps` skips the online lookup, and `--date=2024-10-31` / `--camera=ricoh-gr-ii` override the metadata for every file. The old three-argument form maps to:

```bash
rename_files_structured --date=2024-10-31 --camera=ricoh-gr-ii japan
```

## Undo Rename

This script reads `rename_log.txt` and reverses the most recent run. Run it again to undo the run before that.

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
