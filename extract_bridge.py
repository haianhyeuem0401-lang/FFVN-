import sys
import zipfile
from pathlib import Path


DONOR_MEMBER = "Payload/Filza.app/Frameworks/FilzaApplySandboxExt.dylib"


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: extract_bridge.py FILZA_IPA OUTPUT_DYLIB")
    ipa = Path(sys.argv[1])
    output = Path(sys.argv[2])
    if not ipa.is_file():
        raise SystemExit(f"donor IPA not found: {ipa}")
    with zipfile.ZipFile(ipa) as archive:
        try:
            data = archive.read(DONOR_MEMBER)
        except KeyError:
            raise SystemExit(f"donor member missing from IPA: {DONOR_MEMBER}")
    if not data:
        raise SystemExit("donor bridge is empty")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(data)
    print(f"EXTRACT_BRIDGE_PASS {len(data)} bytes -> {output}")


if __name__ == "__main__":
    main()
