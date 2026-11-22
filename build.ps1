param(
    [string]$FilzaIpa = "D:\FilzaSlop_1.0.3.ipa",
    [switch]$Offline
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $Root "build_access_backend.ps1")
$ToolsRoot = "C:\Users\fakherddin\Downloads\__pycache__\@FAKHER\@FAKHER\.tools"
$MingwBin = Join-Path $ToolsRoot "llvm-mingw\llvm-mingw-20260616-ucrt-x86_64\bin"
$LlvmBin = Join-Path $ToolsRoot "llvm-official\clang+llvm-18.1.8-x86_64-pc-windows-msvc\bin"
$Sdk = "C:\Users\fakherddin\theos\sdks\iPhoneOS14.5.sdk"
$Clang = Join-Path $MingwBin "clang.exe"
$Linker = Join-Path $LlvmBin "ld64.lld.exe"
$Lipo = Join-Path $LlvmBin "llvm-lipo.exe"
$InstallNameTool = Join-Path $LlvmBin "llvm-install-name-tool.exe"
$Strip = Join-Path $LlvmBin "llvm-strip.exe"
$Python = "C:\Users\fakherddin\AppData\Local\Python\bin\python.exe"
$BrandImage = "D:\photo_6048770355163238977_y.jpg"
$Build = Join-Path ([System.IO.Path]::GetTempPath()) ("FFCacheManager-v157-six-skin-catalog-" + [Guid]::NewGuid().ToString("N"))
$Object = Join-Path $Build "main.o"
$SourceFile = Join-Path $Build "main.m"
$Payload = Join-Path $Build "Payload"
$App = Join-Path $Payload "FFCacheManager.app"
$Frameworks = Join-Path $App "Frameworks"
$FrameworkBundle = Join-Path $Frameworks "CoreTelemetry.framework"
$Executable = Join-Path $App "FFCacheManager"
$ProtectedBridge = Join-Path $FrameworkBundle "CoreTelemetry"
$ProtectionMetadata = Join-Path $Build "protected-core.json"
$ProtectedConfig = Join-Path $Build "ProtectedConfig.h"
$FilzaTag = ([System.IO.Path]::GetFileNameWithoutExtension($FilzaIpa)) -replace '[^A-Za-z0-9\.]', ''
$IpaBaseName = if ($Offline) { "FFCacheManager-v157-Offline-3105-Exact-MCM-Logic-Unsigned.ipa" } else { "FFCacheManager-v157-MOD-SKINS-Catalog-Signer-Compatible.ipa" }
$Ipa = Join-Path $Build $IpaBaseName

foreach ($required in @($Clang, $Linker, $Lipo, $InstallNameTool, $Strip, $Python, $Sdk, $FilzaIpa, $BrandImage)) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Missing build dependency: $required" }
}

New-Item -ItemType Directory -Path $FrameworkBundle -Force | Out-Null
$SevenZip = "C:\Program Files\7-Zip\7z.exe"
if (-not (Test-Path -LiteralPath $SevenZip -PathType Leaf)) { throw "Missing 7-Zip: $SevenZip" }
& $SevenZip e -y "-o$Build" $FilzaIpa "Payload/Filza.app/Frameworks/FilzaApplySandboxExt.dylib" | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Could not extract Filza sandbox bridge ($LASTEXITCODE)" }
$SandboxBridge = Join-Path $Build "FilzaApplySandboxExt.dylib"
if (-not (Test-Path -LiteralPath $SandboxBridge -PathType Leaf)) { throw "Sandbox bridge missing after extraction" }

# Remove DWARF/debug symbol tables before the protected export rewrite. This
# does not remove runtime-required exports or Objective-C metadata.
& $Strip --strip-debug $SandboxBridge
if ($LASTEXITCODE -ne 0) { throw "Debug-symbol stripping failed ($LASTEXITCODE)" }

& $InstallNameTool -id "@rpath/CoreTelemetry.framework/CoreTelemetry" $SandboxBridge
if ($LASTEXITCODE -ne 0) { throw "Bridge install-name protection failed ($LASTEXITCODE)" }

& $Python (Join-Path $Root "protect_bridge.py") $SandboxBridge $ProtectedBridge $ProtectionMetadata
if ($LASTEXITCODE -ne 0) { throw "Bridge export protection failed ($LASTEXITCODE)" }
Remove-Item -LiteralPath $SandboxBridge -Force

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

# Compile a temporary copy. Some Windows file-indexing providers can hold the
# workspace source open while clang reads it, which makes the compiler appear
# stalled; the build directory is isolated and avoids that race.
Copy-Item -LiteralPath (Join-Path $Root "main.m") -Destination $SourceFile -Force
Copy-FFAccessSources -Root $Root -Build $Build

