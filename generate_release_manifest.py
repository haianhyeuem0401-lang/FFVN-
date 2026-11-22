import hashlib
import json
import plistlib
import sys
from pathlib import Path

import lief


def digest(values):
    return hashlib.sha256(bytes(values)).hexdigest()


def macho_hashes(binary):
    text = binary.get_section("__text")
    exports = binary.dyld_exports_trie
    if text is None or exports is None:
        raise RuntimeError("Mach-O text or export trie is unavailable")
    return digest(text.content), digest(exports.content)


def application_hashes(binary):
    text = binary.get_section("__text")
    cstring = binary.get_section("__cstring")
    if text is None or cstring is None:
        raise RuntimeError("Application code or sensitive-string section is unavailable")
    # Hash the executable instructions and constant strings directly.  A
    # legitimate final signer may rewrite non-code Mach-O metadata, but must
    # never change either of these protected sections.
    return digest(text.content), digest(cstring.content)


def canonical_plist_hash(plist, keys):
    canonical = "|".join(f"{key}={plist.get(key, '')}" for key in keys)
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: generate_release_manifest.py BUILD_DIRECTORY OUTPUT_JSON")
    build = Path(sys.argv[1])
    output = Path(sys.argv[2])
    app = build / "Payload" / "FFCacheManager.app"
    executable = app / "FFCacheManager"
    framework = app / "Frameworks" / "CoreTelemetry.framework"
    core = framework / "CoreTelemetry"
    info_path = app / "Info.plist"
    framework_info_path = framework / "Info.plist"

    main_fat = lief.MachO.parse(executable)
    core_fat = lief.MachO.parse(core)
    if main_fat is None or len(main_fat) != 1:
        raise RuntimeError("Expected one arm64 application slice")
    if core_fat is None or len(core_fat) != 2:
        raise RuntimeError("Expected two protected-core slices")
    app_text, app_cstring = application_hashes(main_fat.at(0))
    core_a_text, core_a_exports = macho_hashes(core_fat.at(0))
    core_b_text, core_b_exports = macho_hashes(core_fat.at(1))
    info_data = info_path.read_bytes()
    framework_info_data = framework_info_path.read_bytes()
    info = plistlib.loads(info_data)
    framework_info = plistlib.loads(framework_info_data)

    manifest = {
        "schema": 1,
        "integrity": {
            "app_text_sha256": app_text,
            "app_cstring_sha256": app_cstring,
            "core_a_text_sha256": core_a_text,
            "core_a_export_sha256": core_a_exports,
            "core_b_text_sha256": core_b_text,
            "core_b_export_sha256": core_b_exports,
            # Hash stable security-relevant values so ESign can reserialize the plist
            # without invalidating an otherwise identical release.
            "info_plist_sha256": canonical_plist_hash(info, [
                "CFBundleDisplayName", "CFBundleExecutable", "CFBundleIdentifier", "CFBundleName",
                "CFBundlePackageType", "CFBundleShortVersionString", "CFBundleVersion", "MinimumOSVersion",
            ]),
            "framework_plist_sha256": canonical_plist_hash(framework_info, [
                "CFBundleExecutable", "CFBundleIdentifier", "CFBundleName", "CFBundlePackageType",
                "CFBundleShortVersionString", "CFBundleVersion", "MinimumOSVersion",
            ]),
            "bundle_identifier": info["CFBundleIdentifier"],
            "display_name": info["CFBundleDisplayName"],
            "app_version": info["CFBundleShortVersionString"],
            "build_version": info["CFBundleVersion"],
        },
    }
    output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"RELEASE_MANIFEST_PASS {output}")


if __name__ == "__main__":
    main()
