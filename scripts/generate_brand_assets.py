from pathlib import Path
import shutil
import sys

import cairosvg
from PIL import Image


def main() -> int:
    if len(sys.argv) not in (3, 4):
        print("Usage: generate_brand_assets.py <logo_icon_svg> <repo_root> [brand_app_icon_ico]")
        return 1

    src_svg = Path(sys.argv[1]).resolve()
    repo_root = Path(sys.argv[2]).resolve()
    src_ico = Path(sys.argv[3]).resolve() if len(sys.argv) == 4 else None

    if not src_svg.exists():
        raise FileNotFoundError(f"Missing icon svg: {src_svg}")

    tmp_png = repo_root / "build" / "brand_icon_1024.png"
    tmp_png.parent.mkdir(parents=True, exist_ok=True)

    cairosvg.svg2png(
        url=str(src_svg),
        write_to=str(tmp_png),
        output_width=1024,
        output_height=1024,
    )
    img = Image.open(tmp_png).convert("RGBA")

    ico_sizes = [(16, 16), (24, 24), (32, 32), (40, 40), (48, 48), (64, 64), (128, 128), (256, 256)]
    win_ico = repo_root / "windows" / "runner" / "resources" / "app_icon.ico"
    assets_ico = repo_root / "assets" / "app_icon.ico"
    if src_ico is not None and src_ico.exists():
        shutil.copyfile(src_ico, win_ico)
        shutil.copyfile(src_ico, assets_ico)
    else:
        img.save(win_ico, format="ICO", sizes=ico_sizes)
        img.save(assets_ico, format="ICO", sizes=ico_sizes)

    android_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in android_sizes.items():
        target = repo_root / "android" / "app" / "src" / "main" / "res" / folder / "ic_launcher.png"
        resized = img.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(target, format="PNG")

    tmp_png.unlink(missing_ok=True)
    print("Brand assets generated successfully")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
