param(
    [string]$FilzaIpa = "",
    [string]$BrandImage = "",
    [string]$ToolsRoot = ""
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $Root "build_access_backend.ps1")
# Keep every path handed to the LLVM tools ASCII-only.  llvm-mingw uses the
# Windows ANSI code page and cannot open the accented workspace path.
$Build = Join-Path $env:TEMP "opencode\ffcache-match-build"
$Dist = Join-Path $Root "dist"
$MatchDist = Join-Path $Dist "match_state"
$IpaBaseName = "FFCacheManager-5.6.2-4-MATCH.ipa"
$Ipa = Join-Path $Build $IpaBaseName
$StableIpaName = "FFCacheManager-v157-MOD-SKINS-Catalog-Signer-Compatible.ipa"
$StableIpa = Join-Path $Dist $StableIpaName
$StableHash = "AEF2C269FB5A96E0FC83AA800B16FA7684F08FF16D7CE03025764DA4DA15BC63"

function Find-MatchingPath {
    param(
        [string]$RootPath,
        [string]$Filter,
        [switch]$Directory
    )
    if (-not $RootPath -or -not (Test-Path -LiteralPath $RootPath)) { return $null }
    if ($Directory) {
        $item = Get-ChildItem -LiteralPath $RootPath -Directory -Filter $Filter -Recurse -Depth 4 -ErrorAction SilentlyContinue | Select-Object -First 1
    } else {
        $item = Get-ChildItem -LiteralPath $RootPath -File -Filter $Filter -Recurse -Depth 4 -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    if ($item) { return $item.FullName }
    return $null
}

function Find-FirstFile {
    param([string[]]$Candidates)
    foreach ($candidate in $Candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) { return $candidate }
    }
    return $null
}

function Assert-StableIpaUnchanged {
    if (-not (Test-Path -LiteralPath $StableIpa -PathType Leaf)) {
        Write-Output "stable IPA not present; nothing to protect in this workspace copy"
        return
    }
    $hash = (Get-FileHash -LiteralPath $StableIpa -Algorithm SHA256).Hash
    if ($hash -ne $StableHash) {
        throw "Stable IPA hash changed before Match State build: $hash"
    }
}

Assert-StableIpaUnchanged

$toolCandidates = New-Object System.Collections.Generic.List[string]
if ($ToolsRoot) { $toolCandidates.Add($ToolsRoot) }
if ($env:FF_TOOLS_ROOT) { $toolCandidates.Add($env:FF_TOOLS_ROOT) }
$toolCandidates.Add((Join-Path $Root ".tools"))
$toolCandidates.Add("C:\Users\rhoun\AppData\Local\Temp\opencode\tools")
$toolCandidates.Add("C:\Users\fakherddin\Downloads\__pycache__\@FAKHER\@FAKHER\.tools")

$Clang = $env:FF_CLANG
$Sdk = $env:FF_SDK
foreach ($candidate in $toolCandidates) {
    if (-not $Clang) { $Clang = Find-MatchingPath -RootPath $candidate -Filter "clang.exe" }
    if (-not $Sdk) { $Sdk = Find-MatchingPath -RootPath $candidate -Filter "iPhoneOS14.5.sdk" -Directory }
    if ($Clang -and $Sdk) { $ToolsRoot = $candidate; break }
}
if (-not $Clang) { throw "iOS clang.exe was not found. Set FF_CLANG or FF_TOOLS_ROOT." }
if (-not $Sdk) {
    foreach ($candidate in @(
        (Join-Path $Root ".tools\iPhoneOS14.5.sdk"),
        "C:\Users\rhoun\AppData\Local\Temp\opencode\tools\iPhoneOS14.5.sdk",
        "C:\Users\fakherddin\theos\sdks\iPhoneOS14.5.sdk",
        $(if ($env:THEOS) { Join-Path $env:THEOS "sdks\iPhoneOS14.5.sdk" } else { $null })
    )) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Container)) { $Sdk = $candidate; break }
    }
}
if (-not $Sdk) { throw "iPhoneOS14.5.sdk was not found. Set FF_SDK or FF_TOOLS_ROOT." }

$ToolBin = Split-Path -Parent $Clang
$Linker = Find-FirstFile @((Join-Path $ToolBin "ld64.lld.exe"))
if (-not $Linker) {
    $elfLinker = Find-FirstFile @(
        (Join-Path $ToolBin "ld.lld.exe"),
        (Find-MatchingPath -RootPath $ToolsRoot -Filter "ld.lld.exe")
    )
    if ($elfLinker) {
        $Linker = Join-Path $ToolBin "ld64.lld.exe"
        Copy-Item -LiteralPath $elfLinker -Destination $Linker -Force
    }
}
if (-not $Linker) { throw "ld64.lld.exe was not found next to clang and no ld.lld.exe fallback exists." }

