import os
import sys
import time
import zipfile
from pathlib import Path


EXECUTABLES = {"FFCacheManager", "CoreTelemetry"}


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: make_ipa.py BUILD_DIRECTORY OUTPUT_IPA")
    build = Path(sys.argv[1])
    output = Path(sys.argv[2])
    payload = build / "Payload"
    if not (payload / "FFCacheManager.app" / "FFCacheManager").is_file():
        raise SystemExit("Payload/FFCacheManager.app/FFCacheManager is missing")

    stamp = time.localtime()[:6]
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for directory, _subdirs, files in os.walk(payload):
            relative_dir = os.path.relpath(directory, payload).replace(os.sep, "/")
            if relative_dir != ".":
                info = zipfile.ZipInfo("Payload/" + relative_dir + "/", stamp)
                info.external_attr = (0o40755 << 16) | 0x10
                archive.writestr(info, b"")
            for name in sorted(files):
                full = Path(directory) / name
                relative = os.path.relpath(full, payload).replace(os.sep, "/")
                info = zipfile.ZipInfo("Payload/" + relative, stamp)
                mode = 0o100755 if name in EXECUTABLES else 0o100644
                info.external_attr = mode << 16
                info.compress_type = zipfile.ZIP_DEFLATED
                archive.writestr(info, full.read_bytes())

    print(f"IPA_PACKAGE_PASS {output} {output.stat().st_size} bytes")


if __name__ == "__main__":
    main()
