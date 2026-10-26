# Red Alert 3: 4K subtitle size patch

[简体中文](README.md) | [English](README.en.md)

Changes the configured font size for in-game dialogue subtitles from 14 to 7 to reduce oversized text and excessive line wrapping at 4K. This patch targets the English version of Command & Conquer: Red Alert 3 1.12 and has been tested at 3840×2160. Subtitles will also become smaller at lower resolutions.

## Build

Requires Windows PowerShell and the RA3 MOD SDK. The SDK's `tools` directory must contain `BinaryAssetBuilder.exe`, `MakeBig.exe`, and their dependencies.

Run the following in Command Prompt, passing the game installation directory and SDK directory:

```bat
build.cmd "X:\Games\Red Alert 3" "X:\Tools\RA3_MODSDK"
```

Build output:

```text
build/
├─ SubtitlePreload_1.0.big
└─ RA3_english_1.12.SkuDef
```

Compiler logs and intermediate files are also saved under `build/`.

## Installation

Exit the game and back up `RA3_english_1.12.SkuDef` in the game installation directory. Then copy the build output:

| File | Destination |
|---|---|
| `SubtitlePreload_1.0.big` | The game's `Data` directory |
| `RA3_english_1.12.SkuDef` | The game installation directory, replacing the existing file |

Launch version 1.12 as usual.

If your existing SkuDef has already been modified for other patches, keep it and insert the following line before the line that loads `Core12.big` instead of replacing the file:

```text
add-big Data\SubtitlePreload_1.0.big
```

The supplied launch configuration is for the English version. For other languages, add the same line to the corresponding 1.12 SkuDef rather than replacing it with the English configuration.

To uninstall, restore the original SkuDef or remove the added line, then delete `Data\SubtitlePreload_1.0.big`.

## Source layout

```text
src/
├─ SageXml/
│  └─ UI/
│     └─ SettingsCommon.xml
└─ RA3_english_1.12.SkuDef
build.cmd
build.ps1
tests.ps1
```

`SettingsCommon.xml` retains the complete SDK file. The only change is the font size in `UISubtitleDisplay`:

```diff
- <Font Name="Lucida Sans" Size="14"/>
+ <Font Name="Lucida Sans" Size="7"/>
```

The SkuDef adds a line to the original 1.12 configuration to load the patch archive.

## Build process

`build.cmd` passes the directory arguments to `build.ps1`, which:

1. Extracts `UISubtitleDisplay` from the XML and compiles it using the SDK.
2. Reads the high-, medium-, and low-detail static streams from `Core12.big`.
3. Replaces the subtitle asset while preserving the other assets and resource references.
4. Calls the SDK's MakeBig tool to create the patch archive and copies the source SkuDef to the output directory.

The script's BIG reader, RefPack decompressor, and data insertion functions handle these resource streams. All build output is written under the project's `build/` directory; game files are read-only inputs.

## Validation and compatibility

Run the build checks:

```powershell
.\tests.ps1 -GameDirectory "X:\Games\Red Alert 3" -SdkDirectory "X:\Tools\RA3_MODSDK"
```

The checks cover the single-field XML change, SDK compilation output, launch configuration, resource file count, and the integrity of the original `Core12.big`.

This patch changes a fixed font-size setting, not the engine's scaling algorithm. Compatibility with other mods, game versions, and multiplayer platforms requires separate testing.
