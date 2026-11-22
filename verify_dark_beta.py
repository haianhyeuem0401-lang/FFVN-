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

INJECTION_MARKERS = (
    b"CydiaSubstrate", b"FAKHER_IPAVIEW_TEST", b"MSHookFunction",
    b"il2cpp_", b"FFDark.dylib", b"libsubsystem", b"MIZZE_INJECTED",
    b"com.hoanghadev",
)

OLD_FEATURE_MARKERS = (
    b"BODY", b"DRAG", b"NECK", b"CHEST", b"MAGIC",
    b"MOD SKINS", b"HOLOGRAM_GUN", b"3105 MCM",
)

DARK_MARKERS = (
    b"FFDarkViewController", b"FFDarkPreviewView", b"FFDarkConfig.v1",
    b"M BOARD", b"IN-GAME READY", b"DARK IN-GAME PREVIEW", b"AIM BOT",
    b"APPLY & SHOW GLOWING BUTTON", b"GLOWING AIM BUTTON", b"DARK companion",
)

OLD_EXPORTS = {
    "_MCMFilzaStart",
    "_MCMFilzaDataContainerPath",
    "_MCMFilzaSetUnrestrictedFilesystem",
}

SENSITIVE_EXPORT_MARKERS = tuple(name.encode("ascii") for name in OLD_EXPORTS)


def sha256(values):
    return hashlib.sha256(bytes(values)).hexdigest()


def contains_marker(data, marker):
    return marker in data or marker.decode("ascii").encode("utf-16-le") in data


