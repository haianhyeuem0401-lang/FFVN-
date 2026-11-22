import hashlib
import json
import struct
import sys
from pathlib import Path

MAGIC = b"FFASM001"
EXPECTED_FILES = (
    "Assembly-CSharp-patch.bytes",
    "localConfig.json",
)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def build_package(source_dir: Path, output_path: Path):
    entries = []
    payload = bytearray()
    for name in EXPECTED_FILES:
        file_path = source_dir / name
        if not file_path.is_file():
            raise RuntimeError(f"Missing source file: {file_path}")
        data = file_path.read_bytes()
        if name == "Assembly-CSharp-patch.bytes":
            header = data[:64]
            if (not header.startswith(b"UnityFS\x00") and b"IFix" not in header) or len(data) < 100_000:
                raise RuntimeError("Assembly-CSharp-patch.bytes is invalid")
        elif name == "localConfig.json":
            parsed = json.loads(data.decode("utf-8"))
            if not isinstance(parsed, dict) or parsed.get("testCodePatch") is not True:
                raise RuntimeError("localConfig.json is invalid")
        entries.append({
            "name": name,
            "offset": len(payload),
            "length": len(data),
            "sha256": sha256(data),
        })
        payload.extend(data)

    manifest = {
        "feature": "ASSEMBLY",
        "version": 1,
        "files": entries,
    }
    manifest_bytes = json.dumps(manifest, sort_keys=True, separators=(",", ":")).encode("utf-8")
    package = MAGIC + struct.pack(">I", len(manifest_bytes)) + manifest_bytes + bytes(payload)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_bytes(package)
    print(json.dumps({
        "status": "ASSEMBLY_PACKAGE_BUILT",
        "output": str(output_path),
        "size": len(package),
        "sha256": sha256(package),
        "files": entries,
    }, indent=2))


def main():
    root = Path(__file__).resolve().parent
    source_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else (root / "game_files")
    output_path = Path(sys.argv[2]) if len(sys.argv) > 2 else (root / "server_payloads" / "ASSEMBLY_package.ffasm")
    build_package(source_dir, output_path)


if __name__ == "__main__":
    main()
