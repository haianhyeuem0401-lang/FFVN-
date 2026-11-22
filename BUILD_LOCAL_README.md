> **2026-11-12 update:** iOS 26/27 container access now uses the bundled worse_query backend. Read `FILZA_WORSE_QUERY_README.md` for the exact version/build gate and required App Group signing. Earlier kernel-support notes below describe the optional legacy backend.

# Local Windows build

The original `build.ps1` targets the author's machine. `build_local.ps1` is the
self-contained Windows variant used for this workspace.

## Run

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build_local.ps1
```

## Inputs

- iOS clang + `ld64.lld` + `llvm-strip`
- `iPhoneOS14.5.sdk`
- `donors/FilzaSlop_1.0.3.ipa`
- `resources/brand.png`
- Python 3 with `Pillow` and `lief`

The script searches `FF_TOOLS_ROOT`, `.tools`, the local OpenCode tool cache,
and the original author tool path. Individual tools can be overridden with
`FF_CLANG`, `FF_SDK`, and `FF_PYTHON`.

## Outputs (`dist/`)

- `FFCacheManager-v157-MOD-SKINS-Catalog-Signer-Compatible.ipa` (unsigned)
- `*.ipa.sha256`
- `release_manifest.json` (schema 1, single entry)
- `release_manifest_releases.json` (schema 2 allowlist form)
- `P8_FREE_FIRE_TH.ffesp` (ESP P8 V2 server payload)

The IPA is intentionally unsigned. Sign it with the normal iOS signer before
installing. The release manifest is generated from the exact built Mach-O
sections and must be uploaded with the IPA.

The client `Info.plist` carries release metadata version `5.6.2`, build `1`,
minimum iOS `15.0`. `verify_build.py` expects that pair. Server-side
`minimum_app_version` is `5.6.2` and `revoked_app_versions` contains every
older line (`5.5`, `5.6`, `5.6.1`, `5.7`, `6.0`), so only the 5.6.2 build can activate.
The 5.6.2 build bundles the OGIOS kernel exploit chain (`kexploit_opa334` →
`sandbox_escape`) and compiles the 3105 MCM access engine into the online
release. The exploit is gated to iOS/iPadOS 17.0–18.7.x and 26.0.x, matching
the bundled offset table; iOS 16 and 26.1+ keep the non-exploit fallback.
The 5.6.1 UI additions remain: a persistent navigation-bar `📣 CHANNEL`
button plus full-width `📣 JOIN STFAMILY FF CHANNEL` buttons on the access
and control screens. The channel link and verification bot are read only from
the signed server status response; no fallback URL is compiled into the IPA.
