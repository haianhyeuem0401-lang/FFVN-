import hashlib
import json
import plistlib
import sys
import zipfile
from pathlib import Path

import lief


EXPECTED_EXPORTS = {
    "_FKX0A7Q2M9Z",
    "_FKX1R4V8N6P",
    "_FKX2C5J9T3W",
    "_FKX3D8H4K7R",
}

ICON_FILES = {
    "AppIcon60x60@2x.png": (120, 120),
    "AppIcon60x60@3x.png": (180, 180),
    "AppIcon76x76.png": (76, 76),
    "AppIcon76x76@2x.png": (152, 152),
    "AppIcon83.5x83.5@2x.png": (167, 167),
    "AppIcon1024.png": (1024, 1024),
}
FORBIDDEN_SECRET_MARKERS = (
    b"FFCACHE_SECRET=", b"FF_SSH_PASSWORD=", b"BEGIN PRIVATE KEY",
    b"DATABASE_URL=", b"ADMIN_TOKEN=", b"SIGNING_PRIVATE_KEY=",
)

FORBIDDEN_RELEASE_DIAGNOSTICS = (
    b"[ApplyManager]", b"[Compatibility]", b"Presenting AuthorizedFolderAccess picker",
    b"__PASTE_SIGNING_PUBLIC_KEY_HERE__", b"Suppressed integrity alert",
    b"Suppressed activation nag", b"hooks installed", b"research build",
    b"research source repository", b"[MCMFilza]", b"[WallpaperLab]", b"[Tweak]",
)

OLD_EXPORTS = {
    "_MCMFilzaStart",
    "_MCMFilzaDataContainerPath",
    "_MCMFilzaSetUnrestrictedFilesystem",
}

SENSITIVE_EXPORT_MARKERS = tuple(name.encode("ascii") for name in OLD_EXPORTS)


