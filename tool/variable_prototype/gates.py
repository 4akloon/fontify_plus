"""The four Phase 0 gates: parse, instance-correctness, subset survival, size."""
import io
import pathlib
import sys

from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
from fontTools.subset import Subsetter

OUT = pathlib.Path(__file__).parent / "out"
STOPS = [1.33, 1.5, 2.0]
# Font units of slack per coordinate; masters round to integers independently.
TOLERANCE = 2


def outlines(font, glyph_name):
    """Every point of one glyph, as a flat list, whatever the outline format."""
    from fontTools.pens.recordingPen import RecordingPen

    pen = RecordingPen()
    font.getGlyphSet()[glyph_name].draw(pen)
    points = []
    for _, args in pen.value:
        for arg in args:
            if isinstance(arg, tuple):
                points.extend(arg)
    return points


def gate_parse(path):
    TTFont(path).save(io.BytesIO())
    return "parses"


def gate_correctness(variable_path, static_fmt):
    """Every stop of the variable font must match a separately built static."""
    worst = 0.0
    for stop in STOPS:
        instance = instantiateVariableFont(TTFont(variable_path), {"wght": stop})
        static = TTFont(OUT / f"static_{stop}_{static_fmt}.otf")
        for name in static.getGlyphOrder():
            if name in (".notdef", "space"):
                continue
            a, b = outlines(instance, name), outlines(static, name)
            if len(a) != len(b):
                raise AssertionError(
                    f"{variable_path.name} @{stop} {name}: "
                    f"{len(a)} points vs {len(b)}"
                )
            worst = max(worst, max((abs(x - y) for x, y in zip(a, b)), default=0))
    if worst > TOLERANCE:
        raise AssertionError(f"{variable_path.name}: worst deviation {worst:.2f}")
    return f"matches static (worst {worst:.2f} units)"


def gate_subset(path):
    font = TTFont(path)
    subsetter = Subsetter()
    subsetter.populate(unicodes=[0xE000])
    subsetter.subset(font)
    buffer = io.BytesIO()
    font.save(buffer)
    after = TTFont(io.BytesIO(buffer.getvalue()))
    if "fvar" not in after:
        raise AssertionError(f"{path.name}: fvar dropped by subsetting")
    if "gvar" not in after and "CFF2" not in after:
        raise AssertionError(f"{path.name}: variation data dropped by subsetting")
    return f"survives subsetting ({buffer.getbuffer().nbytes} B)"


# The tables that actually carry outlines, per format. Everything else in
# these fonts is fixed overhead that does not grow with the icon set.
OUTLINE_TABLES = ("CFF ", "CFF2", "glyf", "gvar")


def outline_bytes(path):
    reader = TTFont(path).reader
    return sum(
        reader.tables[tag].length for tag in OUTLINE_TABLES if tag in reader
    )


def gate_size(path, baseline):
    """Ratio of outline data, not of whole files.

    Three toy glyphs carry ~1.5 KB of fixed tables (name, cmap, OS/2) that
    dwarf their outlines, so a whole-file ratio would pass any format and
    measure nothing. The outline tables are the part that scales with the
    icon set, and the part this gate is about.
    """
    variable = outline_bytes(path)
    static = outline_bytes(baseline)
    ratio = variable / static
    verdict = "PASS" if ratio <= 1.5 else "FAIL"
    return (
        f"outlines {variable} B vs {static} B static, {ratio:.2f}x [{verdict}]"
        f"; whole file {path.stat().st_size} B",
        ratio,
    )


if __name__ == "__main__":
    failures = []
    candidates = [
        (OUT / "variable_cff2.otf", "cff", OUT / "static_2.0_cff.otf"),
        (OUT / "variable_gvar.ttf", "glyf", OUT / "static_2.0_glyf.otf"),
        (OUT / "variable_gvar_noiup.ttf", "glyf", OUT / "static_2.0_glyf.otf"),
    ]
    for path, fmt, baseline in candidates:
        print(f"\n== {path.name}")
        for gate in (
            lambda: gate_parse(path),
            lambda: gate_correctness(path, fmt),
            lambda: gate_subset(path),
            lambda: gate_size(path, baseline)[0],
        ):
            try:
                print("  ", gate())
            except Exception as error:  # noqa: BLE001 - report every gate
                print("   FAIL:", error)
                failures.append(f"{path.name}: {error}")
    sys.exit(1 if failures else 0)