$ClangArgs = @(
    "-arch","arm64","-target","arm64-apple-ios15.0","-isysroot",$Sdk,
    "-fobjc-arc","-Os","-fstack-protector-strong","-fvisibility=hidden","-fomit-frame-pointer","-fno-ident",
    "-Werror","-Wno-deprecated-declarations"
)
if ($Offline) { $ClangArgs += "-DFF_OFFLINE_BUILD=1" }
$ClangArgs += "-DFF_3105_MCM=1"
$ClangArgs += "-DFF_RELEASE_BUILD=1"
$ClangArgs += "-DFF_REQUIRE_SIGNED_RESPONSES=1"
$ClangArgs += @("-I",$Build,"-c",$SourceFile,"-o",$Object)
& $Clang @ClangArgs
if ($LASTEXITCODE -ne 0) { throw "Compile failed ($LASTEXITCODE)" }

$AccessObjects = @(Build-FFAccessObjects -Clang $Clang -Sdk $Sdk -Build $Build)
$LinkObjects = @($Object) + $AccessObjects
& $Linker -arch arm64 -platform_version ios 15.0 15.0 -syslibroot $Sdk `
    -e _main -adhoc_codesign -dead_strip @LinkObjects `
    -framework UIKit -framework Foundation -framework CoreGraphics -framework QuartzCore -framework Security `
    -framework UniformTypeIdentifiers -framework IOSurface -lobjc -lSystem -o $Executable
if ($LASTEXITCODE -ne 0) { throw "Link failed ($LASTEXITCODE)" }

# Retain only symbols needed by the dynamic loader.  This removes local
# implementation names; it does not try to conceal app behavior or secrets.
& $Strip -x $Executable
if ($LASTEXITCODE -ne 0) { throw "Application symbol stripping failed ($LASTEXITCODE)" }

$AppInfoPath = Join-Path $App "Info.plist"
Copy-Item -LiteralPath (Join-Path $Root "Info.plist") -Destination $AppInfoPath -Force
if ($Offline) {
    # Keep the online release metadata untouched, but make the direct/offline
# artifact the exact-3105-MCM v157 release (5.7 / build 43).  This build never
    # submits application hashes to the activation service.
    # System.Xml.Save on Windows adds a UTF-8 BOM and an empty DTD subset
    # ("PropertyList-1.0.dtd\"[]>").  Foundation accepts it, but TrollStore
    # and ESign report that Info.plist is missing because their strict parser
    # rejects that byte form.  plistlib writes the canonical Apple XML form.
    & $Python (Join-Path $Root "update_plist_version.py") $AppInfoPath "5.5" "41"
    if ($LASTEXITCODE -ne 0) { throw "Canonical Info.plist generation failed ($LASTEXITCODE)" }
}
Copy-Item -LiteralPath (Join-Path $Root "FrameworkInfo.plist") -Destination (Join-Path $FrameworkBundle "Info.plist") -Force
& $Python (Join-Path $Root "generate_app_icons.py") $BrandImage $App
if ($LASTEXITCODE -ne 0) { throw "Application icon generation failed ($LASTEXITCODE)" }

if ($Offline) {
    $OfflineSource = "C:\Users\fakherddin\Desktop\cache files drag neck body"
    $CacheBody = Join-Path $OfflineSource "BODY"
    $CacheDrag = Join-Path $OfflineSource "DRAG"
    $CacheNeck = Join-Path $OfflineSource "NECK"
    foreach ($required in @($CacheBody, $CacheDrag, $CacheNeck)) {
        if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Missing offline cache file: $required" }
    }
    $OfflineCache = Join-Path $App "OfflineCache"
    New-Item -ItemType Directory -Path $OfflineCache -Force | Out-Null
    $FeatureToSource = @{ BODY = $CacheBody; DRAG = $CacheDrag; NECK = $CacheNeck }
    foreach ($feature in $FeatureToSource.Keys) {
        Copy-Item -LiteralPath $FeatureToSource[$feature] -Destination (Join-Path $OfflineCache "$feature.ffcache") -Force
    }
    Write-Output "[offline] bundled user profiles: BODY, DRAG, NECK into $OfflineCache"
}

Push-Location $Build
try {
    & $SevenZip a -tzip "-mx=9" $Ipa "Payload" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "IPA packaging failed ($LASTEXITCODE)" }
} finally {
    Pop-Location
}

if (-not $Offline) {
    & $Python (Join-Path $Root "verify_build.py") $Build
    if ($LASTEXITCODE -ne 0) { throw "Security verification failed ($LASTEXITCODE)" }
} else {
    & $Python (Join-Path $Root "verify_offline_build.py") $Build $IpaBaseName
    if ($LASTEXITCODE -ne 0) { throw "Offline build verification failed ($LASTEXITCODE)" }
}

& $Lipo -info $Executable
Write-Output "Built: $Ipa"
