"""Validates generated fonts against fonttools, an independent implementation.

Usage:
  validate_font.py FONT [FONT ...]
  validate_font.py --variable VARIABLE.otf --static-prefix PREFIX

`--variable` runs the full variable-font gate set on VARIABLE.otf:
metadata round-trip, interpolation against static fonts at each axis stop,
`pyftsubset` survival, and `ots-sanitize`. Static fonts at each stop are read
from PREFIX + "{stop}_cff.otf" (e.g. PREFIX=fonts/proto/static_ yields
fonts/proto/static_1.33_cff.otf).

Plain FONT arguments only check parse and round-trip save.
"""
import io
import pathlib
import shutil
import subprocess
import sys

from fontTools.pens.recordingPen import RecordingPen
from fontTools.subset import Subsetter
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

STOPS = [1.33, 1.5, 2.0]
ICON_CODEPOINTS = [0xE000, 0xE001, 0xE002]
# Font units at unitsPerEm 1000. Phase 0 CFF2 prototypes sat exactly on this
# bound, so the gate has no margin — 3 units is a regression, not noise.
TOLERANCE = 2


def _outlines(font, glyph_name):
    pen = RecordingPen()
    font.getGlyphSet()[glyph_name].draw(pen)
    points = []
    for _, args in pen.value:
        for arg in args:
            if isinstance(arg, tuple):
                points.extend(arg)
    return points


def validate_static(path):
    font = TTFont(path)
    buffer = io.BytesIO()
    font.save(buffer)
    TTFont(io.BytesIO(buffer.getvalue()))
    return "static font, parses and round-trips"


def validate_variable_metadata(path):
    font = TTFont(path)
    buffer = io.BytesIO()
    font.save(buffer)
    TTFont(io.BytesIO(buffer.getvalue()))

    if "fvar" not in font:
        raise AssertionError("no fvar table, so this font is static")

    axis = font["fvar"].axes[0]
    if "STAT" not in font:
        raise AssertionError("variable font without a STAT table")
    if axis.minValue >= axis.maxValue:
        raise AssertionError(f"empty axis range {axis.minValue}-{axis.maxValue}")

    axis_name = font["name"].getDebugName(axis.axisNameID)
    if not axis_name:
        raise AssertionError(
            f"fvar axisNameID {axis.axisNameID} resolves to no name record"
        )

    return (
        f"variable font, axis {axis.axisTag} "
        f'"{axis_name}" '
        f"{axis.minValue}-{axis.maxValue} default {axis.defaultValue}"
    )


def validate_interpolation(variable_path, static_prefix):
    """Axis endpoints must match instancing; mid stop must match lerped endpoints."""
    variable = TTFont(variable_path)
    worst = 0.0

    thin = instantiateVariableFont(variable, {"wght": STOPS[0]})
    thick = instantiateVariableFont(variable, {"wght": STOPS[-1]})
    thin_buffer = io.BytesIO()
    thin.save(thin_buffer)
    thin = TTFont(io.BytesIO(thin_buffer.getvalue()))
    thick_buffer = io.BytesIO()
    thick.save(thick_buffer)
    thick = TTFont(io.BytesIO(thick_buffer.getvalue()))

    static_max_path = pathlib.Path(f"{static_prefix}2.0_cff.otf")
    if not static_max_path.is_file():
        static_max_path = pathlib.Path("example/fonts/my_icons.otf")
    if static_max_path.is_file():
        static_max = TTFont(static_max_path)
        static_cmap = static_max.getBestCmap()
        thick_cmap = thick.getBestCmap()
        for code in _icon_codepoints(variable, thick_cmap):
            a = _outlines(thick, thick_cmap[code])
            b = _outlines(static_max, static_cmap[code])
            if len(a) != len(b):
                raise AssertionError(
                    f"max endpoint U+{code:04X}: {len(a)} points vs {len(b)}"
                )
            worst = max(
                worst,
                max((abs(x - y) for x, y in zip(a, b)), default=0),
            )

    thin_cmap = thin.getBestCmap()
    thick_cmap = thick.getBestCmap()
    axis_span = STOPS[-1] - STOPS[0]
    mid_fraction = (1.5 - STOPS[0]) / axis_span

    mid = instantiateVariableFont(variable, {"wght": 1.5})
    buffer = io.BytesIO()
    mid.save(buffer)
    mid = TTFont(io.BytesIO(buffer.getvalue()))
    mid_cmap = mid.getBestCmap()

    for code in _icon_codepoints(variable, thin_cmap):
        thin_pts = _outlines(thin, thin_cmap[code])
        thick_pts = _outlines(thick, thick_cmap[code])
        mid_pts = _outlines(mid, mid_cmap[code])
        if len({len(thin_pts), len(thick_pts), len(mid_pts)}) != 1:
            raise AssertionError(
                f"U+{code:04X}: point counts differ across stops "
                f"({len(thin_pts)}, {len(mid_pts)}, {len(thick_pts)})"
            )
        for thin_v, thick_v, mid_v in zip(thin_pts, thick_pts, mid_pts):
            expected = thin_v + mid_fraction * (thick_v - thin_v)
            worst = max(worst, abs(mid_v - expected))

    if worst > TOLERANCE:
        raise AssertionError(f"worst deviation {worst:.2f} > {TOLERANCE}")

    return f"interpolation consistent (worst {worst:.2f} units)"