$Strip = Find-FirstFile @(
    (Join-Path $ToolBin "llvm-strip.exe"),
    (Find-MatchingPath -RootPath $ToolsRoot -Filter "llvm-strip.exe")
)
if (-not $Strip) { throw "llvm-strip.exe was not found." }

$Python = $env:FF_PYTHON
if (-not $Python) {
    $pythonCommand = Get-Command python.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pythonCommand) { $Python = $pythonCommand.Source }
}
if (-not $Python) { $Python = "C:\Users\rhoun\AppData\Local\Programs\Python\Python312\python.exe" }
if (-not (Test-Path -LiteralPath $Python -PathType Leaf)) { throw "Python was not found. Set FF_PYTHON." }

& $Python -c "import PIL, lief" 2>$null
if ($LASTEXITCODE -ne 0) {
    throw "Python needs Pillow and lief. Run: `"$Python`" -m pip install pillow lief"
}

if (-not $FilzaIpa) {
    $FilzaIpa = Find-FirstFile @(
        (Join-Path $Root "donors\FilzaSlop_1.0.3.ipa"),
        (Join-Path $env:TEMP "opencode\tools\FilzaSlop_1.0.3.ipa"),
        "C:\Users\rhoun\AppData\Local\Temp\opencode\tools\FilzaSlop_1.0.3.ipa"
    )
}
if (-not $FilzaIpa) { throw "FilzaSlop 1.0.3 donor IPA was not found. Pass -FilzaIpa." }

if (-not $BrandImage) {
    $BrandImage = Find-FirstFile @(
        (Join-Path $Root "resources\brand.png"),
        "C:\fakher_w\p8v2\FF_CACHE_P8_FINAL_BUILD_PROJECT_V2\assets\brand.png"
    )
}
if (-not $BrandImage) { throw "Brand image was not found. Pass -BrandImage." }

Write-Output "Match State build"
Write-Output "clang:  $Clang"
Write-Output "linker: $Linker"
Write-Output "sdk:    $Sdk"
Write-Output "python: $Python"
Write-Output "donor:  $FilzaIpa"
Write-Output "brand:  $BrandImage"

if (Test-Path -LiteralPath $Build) { Remove-Item -LiteralPath $Build -Recurse -Force }
New-Item -ItemType Directory -Path $Build -Force | Out-Null
New-Item -ItemType Directory -Path $MatchDist -Force | Out-Null

$Payload = Join-Path $Build "Payload"
$App = Join-Path $Payload "FFCacheManager.app"
$Frameworks = Join-Path $App "Frameworks"
$FrameworkBundle = Join-Path $Frameworks "CoreTelemetry.framework"
$Executable = Join-Path $App "FFCacheManager"
$SandboxBridge = Join-Path $Build "FilzaApplySandboxExt.dylib"
$NamedBridge = Join-Path $Build "FilzaApplySandboxExt.named.dylib"
$ProtectedBridge = Join-Path $FrameworkBundle "CoreTelemetry"
$ProtectionMetadata = Join-Path $Build "protected-core.json"
$ProtectedConfig = Join-Path $Build "ProtectedConfig.h"
$Object = Join-Path $Build "main.o"
$SourceFile = Join-Path $Build "main.m"
New-Item -ItemType Directory -Path $FrameworkBundle -Force | Out-Null

& $Python (Join-Path $Root "extract_bridge.py") $FilzaIpa $SandboxBridge
if ($LASTEXITCODE -ne 0) { throw "Donor bridge extraction failed ($LASTEXITCODE)" }

& $Strip --strip-debug $SandboxBridge
if ($LASTEXITCODE -ne 0) { throw "Debug-symbol stripping failed ($LASTEXITCODE)" }

& $Python (Join-Path $Root "set_install_name.py") $SandboxBridge $NamedBridge "@rpath/CoreTelemetry.framework/CoreTelemetry"
if ($LASTEXITCODE -ne 0) { throw "Bridge install-name rewrite failed ($LASTEXITCODE)" }

& $Python (Join-Path $Root "protect_bridge.py") $NamedBridge $ProtectedBridge $ProtectionMetadata
if ($LASTEXITCODE -ne 0) { throw "Bridge export protection failed ($LASTEXITCODE)" }

$metadata = Get-Content -LiteralPath $ProtectionMetadata -Raw | ConvertFrom-Json
if ($metadata.slices.Count -ne 2) { throw "Expected two protected core integrity records" }
$config = @"
#define FFCORE_TEXT_SHA256_A @"$($metadata.slices[0].text_sha256)"
#define FFCORE_EXPORT_SHA256_A @"$($metadata.slices[0].export_sha256)"
#define FFCORE_SECTION_SHA256_A @"$($metadata.slices[0].section_sha256)"
#define FFCORE_TEXT_SHA256_B @"$($metadata.slices[1].text_sha256)"
#define FFCORE_EXPORT_SHA256_B @"$($metadata.slices[1].export_sha256)"
#define FFCORE_SECTION_SHA256_B @"$($metadata.slices[1].section_sha256)"
"@
[System.IO.File]::WriteAllText($ProtectedConfig, $config, [System.Text.UTF8Encoding]::new($false))

$Sources = @(
    "main.m",
    "FFMatchStateManager.h",
    "FFMatchStateManager.m",
    "FFMatchStateViewController.h",
    "FFMatchStateViewController.m"
)
foreach ($name in $Sources) {
    Copy-Item -LiteralPath (Join-Path $Root $name) -Destination $Build -Force
}
Copy-FFAccessSources -Root $Root -Build $Build

$ClangArgs = @(
    "-arch", "arm64", "-target", "arm64-apple-ios15.0", "-isysroot", $Sdk,
    "-fobjc-arc", "-Os", "-fstack-protector-strong", "-fvisibility=hidden",
    "-fomit-frame-pointer", "-fno-ident",
    "-Werror", "-Wno-deprecated-declarations",
    "-DFF_RELEASE_BUILD=1", "-DFF_REQUIRE_SIGNED_RESPONSES=1", "-DFF_3105_MCM=1",
    "-DFF_MATCH_STATE=1",
    "-I", $Build
)
& $Clang @ClangArgs -c $SourceFile -o $Object
if ($LASTEXITCODE -ne 0) { throw "Match State main compile failed ($LASTEXITCODE)" }

$MatchObjects = @()
foreach ($name in @("FFMatchStateManager.m", "FFMatchStateViewController.m")) {
    $matchObject = Join-Path $Build ($name -replace '\.m$', '.o')
    & $Clang @ClangArgs -c (Join-Path $Build $name) -o $matchObject
    if ($LASTEXITCODE -ne 0) { throw "Match State source compile failed: $name ($LASTEXITCODE)" }
    $MatchObjects += $matchObject
}

$AccessObjects = @(Build-FFAccessObjects -Clang $Clang -Sdk $Sdk -Build $Build)

$LinkObjects = @($Object) + $AccessObjects + $MatchObjects
& $Linker -arch arm64 -platform_version ios 15.0 15.0 -syslibroot $Sdk `
    -e _main -adhoc_codesign -dead_strip @LinkObjects `
    -framework UIKit -framework Foundation -framework CoreGraphics -framework QuartzCore -framework Security `
    -framework UniformTypeIdentifiers -framework IOSurface -lobjc -lSystem -o $Executable
if ($LASTEXITCODE -ne 0) { throw "Match State link failed ($LASTEXITCODE)" }

& $Strip -x $Executable
if ($LASTEXITCODE -ne 0) { throw "Application symbol stripping failed ($LASTEXITCODE)" }

& $Python (Join-Path $Root "make_match_state_info_plist.py") (Join-Path $Root "Info.plist") (Join-Path $App "Info.plist")
if ($LASTEXITCODE -ne 0) { throw "Match State Info.plist generation failed ($LASTEXITCODE)" }
Copy-Item -LiteralPath (Join-Path $Root "FrameworkInfo.plist") -Destination (Join-Path $FrameworkBundle "Info.plist") -Force

& $Python (Join-Path $Root "generate_app_icons.py") $BrandImage $App
if ($LASTEXITCODE -ne 0) { throw "Application icon generation failed ($LASTEXITCODE)" }

$AutoCacheSource = Join-Path $Root "auto_cache"
if (-not (Test-Path -LiteralPath $AutoCacheSource -PathType Container)) {
    throw "AutoCache source directory is missing: $AutoCacheSource"
}
$AutoCache = Join-Path $App "AutoCache"
New-Item -ItemType Directory -Path $AutoCache -Force | Out-Null
$AutoCacheFiles = @(Get-ChildItem -LiteralPath $AutoCacheSource -File -Filter "*.ffcache")
if ($AutoCacheFiles.Count -eq 0) { throw "AutoCache contains no .ffcache profiles" }
foreach ($item in $AutoCacheFiles) {
    Copy-Item -LiteralPath $item.FullName -Destination (Join-Path $AutoCache $item.Name) -Force
}
Write-Output "[auto] bundled quick-toggle profiles: $($AutoCacheFiles.Name -join ', ')"

& $Python (Join-Path $Root "make_ipa.py") $Build $Ipa
if ($LASTEXITCODE -ne 0) { throw "IPA packaging failed ($LASTEXITCODE)" }

& $Python (Join-Path $Root "verify_match_state_build.py") $Build $IpaBaseName
if ($LASTEXITCODE -ne 0) { throw "Match State security verification failed ($LASTEXITCODE)" }

$MatchManifest = Join-Path $Build "release_manifest.json"
& $Python (Join-Path $Root "generate_release_manifest.py") $Build $MatchManifest
if ($LASTEXITCODE -ne 0) { throw "Match State release manifest generation failed ($LASTEXITCODE)" }

$StableManifest = Join-Path $Dist "release_manifest.json"
$BetaManifest = Join-Path $Dist "beta\release_manifest.json"
$CombinedManifest = Join-Path $Build "release_manifest_releases.json"
$ManifestInputs = @()
if (Test-Path -LiteralPath $StableManifest -PathType Leaf) { $ManifestInputs += $StableManifest }
if (Test-Path -LiteralPath $BetaManifest -PathType Leaf) { $ManifestInputs += $BetaManifest }
if ($ManifestInputs.Count -gt 0) {
    & $Python (Join-Path $Root "combine_release_manifests.py") $CombinedManifest @ManifestInputs $MatchManifest
    if ($LASTEXITCODE -ne 0) { throw "Match State combined manifest generation failed ($LASTEXITCODE)" }
} else {
    Copy-Item -LiteralPath $MatchManifest -Destination $CombinedManifest -Force
}

$hash = (Get-FileHash -LiteralPath $Ipa -Algorithm SHA256).Hash
$shortHash = $hash.Substring(0, 12)
$MatchIpaName = "FFCacheManager-5.6.2-4-MATCH-$shortHash.ipa"
$MatchIpa = Join-Path $MatchDist $MatchIpaName
Copy-Item -LiteralPath $Ipa -Destination $MatchIpa -Force
"$hash *$MatchIpaName" | Set-Content -LiteralPath (Join-Path $MatchDist "$MatchIpaName.sha256") -Encoding Ascii
$AutoIpaName = "FFCacheManager-AUTO-TOGGLE.ipa"
$AutoIpa = Join-Path $MatchDist $AutoIpaName
Copy-Item -LiteralPath $MatchIpa -Destination $AutoIpa -Force
"$hash *$AutoIpaName" | Set-Content -LiteralPath (Join-Path $MatchDist "$AutoIpaName.sha256") -Encoding Ascii
Copy-Item -LiteralPath $MatchManifest -Destination (Join-Path $MatchDist "release_manifest.json") -Force
Copy-Item -LiteralPath $CombinedManifest -Destination (Join-Path $MatchDist "release_manifest_releases.json") -Force

$info = @"
MATCH STATE BUILD
Date: $(Get-Date -Format o)
Version: 5.6.2
Build: 4
Bundle ID: com.apple.mobile.MobileHouseArrest
Display name: FF Cache Manager MATCH
IPA: $MatchIpaName
SHA-256: $hash
Stable IPA: $StableIpaName
Stable SHA-256: $StableHash
Mode: App-local Match State (NOT_START / START / END / UNKNOWN) with manual/authorized events only
Automatic detection: NOT VERIFIED (no network heuristic enabled)
Auto toggle: OPEN=APPLY / EXIT=CLEAN (bundled BODY, CHEST, MAGIC, NECK)
"@
[System.IO.File]::WriteAllText((Join-Path $MatchDist "MATCH_STATE_BUILD.txt"), $info, [System.Text.UTF8Encoding]::new($false))

Assert-StableIpaUnchanged

Write-Output ""
Write-Output "MATCH STATE BUILD PASS"
Write-Output "IPA: $(Join-Path $MatchDist $MatchIpaName)"
Write-Output "SHA256: $hash"
Write-Output "MATCH MANIFEST: $(Join-Path $MatchDist 'release_manifest.json')"
Write-Output "COMBINED MANIFEST: $(Join-Path $MatchDist 'release_manifest_releases.json')"
Write-Output "STABLE IPA: unchanged ($StableHash)"
