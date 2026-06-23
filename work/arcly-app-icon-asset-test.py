#!/usr/bin/env python3
import hashlib
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE_ICON = Path(
    "/Users/apple/.codex/generated_images/019ece02-48cd-76e2-8a43-bb8faffd8b7f/"
    "ig_009b136fde3ca2f3016a39d909d12c81989d6a99eec563196c.png"
)
APPICON_SET = ROOT / "Resources" / "Assets.xcassets" / "AppIcon.appiconset"
ICNS = ROOT / "Resources" / "AppIcon.icns"
SOURCE_CROP_BOX = (187, 203, 1074, 1090)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def dimensions(path: Path) -> tuple[int, int]:
    result = subprocess.run(
        ["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(path)],
        check=True,
        capture_output=True,
        text=True,
    )
    width = height = None
    for line in result.stdout.splitlines():
        parts = line.strip().split(": ")
        if len(parts) != 2:
            continue
        if parts[0] == "pixelWidth":
            width = int(parts[1])
        elif parts[0] == "pixelHeight":
            height = int(parts[1])
    assert width is not None and height is not None, f"could not read dimensions for {path}"
    return width, height


def resized_hash(size: int) -> str:
    with tempfile.TemporaryDirectory() as tmp:
        cropped = Path(tmp) / "cropped.png"
        out = Path(tmp) / f"icon_{size}.png"
        subprocess.run(
            [
                "python3",
                "-c",
                (
                    "from PIL import Image; "
                    "im=Image.open(r'''%s''').convert('RGB'); "
                    "im.crop(%r).resize((1024, 1024), Image.Resampling.LANCZOS).save(r'''%s''')"
                )
                % (SOURCE_ICON, SOURCE_CROP_BOX, cropped),
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        subprocess.run(
            ["sips", "-s", "format", "png", "-z", str(size), str(size), str(cropped), "--out", str(out)],
            check=True,
            capture_output=True,
            text=True,
        )
        return sha256(out)


def main() -> None:
    assert SOURCE_ICON.exists(), f"selected source icon is missing: {SOURCE_ICON}"
    assert ICNS.exists() and ICNS.stat().st_size > 0, "AppIcon.icns should exist and be non-empty"

    for size in [16, 32, 64, 128, 256, 512, 1024]:
        icon = APPICON_SET / f"icon_{size}x{size}.png"
        assert icon.exists(), f"missing app icon asset: {icon}"
        assert dimensions(icon) == (size, size), f"{icon.name} should be {size}x{size}"

    current_1024 = APPICON_SET / "icon_1024x1024.png"
    assert sha256(current_1024) == resized_hash(1024), (
        "the project AppIcon should be generated from the cropped, edge-filling liquid-A Arcly icon"
    )

    print("Arcly app icon asset contract passed.")


if __name__ == "__main__":
    main()