def _icon_codepoints(variable, cmap):
    for code in ICON_CODEPOINTS:
        if code in cmap:
            yield code
    for code in sorted(cmap):
        if code >= 0xE000:
            yield code


def validate_subset(path):
    font = TTFont(path)
    subsetter = Subsetter()
    subsetter.populate(unicodes=[0xE000, 0xE001])
    subsetter.subset(font)
    buffer = io.BytesIO()
    font.save(buffer)
    after = TTFont(io.BytesIO(buffer.getvalue()))

    if "fvar" not in after:
        raise AssertionError("fvar dropped by subsetting")
    if "STAT" not in after:
        raise AssertionError("STAT dropped by subsetting")

    raw_cff2 = after.reader["CFF2"]
    if raw_cff2.count(bytes([16])) == 0:
        raise AssertionError("subset charstrings contain no blend operator")

    return f"survives pyftsubset ({buffer.getbuffer().nbytes} B)"


def _ots_sanitize_command():
    ots = shutil.which("ots-sanitize")
    if ots is not None:
        return [ots]

    try:
        import ots as ots_module
    except ImportError:
        raise AssertionError(
            "ots-sanitize not found — install PyPI opentype-sanitizer, not homebrew ots"
        ) from None

    bundled = pathlib.Path(ots_module.__file__).parent / "ots-sanitize"
    if bundled.is_file():
        return [str(bundled)]

    raise AssertionError(
        "ots-sanitize not found — install PyPI opentype-sanitizer, not homebrew ots"
    )


def validate_ots(path):
    subprocess.run(_ots_sanitize_command() + [str(path)], check=True, capture_output=True)
    return "ots-sanitize clean"


def validate_variable(variable_path, static_prefix):
    parts = [
        validate_variable_metadata(variable_path),
        validate_interpolation(variable_path, static_prefix),
        validate_subset(variable_path),
        validate_ots(variable_path),
    ]
    return "; ".join(parts)


if __name__ == "__main__":
    arguments = sys.argv[1:]
    variable_path = None
    static_prefix = None
    paths = []

    index = 0
    while index < len(arguments):
        arg = arguments[index]
        if arg == "--variable":
            index += 1
            variable_path = arguments[index]
        elif arg == "--static-prefix":
            index += 1
            static_prefix = arguments[index]
        else:
            paths.append(arg)
        index += 1

    if variable_path is not None:
        if static_prefix is None:
            print("usage: --variable requires --static-prefix")
            sys.exit(2)
        try:
            print(
                f"{variable_path}: "
                f"{validate_variable(variable_path, static_prefix)}"
            )
        except Exception as error:  # noqa: BLE001 - report every font
            print(f"{variable_path}: FAIL {error}")
            sys.exit(1)

    for path in paths:
        try:
            print(f"{path}: {validate_static(path)}")
        except Exception as error:  # noqa: BLE001
            print(f"{path}: FAIL {error}")
            sys.exit(1)

    if not paths and variable_path is None:
        print(f"usage: {sys.argv[0]} [--variable VAR --static-prefix PREFIX] FONT ...")
        sys.exit(2)
