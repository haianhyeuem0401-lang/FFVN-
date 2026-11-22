import json
import sys
from pathlib import Path


def main():
    if len(sys.argv) < 4:
        raise SystemExit("usage: combine_release_manifests.py OUTPUT INPUT [INPUT ...]")
    output = Path(sys.argv[1])
    releases = []
    identities = set()
    for source_name in sys.argv[2:]:
        source = json.loads(Path(source_name).read_text(encoding="utf-8"))
        items = source.get("releases") or [source["integrity"]]
        for item in items:
            identity = (item["app_version"], item["build_version"], item["app_text_sha256"])
            if identity not in identities:
                identities.add(identity)
                releases.append(item)
    releases.sort(key=lambda item: tuple(int(part) for part in item["app_version"].split(".")))
    output.write_text(json.dumps({"schema": 2, "releases": releases}, indent=2) + "\n", encoding="utf-8")
    print("RELEASE_ALLOWLIST_PASS " + ",".join(item["app_version"] for item in releases))


if __name__ == "__main__":
    main()

