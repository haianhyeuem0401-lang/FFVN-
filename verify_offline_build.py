import hashlib
import json
import plistlib
import struct
import sys
import zipfile
from pathlib import Path

import lief
from PIL import Image


EXPECTED_EXPORTS = {
    "_FKX0A7Q2M9Z",
    "_FKX1R4V8N6P",
    "_FKX2C5J9T3W",
}
OLD_EXPORTS = {
    "_MCMFilzaStart",
    "_MCMFilzaDataContainerPath",
    "_MCMFilzaSetUnrestrictedFilesystem",
}
ICON_FILES = {
    "AppIcon60x60@2x.png": (120, 120),
    "AppIcon60x60@3x.png": (180, 180),
    "AppIcon76x76.png": (76, 76),
    "AppIcon76x76@2x.png": (152, 152),
    "AppIcon83.5x83.5@2x.png": (167, 167),
    "AppIcon1024.png": (1024, 1024),
}
OFFLINE_FEATURES = {"BODY", "DRAG", "NECK"}
EXPECTED_FEATURE_HASHES = {
    "BODY": "BC757879848667779CB37B2092EB9C9382F41A825A86AE3D11ECCA5818463413",
    "DRAG": "678C1310430200B902C2B8427F2FC439439362C8DFE1CE555DCD99AD1C3A9065",
    "NECK": "73A1DF313DA2CBD9E9D1392ADEEA9B6FC9644102F1E621855FE3D01D37AB7205",
}
FORBIDDEN_SECRET_MARKERS = (
    b"FFCACHE_SECRET=",
    b"FF_SSH_PASSWORD=",
    b"BEGIN PRIVATE KEY",
)


def sha256(data):
    return hashlib.sha256(data).hexdigest().upper()


def contains_string(binary, value):
    return value.encode("ascii") in binary or value.encode("utf-16le") in binary


