import json
import sys
from pathlib import Path


FIELDS = {
    "app_text_sha256", "app_cstring_sha256", "core_a_text_sha256", "core_a_export_sha256",
    "core_b_text_sha256", "core_b_export_sha256", "info_plist_sha256",
    "framework_plist_sha256", "bundle_identifier", "display_name", "app_version", "build_version",
}


def entries(document):
    values = document.get("releases") or [document.get("integrity")]
    if not isinstance(values, list) or not values or any(not isinstance(row, dict) for row in values):
        raise RuntimeError("Release manifest has no valid entries")
    if any(not FIELDS <= set(row) for row in values):
        raise RuntimeError("Release entry is incomplete")
    return values


def main():
    if len(sys.argv) != 4:
        raise SystemExit("usage: merge_release_manifests.py BASE NEW OUTPUT")
    base_path, new_path, output_path = map(Path, sys.argv[1:])
    base = json.loads(base_path.read_text(encoding="utf-8"))
    new = json.loads(new_path.read_text(encoding="utf-8"))
    releases = entries(base)
    for candidate in entries(new):
        releases = [row for row in releases if row["app_text_sha256"] != candidate["app_text_sha256"]]
        releases.append(candidate)
    output = {"schema": 2, "releases": releases}
    output_path.write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
    print(f"RELEASE_MANIFEST_MERGE_PASS releases={len(releases)} output={output_path}")


if __name__ == "__main__":
    main()