def main():
    if len(sys.argv) not in (2, 3):
        raise SystemExit("usage: verify_dark_beta.py BUILD_DIRECTORY [IPA_NAME]")
    build = Path(sys.argv[1])
    app = build / "Payload" / "FFCacheManager.app"
    core = app / "Frameworks" / "CoreTelemetry.framework" / "CoreTelemetry"
    ipa_name = sys.argv[2] if len(sys.argv) == 3 else "FFCacheManager-5.6.2-3-DARK.ipa"
    ipa = build / ipa_name

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

    if app_info.get("CFBundleShortVersionString") != "5.6.2":
        raise RuntimeError("DARK beta version must be 5.6.2")
    if app_info.get("CFBundleVersion") != "3":
        raise RuntimeError("DARK beta build must be 3")
    if app_info.get("CFBundleIdentifier") != "com.apple.mobile.MobileHouseArrest":
        raise RuntimeError("DARK beta bundle identifier changed")
    if app_info.get("CFBundleDisplayName") != "FF Cache Manager DARK":
        raise RuntimeError("DARK beta display name is incorrect")
    if app_info.get("MinimumOSVersion") != "15.0":
        raise RuntimeError("DARK beta minimum iOS version is incorrect")
    if framework_info.get("CFBundlePackageType") != "FMWK" or \
            framework_info.get("CFBundleExecutable") != "CoreTelemetry":
        raise RuntimeError("Framework metadata is incorrect")

    metadata = json.loads((build / "protected-core.json").read_text(encoding="utf-8"))["slices"]
    fat = lief.MachO.parse(core)
    if fat is None or len(fat) != 2:
        raise RuntimeError("Protected core is not a two-slice Mach-O")
    results = []
    for index, (binary, expected) in enumerate(zip(fat, metadata)):
        names = {symbol.name for symbol in binary.exported_symbols}
        unexpected_cleartext = {
            name for name in names if name not in EXPECTED_EXPORTS and not name.startswith("_Q")
        }
        if not EXPECTED_EXPORTS.issubset(names) or names & OLD_EXPORTS or unexpected_cleartext:
            raise RuntimeError(f"Protected exports are incorrect in slice {index}: {sorted(names)}")
        text = binary.get_section("__text")
        exports = binary.dyld_exports_trie
        if text is None or exports is None:
            raise RuntimeError(f"Protected regions missing from slice {index}")
        if sha256(text.content) != expected["text_sha256"] or \
                sha256(exports.content) != expected["export_sha256"]:
            raise RuntimeError(f"Integrity metadata mismatch in slice {index}")
        section_payload = b"".join(bytes(section.content) for section in binary.sections
                                   if bytes(section.content))
        if hashlib.sha256(section_payload).hexdigest() != expected["section_sha256"]:
            raise RuntimeError(f"Full section integrity metadata mismatch in slice {index}")
        results.append({"slice": index})

    app_fat = lief.MachO.parse(app / "FFCacheManager")
    if app_fat is None or len(app_fat) != 1:
        raise RuntimeError("Application must be a single arm64 Mach-O slice")
    application_bytes = (app / "FFCacheManager").read_bytes()
    if b"CoreTelemetry.framework" not in application_bytes or \
            b"FFProtectedCore.dylib" in application_bytes:
        raise RuntimeError("Application loader metadata is incorrect")

    required_api_markers = (
        b"/license/activate", b"/session/refresh", b"/session/logout",
        b"/session/validate", b"/feature/authorize", b"X-Feature-Token",
        b"session-access-token", b"session-refresh-token", b"/integrity/challenge",
        b"app_text_sha256", b"app_cstring_sha256", b"request_hash", b"framework_plist_sha256",
        b"P1", b"P5", b"P7", b"HOLOGRAM_GUN", b"MOD SKINS", b"/skins/catalog",
        b"/channel/status", b"CHANNEL_VERIFICATION_REQUIRED", b"STFAMILY FF",
        b"bot_username",
        b"3105 MCM", b"libsystem_containermanager", b"container_query_create",
        b"MCMMetadataIdentifier", b"WQ READY TO QUERY", b"com.apple.security.application-groups",
    )
    missing_api_markers = [
        marker for marker in required_api_markers
        if not contains_marker(application_bytes, marker)
    ]
    if missing_api_markers:
        raise RuntimeError(f"Stable feature/session markers are missing: {missing_api_markers}")

    missing_dark_markers = [
        marker for marker in DARK_MARKERS
        if not contains_marker(application_bytes, marker)
    ]
    if missing_dark_markers:
        raise RuntimeError(f"DARK markers are missing: {missing_dark_markers}")

    present_injection_markers = [
        marker for marker in INJECTION_MARKERS
        if contains_marker(application_bytes, marker)
    ]
    if present_injection_markers:
        raise RuntimeError(f"Injection markers leaked into DARK beta: {present_injection_markers}")

    missing_old_features = [
        marker for marker in OLD_FEATURE_MARKERS
        if not contains_marker(application_bytes, marker)
    ]
    if missing_old_features:
        raise RuntimeError(f"Old feature markers are missing: {missing_old_features}")

    core_bytes = core.read_bytes()
    leaked_markers = [marker.decode("ascii") for marker in SENSITIVE_EXPORT_MARKERS
                      if marker in core_bytes]
    if leaked_markers:
        raise RuntimeError(f"Original sensitive bridge exports leaked into the release: {leaked_markers}")

    release_bytes = application_bytes + core_bytes
    leaked_secrets = [marker.decode("ascii") for marker in FORBIDDEN_SECRET_MARKERS
                      if marker in release_bytes]
    if leaked_secrets:
        raise RuntimeError(f"Sensitive build material leaked into release binaries: {leaked_secrets}")

    leaked_diagnostics = [marker.decode("ascii") for marker in FORBIDDEN_RELEASE_DIAGNOSTICS
                          if marker in release_bytes]
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
        "mode": "DARK_BETA_IN_GAME_COMPANION",
        "ipa": ipa.name,
        "ipa_sha256": hashlib.sha256(ipa.read_bytes()).hexdigest().upper(),
        "ipa_size": ipa.stat().st_size,
        "files": len(expected_files),
        "app_version": app_info["CFBundleShortVersionString"],
        "build_version": app_info["CFBundleVersion"],
        "bundle_identifier": app_info["CFBundleIdentifier"],
        "display_name": app_info["CFBundleDisplayName"],
        "minimum_ios": app_info["MinimumOSVersion"],
        "architectures": len(fat),
        "slices": results,
        "dark_markers": len(DARK_MARKERS),
        "old_features_preserved": len(OLD_FEATURE_MARKERS),
        "injection_markers": 0,
    }, indent=2))


if __name__ == "__main__":
    main()
