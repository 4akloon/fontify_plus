"""Builds static master fonts at each prototype stroke width."""
import pathlib
import subprocess
import sys

import glyphs

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = pathlib.Path(__file__).parent / "out"
WIDTHS = [1.33, 1.5, 2.0]


def write_svgs(width):
    directory = OUT / f"svg_{width}"
    directory.mkdir(parents=True, exist_ok=True)
    for name, build in glyphs.GLYPHS.items():
        (directory / f"{name}.svg").write_text(build(width))
    return directory


def build(width, fmt):
    svg_dir = write_svgs(width)
    font = OUT / f"static_{width}_{fmt}.otf"
    command = [
        "dart", "run", "bin/fontify_plus.dart",
        str(svg_dir), str(font),
        "--font-name=Proto", "--no-normalize",
    ]
    if fmt == "glyf":
        command.append("--no-opentype")
    subprocess.run(command, cwd=ROOT, check=True)
    return font


if __name__ == "__main__":
    OUT.mkdir(exist_ok=True)
    for w in WIDTHS:
        for f in ("cff", "glyf"):
            print("built", build(w, f), file=sys.stderr)