def sha256(values):
    return hashlib.sha256(bytes(values)).hexdigest()


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: verify_build.py BUILD_DIRECTORY")
    build = Path(sys.argv[1])
    app = build / "Payload" / "FFCacheManager.app"
    core = app / "Frameworks" / "CoreTelemetry.framework" / "CoreTelemetry"
    ipa = build / "FFCacheManager-v157-MOD-SKINS-Catalog-Signer-Compatible.ipa"

    expected_files = {
        "Payload/FFCacheManager.app/FFCacheManager",
        "Payload/FFCacheManager.app/Info.plist",
        "Payload/FFCacheManager.app/Frameworks/CoreTelemetry.framework/CoreTelemetry",
        "Payload/FFCacheManager.app/Frameworks/CoreTelemetry.framework/Info.plist",
        *(f"Payload/FFCacheManager.app/{name}" for name in ICON_FILES),
    }
    if not zipfile.is_zipfile(ipa):
        raise RuntimeError("IPA is not a ZIP archive")
    with zipfile.ZipFile(ipa) as archive:
        files = {name for name in archive.namelist() if not name.endswith("/")}
    if files != expected_files:
        raise RuntimeError(f"Unexpected IPA files: {sorted(files ^ expected_files)}")

    with (app / "Info.plist").open("rb") as handle:
        app_info = plistlib.load(handle)
    with (core.parent / "Info.plist").open("rb") as handle:
        framework_info = plistlib.load(handle)
    # The 3105 kernel-exploit release line; older 5.5/5.6.x clients are
    # revoked server-side and must not be accepted by the build verifier.
    if app_info.get("CFBundleShortVersionString") != "5.6.2" or app_info.get("CFBundleVersion") != "1":
        raise RuntimeError("Application version metadata is incorrect")
    if app_info.get("MinimumOSVersion") != "15.0":
        raise RuntimeError("Minimum iOS version is incorrect")
    if framework_info.get("CFBundlePackageType") != "FMWK" or framework_info.get("CFBundleExecutable") != "CoreTelemetry":
        raise RuntimeError("Framework metadata is incorrect")

    metadata = json.loads((build / "protected-core.json").read_text(encoding="utf-8"))["slices"]
    fat = lief.MachO.parse(core)
    if fat is None or len(fat) != 2:
        raise RuntimeError("Protected core is not a two-slice Mach-O")
    results = []
    for index, (binary, expected) in enumerate(zip(fat, metadata)):
        names = {symbol.name for symbol in binary.exported_symbols}
        unexpected_cleartext = {name for name in names if name not in EXPECTED_EXPORTS and not name.startswith("_Q")}
        if not EXPECTED_EXPORTS.issubset(names) or names & OLD_EXPORTS or unexpected_cleartext:
            raise RuntimeError(f"Protected exports are incorrect in slice {index}: {sorted(names)}")
        text = binary.get_section("__text")
        exports = binary.dyld_exports_trie
        if text is None or exports is None:
            raise RuntimeError(f"Protected regions missing from slice {index}")
        if sha256(text.content) != expected["text_sha256"] or sha256(exports.content) != expected["export_sha256"]:
            raise RuntimeError(f"Integrity metadata mismatch in slice {index}")
        section_payload = b"".join(bytes(section.content) for section in binary.sections if bytes(section.content))
        if hashlib.sha256(section_payload).hexdigest() != expected["section_sha256"]:
            raise RuntimeError(f"Full section integrity metadata mismatch in slice {index}")
        results.append({"slice": index})

    application_bytes = (app / "FFCacheManager").read_bytes()
    if b"CoreTelemetry.framework" not in application_bytes or b"FFProtectedCore.dylib" in application_bytes:
        raise RuntimeError("Application loader metadata is incorrect")
    # /api/v1 is intentionally XOR-obfuscated in the v145 hardening pass; the
    # remaining markers still confirm every critical path stays wired in.
    required_api_markers = (
        b"/license/activate", b"/session/refresh", b"/session/logout",
        b"/session/validate", b"/feature/authorize", b"X-Feature-Token",
        b"session-access-token", b"session-refresh-token", b"/integrity/challenge",
        b"app_text_sha256", b"app_cstring_sha256", b"request_hash", b"framework_plist_sha256",
        b"P1", b"P5", b"P7", b"HOLOGRAM_GUN", b"MOD SKINS", b"/skins/catalog",
        b"/channel/status", b"CHANNEL_VERIFICATION_REQUIRED", b"STFAMILY FF",
        b"bot_username",
        # The 3105 access engine must remain compiled into the release.
        b"3105 MCM", b"libsystem_containermanager", b"container_query_create",
        b"MCMMetadataIdentifier", b"WQ READY TO QUERY", b"com.apple.security.application-groups",
    )
    missing_api_markers = [
        marker for marker in required_api_markers
        if marker not in application_bytes
        and marker.decode("ascii").encode("utf-16-le") not in application_bytes
    ]
    if missing_api_markers:
        raise RuntimeError(f"Versioned session API markers are missing: {missing_api_markers}")
    core_bytes = core.read_bytes()
    leaked_markers = [marker.decode("ascii") for marker in SENSITIVE_EXPORT_MARKERS if marker in core_bytes]
    if leaked_markers:
        raise RuntimeError(f"Original sensitive bridge exports leaked into the release: {leaked_markers}")
    release_bytes = application_bytes + core_bytes
    leaked_secrets = [marker.decode("ascii") for marker in FORBIDDEN_SECRET_MARKERS if marker in release_bytes]
    if leaked_secrets:
        raise RuntimeError(f"Sensitive build material leaked into release binaries: {leaked_secrets}")
    leaked_diagnostics = [marker.decode("ascii") for marker in FORBIDDEN_RELEASE_DIAGNOSTICS if marker in release_bytes]
    if leaked_diagnostics:
        raise RuntimeError(f"Release diagnostics leaked into application binary: {leaked_diagnostics}")
    if (app / "brand-cat.jpg").exists():
        raise RuntimeError("Brand image must be used only as the app icon")
    from PIL import Image
    for name, expected_size in ICON_FILES.items():
        with Image.open(app / name) as icon:
            if icon.format != "PNG" or icon.size != expected_size:
                raise RuntimeError(f"Application icon is invalid: {name}")
    print(json.dumps({
        "status": "PASS",
        "ipa_sha256": hashlib.sha256(ipa.read_bytes()).hexdigest().upper(),
        "ipa_size": ipa.stat().st_size,
        "files": len(expected_files),
        "minimum_ios": app_info["MinimumOSVersion"],
        "architectures": len(fat),
        "slices": results,
    }, indent=2))


if __name__ == "__main__":
    main()
