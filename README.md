# Bash Rename Scripts

Collection of bash scripts for organizing files and folders.

- **rename_underscores_to_dashes**: Converts underscores (\_) to dashes (-) in folder names recursively.
- **rename_files_structured**: Renames image files to `<date>_<location>_<camera>_<NN>`, reading the date, camera and location (tags or GPS) from each photo's metadata. RAW+JPG pairs share a number.
- **undo_rename**: Reverts the most recent run of `rename_files_structured` using its log.
- **organize_photos**: Moves files into `YYYY-MM` month folders based on the date at the start of each filename, or into a `YYYY-MM-DD_<trip>` folder with `--trip`.

## Folder and file layout

```
Camera Uploads/
  2026-11/
    2026-11-01_marquette_iphone-16-pro_01.jpg     everyday photos sit in the month folder
    2026-11-03_marquette_iphone-16-pro_01.jpg
    rename_log.txt
    2026-11-14_japan/                             trips get one folder, named after their first day
      2026-11-14_japan_ricoh-gr-ii_01.dng
      2026-11-14_japan_ricoh-gr-ii_01.jpg
      2026-11-15_japan_ricoh-gr-ii_01.jpg
```

Underscores separate the fields of a name; dashes join words inside a field (`new-york`, `ricoh-gr-ii`). So a name can always be split back into date, location, camera and number.

Typical workflow:

```bash
organize_photos ~/Dropbox/Camera\ Uploads                 # everyday photos → month folders
organize_photos --trip=japan ~/Dropbox/Camera\ Uploads    # or: this batch is a trip
cd ~/Dropbox/Camera\ Uploads/2026-11/2026-11-14_japan
rename_files_structured japan
```

## Installing

Run the `chmod` and `ln` commands below from this folder. They link each command to the script here (rather than moving it), so `git pull` or any edit takes effect immediately.

## Prerequisites

- macOS with Bash 3.x or newer (Bash 5+ recommended for `rename_files_structured`)
- [Homebrew](https://brew.sh/) to install a modern Bash version if needed
- `exiftool` installed for reading photo metadata:

```bash
brew install exiftool
```

## Rename Folders

This script will rename all folders (recursively) from underscores (\_) to dashes (-) inside whatever directory you run it in.

> **Don't run it on your photo folders.** Trip folders use an underscore between date and name (`2026-11-14_japan`), and `organize_photos` relies on it to recognise them.

### Make Rename Folders Script Executable

```bash
chmod +x rename_underscores_to_dashes.sh
```

### Link Rename Folders Script into User Local Bin

```bash
sudo ln -sf "$PWD/rename_underscores_to_dashes.sh" /usr/local/bin/rename_underscores_to_dashes
```

### Execute Rename Folders Script

```bash
rename_underscores_to_dashes
```

## Rename Files

This script renames every photo in the current directory to `<date>_<location>_<camera>_<NN>.<ext>`, for example `2024-10-31_kyoto_ricoh-gr-ii_01.jpg`. Photos with no location get `<date>_<camera>_<NN>.<ext>`.

- **Date:** a date already at the start of the filename (`2012-04-14-...`), since old exports often carry the export date in their metadata; otherwise EXIF `DateTimeOriginal`, falling back to `CreateDate`, then the file's modified date. New camera files (`IMG_1234.HEIC`, `R0012345.JPG`) have no date in the name, so they always use EXIF.
- **Camera:** EXIF make and model (`RICOH` + `GR II` → `ricoh-gr-ii`). Edit `CAMERA_ALIASES` at the top of the script to shorten names (e.g. `sony-ilce-7m4` → `sony-a7iv`). If a photo has no camera in its metadata, the camera already in its filename is kept. iPhones and cameras found elsewhere in the folder are recognised automatically; add older cameras to `KNOWN_CAMERAS` at the top of the script (otherwise, in an old dash-style name, the camera stays attached to the location, e.g. `marquette-canon-sd400`).
- **Location:** the location argument if you pass one; otherwise the location already in the filename from an earlier run (old dash-style names like `2024-10-31-kyoto-ricoh-gr-ii-01.jpg` included, so re-running the script converts them and keeps their location); otherwise the photo's City/Location tags; otherwise its GPS coordinates looked up through [OpenStreetMap Nominatim](https://nominatim.openstreetmap.org) (this sends the coordinates online; turn it off with `--no-gps`). Photos with no location borrow the most common location in the folder; if none is found, the script asks.
- **Numbering:** in capture order, restarting for each date + location + camera. Files from the same shot (`DSCF1234.JPG` + `DSCF1234.RAF`) share a number.

The script shows the planned renames and asks before changing anything (press Enter to continue). It never overwrites an existing file, and each run is appended to `rename_log.txt`.

GPS lookup also needs `curl` and `jq` (both come with recent macOS).

### Make Rename Files Script Executable

```bash
chmod +x rename_files_structured.sh
```

### Link Rename Files Script into User Local Bin

```bash
sudo ln -sf "$PWD/rename_files_structured.sh" /usr/local/bin/rename_files_structured
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

### Link Undo Rename Script into User Local Bin

```bash
sudo ln -sf "$PWD/undo_rename.sh" /usr/local/bin/undo_rename
```

### Execute Undo Script

```bash
undo_rename
```

## Organize Photos

Scans all files recursively in a target directory and moves them into `YYYY-MM` month folders based on the date found at the start of each filename (e.g. `2024-05-19 16.33.26.jpg` or `2024-05-19_kyoto_ricoh-gr-ii_01.jpg`).

- Files already inside a trip folder (`YYYY-MM/YYYY-MM-DD_<name>/`) are never moved.
- Files in old `YYYY-MM/YYYY-MM-DD` day folders are moved up into their month folder. The day folder's `rename_log.txt` is appended to the month folder's log, so `undo_rename` still works there, and the empty day folder is removed.
- With `--trip=NAME`, only files not yet in a month folder are moved, all into one folder named after the earliest date among them (e.g. `2026-11/2026-11-14_japan`).

### Make Organize Photos Script Executable

```bash
chmod +x organize_photos.sh
```

### Link Organize Photos Script into User Local Bin

```bash
sudo ln -sf "$PWD/organize_photos.sh" /usr/local/bin/organize_photos
```

### Execute Organize Photos Script

```bash
organize_photos /path/to/Camera\ Uploads
```

Use `--dry-run` to preview what would happen without moving any files:

```bash
organize_photos --dry-run /path/to/Camera\ Uploads
```

Put a batch of new photos into a trip folder:

```bash
organize_photos --trip=japan /path/to/Camera\ Uploads
```
