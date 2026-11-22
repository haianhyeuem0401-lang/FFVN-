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
$Build = Join-Path $env:TEMP "opencode\ffcache-clean-build"
$Dist = Join-Path $Root "dist"
$CleanDist = Join-Path $Dist "clean"
$IpaBaseName = "FFCacheManager-5.6.2-4-CLEAN.ipa"
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
        throw "Stable IPA hash changed before clean build: $hash"
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

Write-Output "Clean build (no MATCH state, no auto toggle)"
Write-Output "clang:  $Clang"
Write-Output "linker: $Linker"
Write-Output "sdk:    $Sdk"
Write-Output "python: $Python"
Write-Output "donor:  $FilzaIpa"
Write-Output "brand:  $BrandImage"

if (Test-Path -LiteralPath $Build) { Remove-Item -LiteralPath $Build -Recurse -Force }
New-Item -ItemType Directory -Path $Build -Force | Out-Null
New-Item -ItemType Directory -Path $CleanDist -Force | Out-Null

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

& $Python (Join-Path $Root "generate_app_icons.py") $BrandImage $App
if ($LASTEXITCODE -ne 0) { throw "Application icon generation failed ($LASTEXITCODE)" }

$IconDigest = & $Python -c "import hashlib, sys; from pathlib import Path; app=Path(sys.argv[1]); names=['AppIcon60x60@2x.png','AppIcon60x60@3x.png','AppIcon76x76.png','AppIcon76x76@2x.png','AppIcon83.5x83.5@2x.png','AppIcon1024.png']; parts=[hashlib.sha256((app/n).read_bytes()).hexdigest() for n in names]; print(hashlib.sha256('|'.join(parts).encode()).hexdigest())" $App
if ($LASTEXITCODE -ne 0 -or -not $IconDigest) { throw "Icon bundle digest calculation failed" }
$IconDigest = $IconDigest.Trim()

$metadata = Get-Content -LiteralPath $ProtectionMetadata -Raw | ConvertFrom-Json
if ($metadata.slices.Count -ne 2) { throw "Expected two protected core integrity records" }
$config = @"
#define FFCORE_TEXT_SHA256_A @"$($metadata.slices[0].text_sha256)"
#define FFCORE_EXPORT_SHA256_A @"$($metadata.slices[0].export_sha256)"
#define FFCORE_SECTION_SHA256_A @"$($metadata.slices[0].section_sha256)"
#define FFCORE_TEXT_SHA256_B @"$($metadata.slices[1].text_sha256)"
#define FFCORE_EXPORT_SHA256_B @"$($metadata.slices[1].export_sha256)"
#define FFCORE_SECTION_SHA256_B @"$($metadata.slices[1].section_sha256)"
#define FFICON_BUNDLE_SHA256 @"$IconDigest"
"@
[System.IO.File]::WriteAllText($ProtectedConfig, $config, [System.Text.UTF8Encoding]::new($false))

$Sources = @(
    "main.m"
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
    "-I", $Build
)
& $Clang @ClangArgs -c $SourceFile -o $Object
if ($LASTEXITCODE -ne 0) { throw "Clean main compile failed ($LASTEXITCODE)" }

$AccessObjects = @(Build-FFAccessObjects -Clang $Clang -Sdk $Sdk -Build $Build)

