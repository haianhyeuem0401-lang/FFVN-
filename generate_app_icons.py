import sys
from pathlib import Path

from PIL import Image


ICON_SIZES = {
    "AppIcon60x60@2x.png": 120,
    "AppIcon60x60@3x.png": 180,
    "AppIcon76x76.png": 76,
    "AppIcon76x76@2x.png": 152,
    "AppIcon83.5x83.5@2x.png": 167,
    "AppIcon1024.png": 1024,
}


def square_crop(image):
    edge = min(image.width, image.height)
    left = (image.width - edge) // 2
    top = (image.height - edge) // 2
    return image.crop((left, top, left + edge, top + edge))


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: generate_app_icons.py SOURCE_IMAGE APP_DIRECTORY")
    source = Path(sys.argv[1])
    app = Path(sys.argv[2])
    if not source.is_file() or not app.is_dir():
        raise RuntimeError("Icon source or application directory is unavailable")
    with Image.open(source) as loaded:
        image = square_crop(loaded.convert("RGB"))
    for name, size in ICON_SIZES.items():
        icon = image.resize((size, size), Image.Resampling.LANCZOS)
        icon.save(app / name, "PNG", optimize=True)
    print("APP_ICON_GENERATION_PASS")


if __name__ == "__main__":
    main()

