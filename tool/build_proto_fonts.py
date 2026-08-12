"""Rebuild example/fonts/proto with the package CLI (not varLib).

Used by the render matrix and the fonttools oracle. Static fonts at each
prototype width plus one variable font built with --stroke-width-range.

Run from the repo root:

    python3 tool/build_proto_fonts.py
"""
import importlib.util
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "example" / "fonts" / "proto"
TMP = ROOT / "tool" / "variable_prototype" / "out" / "render_matrix_svgs"
WIDTHS = [1.33, 1.5, 2.0]

_spec = importlib.util.spec_from_file_location(
    "glyphs",
    ROOT / "tool" / "variable_prototype" / "glyphs.py",
)
_glyphs = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_glyphs)


def write_svgs(width):
    directory = TMP / f"width_{width}"
    directory.mkdir(parents=True, exist_ok=True)
    for name, build in _glyphs.GLYPHS.items():
        (directory / f"{name}.svg").write_text(build(width))
    return directory


def run_fontify(svg_dir, font_path, *extra):
    command = [
        "dart",
        "run",
        "bin/fontify_plus.dart",
        str(svg_dir),
        str(font_path),
        "--font-name=Proto",
        "--no-normalize",
        *extra,
    ]
    subprocess.run(command, cwd=ROOT, check=True)


def main():
    OUT.mkdir(parents=True, exist_ok=True)

    for width in WIDTHS:
        svg_dir = write_svgs(width)
        static = OUT / f"static_{width}_cff.otf"
        run_fontify(svg_dir, static)
        print("built", static, file=sys.stderr)

    variable_svgs = write_svgs(2.0)
    variable = OUT / "variable_cff2.otf"
    run_fontify(
        variable_svgs,
        variable,
        "--stroke-width-range=1.33,2",
    )
    print("built", variable, file=sys.stderr)


if __name__ == "__main__":
    main()
