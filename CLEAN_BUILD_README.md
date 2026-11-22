> **2026-11-12 update:** iOS 26/27 container access now uses the bundled worse_query backend. Read `FILZA_WORSE_QUERY_README.md` for the exact version/build gate and required App Group signing. Earlier kernel-support notes below describe the optional legacy backend.

# FF Cache Manager — Clean Build

This build intentionally removes two features from the IPA:

- Match State (`NOT_START / START / END / UNKNOWN`) — absent from the binary.
- Auto Toggle (open=apply / exit=clean) — absent from the binary.

It keeps the cache profiles (BODY, DRAG, NECK, CHEST, MAGIC) and adds server-delivered
assembly patch support (`P10` / `ASSEMBLY_package.ffasm`) that pushes two game files into
the game's `Documents` folder after full license + integrity verification:

- `Assembly-CSharp-patch.bytes`
- `localConfig.json`

Zero payload files (`GameFiles/` or `OfflineCache/`) are bundled inside the IPA.

## Controls

- `PUSH ASSEMBLY + LOCALCONFIG` — authorizes `P10` (`ASSEMBLY`) on the server
  (`/integrity/challenge` -> `/feature/authorize` -> `/profile/P10` with
  `X-Payload-Wrap: FFC1`), decrypts the package using live in-memory Mach-O section
  hashes, and writes both files into the selected game's `Documents` folder.
  Existing files are backed up once as `<name>.ffbackup` before being replaced.
- `REMOVE ASSEMBLY FILES` — restores `Documents` files from the `.ffbackup`
  copies when present, otherwise removes the two files.

The game can delete these files after loading them; that is normal.

## Build

```powershell
cd "C:\Users\rhoun\Documents\Projet par défaut\ff_panel"
$env:FF_SDK = "C:\Users\rhoun\AppData\Local\Temp\opencode\prj2019_work\toolchain\iPhoneOS14.5.sdk"
powershell -NoProfile -ExecutionPolicy Bypass -File .\build_clean.ps1
```

Outputs:

- `dist/clean/FFCacheManager-5.6.2-4-CLEAN-<hash>.ipa`
- `dist/clean/FFCacheManager-CLEAN.ipa`
