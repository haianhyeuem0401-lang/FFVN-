# Shared by every build entry point. worse_query is bundled as source and never
# depends on the donor IPA exporting any new symbols.
function Copy-FFAccessSources {
    param([string]$Root, [string]$Build)
    foreach ($name in @("FFKernelExploit.h", "FFKernelExploit.m", "FFWorseQuery.h", "FFWorseQuery.m", "FFWorseQueryPolicy.h")) {
        Copy-Item -LiteralPath (Join-Path $Root $name) -Destination $Build -Force
    }
    Copy-Item -LiteralPath (Join-Path $Root "vendor") -Destination $Build -Recurse -Force
    if (Test-Path -LiteralPath (Join-Path $Root "kexploit") -PathType Container) {
        Copy-Item -LiteralPath (Join-Path $Root "kexploit") -Destination $Build -Recurse -Force
    }
}

function Build-FFAccessObjects {
    param([string]$Clang, [string]$Sdk, [string]$Build)
    $LegacySources = @("offsets.m", "krw.m", "kutils.m", "vnode.m", "sandbox_escape.m", "kexploit_opa334.m")
    $LegacyEnabled = $true
    foreach ($name in ($LegacySources + @("kexploit_opa334.h", "kutils.h", "sandbox_escape.h"))) {
        if (-not (Test-Path -LiteralPath (Join-Path $Build "kexploit\$name") -PathType Leaf)) {
            $LegacyEnabled = $false
        }
    }
    $ArgsForAccess = @(
        "-arch", "arm64", "-target", "arm64-apple-ios15.0", "-isysroot", $Sdk,
        "-fobjc-arc", "-Os", "-fblocks", "-fvisibility=hidden",
        "-Wno-deprecated-declarations", "-Wno-incompatible-pointer-types-discards-qualifiers",
        "-Wno-unused-function", "-Wno-unused-variable", "-Wno-unused-parameter",
        "-DFF_3105_MCM=1", "-I", $Build, "-I", (Join-Path $Build "kexploit")
    )
    if ($LegacyEnabled) {
        $ArgsForAccess += "-DFF_LEGACY_KERNEL_ENABLED=1"
    } else {
        Write-Host "Legacy kernel sources absent: building worse_query with existing direct/MCM fallbacks."
    }
    $AccessSources = @("FFKernelExploit.m", "FFWorseQuery.m", "vendor\worse_query\worse_query.m")
    if ($LegacyEnabled) {
        foreach ($name in $LegacySources) { $AccessSources += "kexploit\$name" }
    }
    $ObjectDir = Join-Path $Build "access-obj"
    New-Item -ItemType Directory -Path $ObjectDir -Force | Out-Null
    $Objects = @()
    foreach ($relative in $AccessSources) {
        $ObjectName = [System.IO.Path]::GetFileNameWithoutExtension($relative) + ".o"
        $AccessObject = Join-Path $ObjectDir $ObjectName
        & $Clang @ArgsForAccess -c (Join-Path $Build $relative) -o $AccessObject
        if ($LASTEXITCODE -ne 0) { throw "Access backend compile failed: $relative ($LASTEXITCODE)" }
        $Objects += $AccessObject
    }
    return $Objects
}
