param(
    [string]$FilzaIpa = "",
    [string]$BrandImage = "",
    [string]$ToolsRoot = ""
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $Root "build_access_backend.ps1")
# Keep every path handed to the LLVM tools ASCII-only.  The llvm-mingw
# binaries use the Windows ANSI code page and cannot open paths containing
# characters such as the accented "e" in this workspace name.
$Build = Join-Path $env:TEMP "opencode\ffcache-build"
$Dist = Join-Path $Root "dist"
$IpaBaseName = "FFCacheManager-v157-MOD-SKINS-Catalog-Signer-Compatible.ipa"
$Ipa = Join-Path $Build $IpaBaseName

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

Write-Output "clang:  $Clang"
Write-Output "linker: $Linker"
Write-Output "sdk:    $Sdk"
Write-Output "python: $Python"
Write-Output "donor:  $FilzaIpa"
Write-Output "brand:  $BrandImage"

if (Test-Path -LiteralPath $Build) { Remove-Item -LiteralPath $Build -Recurse -Force }
New-Item -ItemType Directory -Path $Build -Force | Out-Null
New-Item -ItemType Directory -Path $Dist -Force | Out-Null

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

Copy-Item -LiteralPath (Join-Path $Root "main.m") -Destination $SourceFile -Force
Copy-FFAccessSources -Root $Root -Build $Build

$ClangArgs = @(
    "-arch", "arm64", "-target", "arm64-apple-ios15.0", "-isysroot", $Sdk,
    "-fobjc-arc", "-Os", "-fstack-protector-strong", "-fvisibility=hidden",
    "-fomit-frame-pointer", "-fno-ident",
    "-Werror", "-Wno-deprecated-declarations",
    "-DFF_RELEASE_BUILD=1", "-DFF_REQUIRE_SIGNED_RESPONSES=1", "-DFF_3105_MCM=1",
    "-I", $Build, "-c", $SourceFile, "-o", $Object
)
& $Clang @ClangArgs
if ($LASTEXITCODE -ne 0) { throw "Compile failed ($LASTEXITCODE)" }

# The access backend sources are compiled from the ASCII-only build directory:
# llvm-mingw cannot open the accented workspace path on this machine.
$AccessObjects = @(Build-FFAccessObjects -Clang $Clang -Sdk $Sdk -Build $Build)

$LinkObjects = @($Object) + $AccessObjects
& $Linker -arch arm64 -platform_version ios 15.0 15.0 -syslibroot $Sdk `
    -e _main -adhoc_codesign -dead_strip @LinkObjects `
    -framework UIKit -framework Foundation -framework CoreGraphics -framework QuartzCore -framework Security `
    -framework UniformTypeIdentifiers -framework IOSurface -lobjc -lSystem -o $Executable
if ($LASTEXITCODE -ne 0) { throw "Link failed ($LASTEXITCODE)" }

& $Strip -x $Executable
if ($LASTEXITCODE -ne 0) { throw "Application symbol stripping failed ($LASTEXITCODE)" }

Copy-Item -LiteralPath (Join-Path $Root "Info.plist") -Destination (Join-Path $App "Info.plist") -Force
Copy-Item -LiteralPath (Join-Path $Root "FrameworkInfo.plist") -Destination (Join-Path $FrameworkBundle "Info.plist") -Force

& $Python (Join-Path $Root "generate_app_icons.py") $BrandImage $App
if ($LASTEXITCODE -ne 0) { throw "Application icon generation failed ($LASTEXITCODE)" }

& $Python (Join-Path $Root "make_ipa.py") $Build $Ipa
if ($LASTEXITCODE -ne 0) { throw "IPA packaging failed ($LASTEXITCODE)" }

& $Python (Join-Path $Root "verify_build.py") $Build
if ($LASTEXITCODE -ne 0) { throw "Security verification failed ($LASTEXITCODE)" }

$Manifest = Join-Path $Build "release_manifest.json"
& $Python (Join-Path $Root "generate_release_manifest.py") $Build $Manifest
if ($LASTEXITCODE -ne 0) { throw "Release manifest generation failed ($LASTEXITCODE)" }

$ManifestReleases = Join-Path $Build "release_manifest_releases.json"
& $Python (Join-Path $Root "combine_release_manifests.py") $ManifestReleases $Manifest $Manifest
if ($LASTEXITCODE -ne 0) { throw "Schema-2 release manifest generation failed ($LASTEXITCODE)" }

Copy-Item -LiteralPath $Ipa -Destination (Join-Path $Dist $IpaBaseName) -Force
Copy-Item -LiteralPath $Manifest -Destination (Join-Path $Dist "release_manifest.json") -Force
Copy-Item -LiteralPath $ManifestReleases -Destination (Join-Path $Dist "release_manifest_releases.json") -Force
$ServerPayload = Join-Path $Root "server_payloads\P8_FREE_FIRE_TH.ffesp"
if (Test-Path -LiteralPath $ServerPayload -PathType Leaf) {
    Copy-Item -LiteralPath $ServerPayload -Destination (Join-Path $Dist "P8_FREE_FIRE_TH.ffesp") -Force
}
$hash = (Get-FileHash -LiteralPath $Ipa -Algorithm SHA256).Hash
"$hash *$IpaBaseName" | Set-Content -LiteralPath (Join-Path $Dist "$IpaBaseName.sha256") -Encoding Ascii

Write-Output ""
Write-Output "BUILD PASS"
Write-Output "IPA: $(Join-Path $Dist $IpaBaseName)"
Write-Output "SHA256: $hash"
Write-Output "MANIFEST: $(Join-Path $Dist 'release_manifest.json')"
Write-Output "MANIFEST SCHEMA 2: $(Join-Path $Dist 'release_manifest_releases.json')"
Write-Output "SERVER ESP PAYLOAD: $(Join-Path $Dist 'P8_FREE_FIRE_TH.ffesp')"
