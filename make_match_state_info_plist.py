import plistlib
import sys
from pathlib import Path


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: make_match_state_info_plist.py SOURCE_PLIST OUTPUT_PLIST")
    source = Path(sys.argv[1])
    output = Path(sys.argv[2])
    with source.open("rb") as handle:
        info = plistlib.load(handle)
    info["CFBundleDisplayName"] = "FF Cache Manager MATCH"
    info["CFBundleShortVersionString"] = "5.6.2"
    info["CFBundleVersion"] = "4"
    with output.open("wb") as handle:
        plistlib.dump(info, handle, sort_keys=False)
    print(f"MATCH_STATE_INFO_PLIST_PASS {output} 5.6.2/4")


if __name__ == "__main__":
    main()