$LinkObjects = @($Object) + $AccessObjects
& $Linker -arch arm64 -platform_version ios 15.0 15.0 -syslibroot $Sdk `
    -e _main -adhoc_codesign -dead_strip @LinkObjects `
    -framework UIKit -framework Foundation -framework CoreGraphics -framework QuartzCore -framework Security `
    -framework UniformTypeIdentifiers -framework IOSurface -lobjc -lSystem -o $Executable
if ($LASTEXITCODE -ne 0) { throw "Clean link failed ($LASTEXITCODE)" }

& $Strip -x $Executable
if ($LASTEXITCODE -ne 0) { throw "Application symbol stripping failed ($LASTEXITCODE)" }

& $Python (Join-Path $Root "make_clean_info_plist.py") (Join-Path $Root "Info.plist") (Join-Path $App "Info.plist")
if ($LASTEXITCODE -ne 0) { throw "Clean Info.plist generation failed ($LASTEXITCODE)" }
Copy-Item -LiteralPath (Join-Path $Root "FrameworkInfo.plist") -Destination (Join-Path $FrameworkBundle "Info.plist") -Force

$AssemblyServerPackage = Join-Path $Root "server_payloads\ASSEMBLY_package.ffasm"
& $Python (Join-Path $Root "build_assembly_package.py") (Join-Path $Root "game_files") $AssemblyServerPackage
if ($LASTEXITCODE -ne 0) { throw "Server assembly package generation failed ($LASTEXITCODE)" }
Write-Output "[server-only] built server assembly package (0 game files bundled in IPA): $AssemblyServerPackage"

& $Python (Join-Path $Root "make_ipa.py") $Build $Ipa
if ($LASTEXITCODE -ne 0) { throw "IPA packaging failed ($LASTEXITCODE)" }

& $Python (Join-Path $Root "verify_clean_build.py") $Build $IpaBaseName
if ($LASTEXITCODE -ne 0) { throw "Clean build security verification failed ($LASTEXITCODE)" }

$CleanManifest = Join-Path $Build "release_manifest.json"
& $Python (Join-Path $Root "generate_release_manifest.py") $Build $CleanManifest
if ($LASTEXITCODE -ne 0) { throw "Clean release manifest generation failed ($LASTEXITCODE)" }

$StableManifest = Join-Path $Dist "release_manifest.json"
$BetaManifest = Join-Path $Dist "beta\release_manifest.json"
$CombinedManifest = Join-Path $Build "release_manifest_releases.json"
$ManifestInputs = @()
if (Test-Path -LiteralPath $StableManifest -PathType Leaf) { $ManifestInputs += $StableManifest }
if (Test-Path -LiteralPath $BetaManifest -PathType Leaf) { $ManifestInputs += $BetaManifest }
if ($ManifestInputs.Count -gt 0) {
    & $Python (Join-Path $Root "combine_release_manifests.py") $CombinedManifest @ManifestInputs $CleanManifest
    if ($LASTEXITCODE -ne 0) { throw "Clean combined manifest generation failed ($LASTEXITCODE)" }
} else {
    Copy-Item -LiteralPath $CleanManifest -Destination $CombinedManifest -Force
}

$hash = (Get-FileHash -LiteralPath $Ipa -Algorithm SHA256).Hash
$shortHash = $hash.Substring(0, 12)
$CleanIpaName = "FFCacheManager-5.6.2-4-CLEAN-$shortHash.ipa"
$CleanIpa = Join-Path $CleanDist $CleanIpaName
Copy-Item -LiteralPath $Ipa -Destination $CleanIpa -Force
"$hash *$CleanIpaName" | Set-Content -LiteralPath (Join-Path $CleanDist "$CleanIpaName.sha256") -Encoding Ascii
$EasyIpaName = "FFCacheManager-CLEAN.ipa"
$EasyIpa = Join-Path $CleanDist $EasyIpaName
Copy-Item -LiteralPath $CleanIpa -Destination $EasyIpa -Force
"$hash *$EasyIpaName" | Set-Content -LiteralPath (Join-Path $CleanDist "$EasyIpaName.sha256") -Encoding Ascii
Copy-Item -LiteralPath $CleanManifest -Destination (Join-Path $CleanDist "release_manifest.json") -Force
Copy-Item -LiteralPath $CombinedManifest -Destination (Join-Path $CleanDist "release_manifest_releases.json") -Force

$info = @"
CLEAN BUILD
Date: $(Get-Date -Format o)
Version: 5.6.2
Build: 4
Bundle ID: com.apple.mobile.MobileHouseArrest
Display name: FF Cache Manager
IPA: $CleanIpaName
SHA-256: $hash
Stable IPA: $StableIpaName
Stable SHA-256: $StableHash
Match State: ABSENT
Auto toggle: ABSENT
GameFiles: Assembly-CSharp-patch.bytes + localConfig.json -> Documents
"@
[System.IO.File]::WriteAllText((Join-Path $CleanDist "CLEAN_BUILD.txt"), $info, [System.Text.UTF8Encoding]::new($false))

Assert-StableIpaUnchanged

Write-Output ""
Write-Output "CLEAN BUILD PASS"
Write-Output "IPA: $(Join-Path $CleanDist $CleanIpaName)"
Write-Output "EASY NAME: $(Join-Path $CleanDist $EasyIpaName)"
Write-Output "SHA256: $hash"
Write-Output "MANIFEST: $(Join-Path $CleanDist 'release_manifest.json')"
Write-Output "COMBINED MANIFEST: $(Join-Path $CleanDist 'release_manifest_releases.json')"
Write-Output "STABLE IPA: unchanged ($StableHash)"