def verify_linker_adhoc_signature(application_bytes, macho):
    binary = macho.at(0)
    if not binary.has_code_signature:
        raise RuntimeError("Application has no replaceable linker ad-hoc signature")
    offset = binary.code_signature.data_offset
    size = binary.code_signature.data_size
    if offset <= 0 or size < 24 or offset + size != len(application_bytes):
        raise RuntimeError("Application ad-hoc signature range is malformed")

    signature = application_bytes[offset:offset + size]
    magic, length, count = struct.unpack_from(">III", signature, 0)
    if magic != 0xFADE0CC0 or length > size or 12 + count * 8 > length:
        raise RuntimeError("Application embedded signature superblob is malformed")

    verified_directories = 0
    for index in range(count):
        slot_type, directory_offset = struct.unpack_from(">II", signature, 12 + index * 8)
        if directory_offset + 40 > length:
            raise RuntimeError("Application CodeDirectory offset is malformed")
        directory_magic = struct.unpack_from(">I", signature, directory_offset)[0]
        if slot_type != 0 or directory_magic != 0xFADE0C02:
            continue
        fields = struct.unpack_from(">9I4B", signature, directory_offset)
        (_, directory_length, _, flags, hash_offset, _, _, code_slots,
         code_limit, hash_size, hash_type, _, page_size_power) = fields
        if directory_offset + directory_length > length:
            raise RuntimeError("Application CodeDirectory length is malformed")
        if flags & 0x2 == 0 or flags & 0x20000 == 0:
            raise RuntimeError("Application signature is not a replaceable linker ad-hoc signature")
        if hash_type != 2 or hash_size != 32 or page_size_power > 20:
            raise RuntimeError("Application CodeDirectory hash configuration is unsupported")
        if code_limit != offset:
            raise RuntimeError("Application CodeDirectory does not cover the complete executable")
        page_size = 1 << page_size_power
        if code_slots != (code_limit + page_size - 1) // page_size:
            raise RuntimeError("Application CodeDirectory slot count is incorrect")
        if hash_offset + code_slots * hash_size > directory_length:
            raise RuntimeError("Application CodeDirectory hash table is malformed")
        for slot in range(code_slots):
            page = application_bytes[slot * page_size:min((slot + 1) * page_size, code_limit)]
            expected = hashlib.sha256(page).digest()
            start = directory_offset + hash_offset + slot * hash_size
            if signature[start:start + hash_size] != expected:
                raise RuntimeError(f"Application ad-hoc signature code-page hash mismatch: {slot}")
        verified_directories += 1
    if verified_directories != 1:
        raise RuntimeError("Application must contain exactly one verified linker CodeDirectory")


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: verify_offline_build.py BUILD_DIRECTORY IPA_FILENAME")

    build = Path(sys.argv[1])
    ipa = build / sys.argv[2]
    app = build / "Payload" / "FFCacheManager.app"
    executable = app / "FFCacheManager"
    core = app / "Frameworks" / "CoreTelemetry.framework" / "CoreTelemetry"

    expected_files = {
        "Payload/FFCacheManager.app/FFCacheManager",
        "Payload/FFCacheManager.app/Info.plist",
        "Payload/FFCacheManager.app/Frameworks/CoreTelemetry.framework/CoreTelemetry",
        "Payload/FFCacheManager.app/Frameworks/CoreTelemetry.framework/Info.plist",
        *(f"Payload/FFCacheManager.app/{name}" for name in ICON_FILES),
        *(f"Payload/FFCacheManager.app/OfflineCache/{name}.ffcache" for name in OFFLINE_FEATURES),
    }
    if not zipfile.is_zipfile(ipa):
        raise RuntimeError("Offline IPA is not a ZIP archive")
    with zipfile.ZipFile(ipa) as archive:
        archive_files = {name for name in archive.namelist() if not name.endswith("/")}
        if archive_files != expected_files:
            raise RuntimeError(f"Unexpected offline IPA files: {sorted(archive_files ^ expected_files)}")
        for name in expected_files:
            staged = build / Path(name)
            if sha256(archive.read(name)) != sha256(staged.read_bytes()):
                raise RuntimeError(f"Archived file differs from staged file: {name}")

    app_info_bytes = (app / "Info.plist").read_bytes()
    if not app_info_bytes.startswith(b'<?xml version="1.0" encoding="UTF-8"?>\n'):
        raise RuntimeError("Info.plist is not canonical UTF-8 XML")
    if app_info_bytes.startswith(b"\xef\xbb\xbf") or b"PropertyList-1.0.dtd\"[]>" in app_info_bytes:
        raise RuntimeError("Info.plist contains the Windows XML BOM/DOCTYPE corruption")
    with (app / "Info.plist").open("rb") as handle:
        app_info = plistlib.load(handle)
    with (core.parent / "Info.plist").open("rb") as handle:
        framework_info = plistlib.load(handle)
    extensionless_files = {
        path.relative_to(app).as_posix()
        for path in app.rglob("*")
        if path.is_file() and not path.suffix
    }
    expected_executables = {
        "FFCacheManager",
        "Frameworks/CoreTelemetry.framework/CoreTelemetry",
    }
    if extensionless_files != expected_executables:
        raise RuntimeError(
            f"Non-Mach-O extensionless resources would confuse ESign: "
            f"{sorted(extensionless_files ^ expected_executables)}"
        )
    if app_info.get("CFBundleIdentifier") != "com.apple.mobile.MobileHouseArrest":
        raise RuntimeError("Offline application identity is incorrect")
    if app_info.get("CFBundleShortVersionString") != "5.1" or app_info.get("CFBundleVersion") != "37":
        raise RuntimeError("Offline application must carry the exact-3105-MCM v155 metadata (5.1/37)")
    if app_info.get("MinimumOSVersion") != "15.0":
        raise RuntimeError("Offline application minimum iOS must match the protected core")
    if framework_info.get("MinimumOSVersion") != "15.0":
        raise RuntimeError("Protected framework minimum iOS is incorrect")

    application_bytes = executable.read_bytes()
    application_macho = lief.MachO.parse(executable)
    if application_macho is None or len(application_macho) != 1:
        raise RuntimeError("Offline application executable is not a thin arm64 Mach-O")
    verify_linker_adhoc_signature(application_bytes, application_macho)
    required_markers = (
        b"OFFLINE MODE",
        b"ffg_offline",
        b"3105 MCM access engine",
        b"flags 0x900000000",
        b"CoreTelemetry.framework",
        b"/usr/lib/system/libsystem_containermanager.dylib",
        b"container_query_create",
        b"container_query_set_class",
        b"container_query_set_identifiers",
        b"container_query_operation_set_flags",
        b"container_query_get_single_result",
        b"container_object_get_path",
        b"container_object_copy",
        b"container_copy_sandbox_token",
        b"container_object_sandbox_extension_activate",
    )
    missing = [
        marker.decode("ascii")
        for marker in required_markers
        if not contains_string(application_bytes, marker.decode("ascii"))
    ]
    if missing:
        raise RuntimeError(f"Offline/direct markers are missing: {missing}")

    fat = lief.MachO.parse(core)
    if fat is None or len(fat) != 2:
        raise RuntimeError("Protected core is not a two-slice arm64/arm64e Mach-O")
    metadata = json.loads((build / "protected-core.json").read_text(encoding="utf-8"))["slices"]
    if len(metadata) != len(fat):
        raise RuntimeError("Protected core metadata slice count is incorrect")
    for index, (binary, expected) in enumerate(zip(fat, metadata)):
        names = {symbol.name for symbol in binary.exported_symbols}
        if not EXPECTED_EXPORTS.issubset(names) or names & OLD_EXPORTS:
            raise RuntimeError(f"Protected exports are incorrect in slice {index}")
        text = binary.get_section("__text")
        exports = binary.dyld_exports_trie
        if text is None or exports is None:
            raise RuntimeError(f"Protected regions are missing in slice {index}")
        text_hash = hashlib.sha256(bytes(text.content)).hexdigest()
        export_hash = hashlib.sha256(bytes(exports.content)).hexdigest()
        if text_hash != expected["text_sha256"] or export_hash != expected["export_sha256"]:
            raise RuntimeError(f"Protected core SHA-256 metadata mismatch in slice {index}")
        if expected["text_sha256"].encode("ascii") not in application_bytes:
            raise RuntimeError(f"Application does not embed the core text SHA-256 for slice {index}")
        if expected["export_sha256"].encode("ascii") not in application_bytes:
            raise RuntimeError(f"Application does not embed the core export SHA-256 for slice {index}")

    release_bytes = application_bytes + core.read_bytes()
    leaked = [marker.decode("ascii") for marker in FORBIDDEN_SECRET_MARKERS if marker in release_bytes]
    if leaked:
        raise RuntimeError(f"Sensitive build material leaked into offline release: {leaked}")

    feature_hashes = {}
    for feature in sorted(OFFLINE_FEATURES):
        data = (app / "OfflineCache" / f"{feature}.ffcache").read_bytes()
        if len(data) < 40_000 or not data.startswith(b"UnityFS\x00"):
            raise RuntimeError(f"Offline profile is not a valid UnityFS bundle: {feature}")
        feature_hashes[feature] = sha256(data)
        if feature_hashes[feature] != EXPECTED_FEATURE_HASHES[feature]:
            raise RuntimeError(f"Offline profile SHA-256 does not match the supplied file: {feature}")

    for name, expected_size in ICON_FILES.items():
        with Image.open(app / name) as icon:
            if icon.format != "PNG" or icon.size != expected_size:
                raise RuntimeError(f"Application icon is invalid: {name}")

    print(json.dumps({
        "status": "PASS",
        "mode": "offline-direct-only",
        "ipa_sha256": sha256(ipa.read_bytes()),
        "ipa_size": ipa.stat().st_size,
        "app_version": app_info["CFBundleShortVersionString"],
        "build_version": app_info["CFBundleVersion"],
        "minimum_ios": app_info["MinimumOSVersion"],
        "main_architectures": 1,
        "core_architectures": len(fat),
        "offline_features": feature_hashes,
    }, indent=2))


if __name__ == "__main__":
    main()
