import sys
from pathlib import Path

import lief


def main():
    if len(sys.argv) != 4:
        raise SystemExit("usage: set_install_name.py INPUT OUTPUT INSTALL_NAME")
    source = Path(sys.argv[1])
    output = Path(sys.argv[2])
    install_name = sys.argv[3]
    fat = lief.MachO.parse(str(source))
    if fat is None or len(fat) == 0:
        raise SystemExit("input is not a Mach-O binary")
    changed = 0
    for binary in fat:
        for command in binary.commands:
            if (isinstance(command, lief.MachO.DylibCommand)
                    and command.command == lief.MachO.LoadCommand.TYPE.ID_DYLIB):
                command.name = install_name
                changed += 1
    if changed == 0:
        raise SystemExit("input has no LC_ID_DYLIB command")
    output.parent.mkdir(parents=True, exist_ok=True)
    fat.write(str(output))
    print(f"INSTALL_NAME_PASS slices={len(fat)} commands={changed} name={install_name}")


if __name__ == "__main__":
    main()
