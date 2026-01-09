# α Import Utility

<img src="https://github.com/user-attachments/assets/4627d06a-d488-4550-9e9f-b64424cd4b5c" alt="Main screen of α Import Utility. A dark-themed UI with Sony α's signature orange accent color, showing three import modes." width="600"><br>

> [!TIP]  
> **🌐 日本語版はこちら: [Readme.md](Readme.md)**

**A desktop application for safely importing un-imported photos and videos from Sony α cameras or their SD cards to your PC. Verified with the α6700.**

> [!IMPORTANT]  
> **This app is designed to create a complete backup of all photos taken with your camera, without missing a single shot.**
> Organization and editing can be done in photo management software. This app is specialized for "reliably saving all data captured by your camera to your PC, including blurry shots."
> Ensuring that no photos are unintentionally left behind is the most critical design goal.

> [!WARNING]  
> **This is not an official Sony application; it is unofficial software developed by an individual.**
> While it has been designed with great care, **please use it at your own risk.**

> [!WARNING]  
> **Testing has only been performed on the Sony α6700.**
> It is likely to work with cameras from the same generation (those that record XAVC S format videos), but older cameras that only support AVCHD format may not work properly.
> If you have tested it with other models, please report your findings in an Issue.

## Background

I have long used the Canon EOS Kiss X7.
Canon has an official desktop application called [EOS Utility 2](https://canon.jp/support/software/os/select/dc/euw21420a-updater), and although updates have been discontinued for some time, it was the perfect software for my needs.

While EOS Utility 2 offers features beyond photo and video import, such as remote shooting, I primarily used it solely for importing photos and videos.
**Simply connecting an EOS camera via USB cable would automatically detect and import "only the photos and videos that haven't been imported yet," organizing them into folders by shooting date with the folder name format of my choice.**
Furthermore, it would save files with the creation date restored to the shooting date. **Files that have already been imported are never duplicated.**

When I switched from my 8-year-old EOS Kiss X7 to the Sony α6700 in August 2025, **I immediately realized that "Sony cameras don't have a PC-oriented app specialized for photo/video import like EOS Utility 2."**

Sony seems to be focusing on photo transfer via smartphone apps ([Creators' App](https://creatorscloud.sony.net/catalog/en-us/creatorsapp/index.html)), and **[PlayMemories Home](https://support.d-imaging.sony.co.jp/www/disoft/int/download/playmemories-home/win/en/), which once existed, has had no maintenance since 2020.**
The macOS version has already been discontinued, and the Windows version does not support video import for the latest camera models.
Also, on a minor note, folder names could only use YYYY-mm-dd format, with no option for snake_case like YYYY_mm_dd.

My workflow is to treat the camera's SD card as temporary storage, import all captured data to a PC's HDD, back up to a NAS, and additionally back up photos to Amazon Photos.
While many people these days complete their workflows on smartphones alone, my use case requires importing all photos and videos to a PC.

## Motivation

**This app was developed to provide an experience equal to or better than EOS Utility 2's photo/video import for Sony α cameras.**
The design prioritizes perfectly meeting my personal use cases:

### What I Wanted to Achieve

- **Reliably import only un-imported photos and videos.**
  Once photos and videos have been imported, duplicate file copies will never occur. Conversely, if a file that should have been imported is missing, it will be automatically re-imported as a fail-safe.
- **Organizing by shooting date into folders is the default.**
  You can choose between snake_case like `2025_12_01` and hyphen-case like `2025-12-01`.
- **Both creation and modification dates can be restored to the shooting date.**
  Even if the file's creation/modification dates are incorrect due to backup restoration, the correct date from EXIF shooting data will be set as the file's creation and modification dates.
- **Works on both Windows and macOS.**
  Supports use cases like "my main import destination is a Windows PC, but I also want to import from a MacBook I take on trips."

### Importing from Multiple PCs

I keep my photos on a Windows PC at home, but I always take a MacBook when traveling, and sometimes want to import from the MacBook too.
And since there's always a risk of dropping the camera or damaging the SD card while traveling, I want to import photos and videos as frequently as possible.

**If you set up [Tailscale](https://tailscale.com/) on both your home Windows PC and MacBook beforehand, you can mount a network drive from the Windows PC or a Synology NAS folder on your MacBook.**
This allows you to save photos taken during your trip directly to your home PC's HDD from anywhere (securely, without port forwarding).

In this case, if the import history isn't shared between the Windows PC and MacBook, duplicate imports would occur when importing from the Windows PC after returning home.
This wastes bandwidth and could potentially cause file corruption through overwrites, which I wanted to avoid.

**α Import Utility stores import history on the SD card itself. Therefore, regardless of which PC you import from, it can correctly determine whether files have already been imported.**
**Even when switching PCs or importing from a different PC, the import history is preserved as long as you have the SD card.**
Photos and videos that have already been imported to the destination folder are automatically skipped, and conversely, photos and videos that should have been imported but are missing are re-imported.

### Importing from SD Card Backups

You might backup the entire SD card contents to an external SSD or USB drive when running out of space while traveling.
Even when importing from such backups, **portions that duplicate files already imported to the PC are appropriately skipped.**
This is an important feature for preventing duplicate imports.

## Design Philosophy

**α Import Utility is designed with the highest priority on "erring on the side of safety."**
As software that handles precious photos I've personally taken over more than 10 years (tens of thousands of photos, several TB in scale), the following principles are strictly adhered to:

### Absolute Rules

- **Source files are never deleted.**
  Files on the SD card are never modified.
- **Destination files are never overwritten.**
  If a file with the same name exists, it is saved with a different name like `DSC00001 (1).ARW`.
- **Users are never asked to make irreversible decisions.**
  Dialogs like "Overwrite?" are never shown. Both versions of the data are saved.
- **Everything gets imported properly if left alone.**
  No complex settings required. Just connect the device and click once.

### Handling Abnormal Cases

- **If files are accidentally deleted on the PC**
  Even if "imported" is recorded on the SD card, if the file doesn't exist on the PC, it will be re-imported.
- **If SD card metadata is lost**
  While it takes time, hashes are compared to rebuild the metadata. Files that have already been imported will not be duplicated.
- **If power is lost during copy**
  Incomplete files are automatically deleted, preventing corrupted data from remaining in the destination.
- **If files on the PC are corrupted**
  Corruption is detected via lightweight signatures, re-imported under a different name, and the user is alerted.

## Features

### 🛡️ Data Safety First

- Source SD card files and already-imported destination folder files are never touched; **files are never overwritten or deleted.**
- If a file with the same name exists, **it is automatically saved with a different name like `DSC00001 (1).ARW`, and a warning is displayed in the import results.**
- If a copy fails partway through, the incomplete file is automatically deleted, **preventing corrupted files from remaining in the destination.**

### 📷 Reliable Import Management

- Import history is recorded on the SD card, **preventing duplicate imports even when importing from multiple PCs.**
- If files disappear from the destination, they are automatically re-imported, **making recovery from accidental deletion or storage failure easy.**
- Destination file corruption is detected via lightweight signatures, and **automatic re-import is performed when necessary.**
- Works on both Windows and MacBook. Also designed for importing to the same folder via network drive from both Windows and macOS.

### ⚡ One-Click Import

- **Cameras and SD cards are automatically detected when connected, and import can start immediately with a single click.**
- The current file name and overall progress can be **displayed in real-time.**

### 🎨 Optimized for Sony α

- Sony α SD card structure is automatically verified, and **still images, videos, and XML metadata are scanned without missing anything.**
- Shooting dates are read from EXIF, and **creation/modification dates of copied files are accurately restored when necessary.**

## Supported Environments

| OS | Architecture |
|----|--------------|
| Windows 10 / 11 | x64 |
| macOS 12+ | Apple Silicon (arm64) / Intel (x64) |

## Supported File Formats

### Still Images

| Format | Extension | Location |
|--------|-----------|----------|
| JPEG | `.JPG`, `.JPEG` | `DCIM/(100-999)MSDCF/` |
| HEIF | `.HIF`, `.HEIF` | `DCIM/(100-999)MSDCF/` |
| Sony RAW | `.ARW` | `DCIM/(100-999)MSDCF/` |

### Videos

| Format | Extension | Location |
|--------|-----------|----------|
| Main Video | `.MP4` | `PRIVATE/M4ROOT/CLIP/` |
| Video Metadata | `.XML` | `PRIVATE/M4ROOT/CLIP/` |
| Proxy Video | `.MP4` | `PRIVATE/M4ROOT/SUB/` |

> [!NOTE]  
> Video metadata (XML) and proxy video import can be toggled on/off in settings.

## Installation

### Download from GitHub Release (Recommended)

1. Visit the [Releases page](https://github.com/tsukumijima/Alpha-Import-Utility/releases).
2. Download the zip file for your OS from the latest release.
   - Windows: `α Import Utility vX.X.X-windows.zip`
   - macOS: `α Import Utility vX.X.X-macos.zip`
3. Extract the downloaded zip file.

### Launching on Windows

<img src="https://github.com/user-attachments/assets/7d2d368b-c5b0-4c40-ba5c-40e744737802" alt="Folder structure on Windows. Shows α Import Utility.exe." width="600"><br>

1. Move the extracted folder to a location of your choice. We recommend somewhere outside of Program Files, such as `C:\Applications\α Import Utility`.
2. Double-click `α Import Utility.exe` to launch.

### Launching on macOS

<img src="https://github.com/user-attachments/assets/16fc80cc-6e5f-4a37-9c2f-613693674d5a" alt="Folder structure on macOS." width="450"><br>

1. Drag and drop the extracted `α Import Utility.app` to your `Applications` folder.
2. On first launch, you'll need to follow these steps to bypass Gatekeeper's security warning:

> [!WARNING]  
> **macOS 14 Sequoia and later have enhanced security for unsigned apps.**
> You may see messages like "Cannot be opened because the developer cannot be verified" or "Apple cannot check it for malicious software" on first launch.
>
> α Import Utility is safe software. If you trust it, please proceed with the following steps:
>
> 1. Click "Cancel", "OK", or "Done" to close the popup.
> 2. Go to "System Preferences" → "Security & Privacy" → Click "Open Anyway".
>    - "Allow applications downloaded from" must be set to "App Store and identified developers" or "Allow all applications".
>
> **For detailed instructions on macOS 15 Sequoia, please refer to [this article (external link)](https://softantenna.com/blog/how-to-bypass-gatekeeper-on-macos-sequoia/).**

## Usage

### 1. Initial Setup

On first launch, you need to set up the destination folder.
Click the gear icon in the upper right to open the settings screen.

#### Basic Settings

<img src="https://github.com/user-attachments/assets/7365d288-aaab-48ee-98c3-e5e89e253537" width="49%">
<img src="https://github.com/user-attachments/assets/19d4ebc6-e03e-4ef6-8c25-2b4e9d765b06" width="49%"><br>

| Setting | Description |
|---------|-------------|
| **Language** | App display language (Japanese / English) |
| **Destination Folder** | Folder where imported photos and videos are saved |
| **Subfolder Settings** | Folder hierarchy structure by shooting date (Date only / Year/Date / Year/Month/Date) |
| **Date Format** | Date notation format for folder names (4-digit year / 2-digit year, separator) |
| **Import Preview** | Whether to show the list of import targets after scanning |

#### Import Options

<img src="https://github.com/user-attachments/assets/367883c8-1a97-4fad-a7a6-06b1a90c70da" width="49%">
<img src="https://github.com/user-attachments/assets/9f557f1d-7d2b-4dc8-a42b-f66547a7edf2" width="49%"><br>

| Setting | Description | Default |
|---------|-------------|---------|
| **Restore date/time from EXIF** | Match copied file creation/modification dates to shooting date | On |
| **Camera Timezone** | Fallback timezone used when EXIF doesn't contain timezone information | Tokyo |
| **Import video metadata (XML)** | Also import NonRealTimeMeta format XML files | On |
| **Import proxy videos** | Also import low-resolution proxy videos | On |

### 2. Connecting a Device

<img src="https://github.com/user-attachments/assets/26969536-110d-4564-a4db-dc749cab8467" alt="SD card detected and displayed as a device card on the main screen. Shows device name and capacity information." width="600"><br>

When you connect a camera via USB cable or insert an SD card into a card reader, it is automatically detected and displayed on the main screen.

### 3. Starting Import

<img src="https://github.com/user-attachments/assets/96f1597c-4f18-4ea0-9d53-8f207315ed41" width="49%">
<img src="https://github.com/user-attachments/assets/0bcf3d23-f57d-4f50-8621-aeeae63900a6" width="49%"><br>

Click on the detected device's card to start scanning for import targets.

> [!NOTE]
> While we've implemented scanning to be as fast as possible, scanning inevitably takes time since we perform a full scan to ensure reliable import.

---

<img src="https://github.com/user-attachments/assets/3057173f-b93a-4492-b9a8-25c31428c236" width="400"><br>

When "Import Preview" is enabled, a list of import targets is displayed before import.

---

<img src="https://github.com/user-attachments/assets/a940efc6-3bf1-4009-8d14-8dab5ea7c2ae" width="400"><br>

Once scanning is complete, import proceeds in the order: DCIM (photos) → PRIVATE/M4ROOT/CLIP (videos) → PRIVATE/M4ROOT/SUB (proxy videos).

> [!TIP]
> You can cancel anytime during import using the "Cancel" button.  
> When cancelled, the current file copy completes before stopping, so no incomplete files are left behind.

> [!NOTE]
> I actually wanted to implement photo preview during import like EOS Utility, but found that implementing preview would slow down import due to file I/O, so I gave up on that feature...

### 4. Import Complete

<img src="https://github.com/user-attachments/assets/c442e8c2-6bfc-4ab0-93ce-4244527a5cd8" width="49%">
<img src="https://github.com/user-attachments/assets/733f2acd-be5f-4b10-9ce6-d0e63b0f0357" width="49%"><br>

When import is complete, a summary of results is displayed.
Click "Open Destination" to open the destination folder directly.

## Import Methods

### Import from Camera

Connect your camera to the PC via USB cable and have it recognized in USB Mass Storage (MSC) mode.
When the camera is detected, it appears in the "Import from Camera" section.

> [!WARNING]  
> **MTP (Media Transfer Protocol) mode connection is not supported.**
> **Always connect in USB Mass Storage (MSC) mode.**

### Import from SD Card

Connect an SD card to the PC via a card reader.
When the SD card is detected, it appears in the "Import from SD Card" section.

### Import from Folder

Click "Select Folder..." to directly specify a backup folder that maintains the SD card structure.
Of course, it supports folders not only on internal storage but also on USB SSDs or USB drives.
Convenient for re-importing from past SD card backups.

> [!WARNING]  
> **Folders that cannot be recognized as Sony α SD card structure cannot be imported.**
> Make sure to specify the SD card root folder where both `DCIM/` and `PRIVATE/M4ROOT/CLIP/` exist.

## Technical Security

### Import History Management

Imported file information is recorded in `PRIVATE/AIU/METADATA.JSON` on the SD card.
Since this information is stored on the SD card side, **duplicate imports can be prevented even when importing from different PCs.**

```
SD_CARD_ROOT/
├── DCIM/
│   ├── 100MSDCF/       # Still images (JPEG, ARW, HEIF)
│   ├── 101MSDCF/       # Moves to next folder when file count exceeds 9999
│   └── 102MSDCF/       # Same as above
└── PRIVATE/
    ├── M4ROOT/
    │   ├── CLIP/       # Main videos (MP4, XML)
    │   └── SUB/        # Proxy videos
    └── AIU/            # This app's metadata
        └── METADATA.JSON
```

### Import Decision Priority

1. **Recorded in metadata + File exists in destination** → Skip
2. **Recorded in metadata + File not in destination** → Re-import (handling accidental deletion)
3. **Not in metadata + Same-named file exists in destination**
   - Hash matches → Skip
   - Hash differs → Save with different name
4. **Not in metadata + File not in destination** → New import

### File Integrity Verification

- Hashes are calculated using the fast and reliable xxHash64 algorithm.
- Identity is verified via lightweight signatures (file size + hash of head/middle/tail).
- Files with modification dates within 30 seconds of current time are considered being written and skipped.

### Creation/Modification Date Restoration

Sets the creation and modification dates of imported files to match the shooting date recorded in EXIF.
When the source file's creation/modification dates are close to the EXIF shooting date, the original dates are preserved; when significantly different, the EXIF shooting date is used.
For timezone, if timezone information is recorded in EXIF, that information is used; if not, the camera timezone specified in settings is used.

> [!TIP]  
> The α6700 v2.0 has been confirmed to properly record timezone information set on the camera in EXIF based on EXIF v2.3.2 specification.
> This likely applies to same-generation cameras as well.
> Note that older cameras may not have timezone recorded per EXIF specification.

### Fail-Fast Error Handling

In case of the following critical errors, import is immediately aborted and the reason is displayed in a dialog:

- Failed to save metadata
- Cannot write to SD card
- Insufficient space in destination
- File I/O error occurred

## Build Instructions

Build instructions for developers.

### Development Environment

- Flutter 3.x (stable channel)
- Dart 3.10+
- Windows: Visual Studio 2022
- macOS: Xcode 16+

### Build Commands

```bash
# Install dependencies
flutter pub get

# Code generation (.g.dart files)
dart run build_runner build --delete-conflicting-outputs

# Build
flutter build windows --release  # Windows
flutter build macos --release    # macOS
```

### Linter, Formatter & Test Execution

```bash
# Run linter
flutter analyze

# Run formatter
dart format .

# Run unit tests
flutter test

# Run integration tests (real environment only)
flutter test integration_test
```

## License

[MIT License](License.txt)
