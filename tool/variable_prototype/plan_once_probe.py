"""Phase 0 probe: would plan-once quad conversion make glyf+gvar buildable?

**This measures a technique the package does not implement.** Nothing here
reflects what `fontify_plus` emits, today or after any planned change. It
exists to answer one question that the format decision turned on, and to make
the number in README's "Results" reproducible rather than asserted.

The question. As of 0.5.2 the package's cubic->quadratic conversion runs
per glyph per width, and picks its subdivision from the geometry it is handed.
A 4% change in stroke width changes the answer, so the `glyf` masters are not
point-compatible across widths, `varLib` prints "incompatible masters;
skipping", and the glyph silently stops responding to the axis. The spec
(section 3) already names cubic->quadratic as a *third* site needing the
plan-once/evaluate-per-width discipline Phase 1 applies to the offsetter. Does
that discipline actually fix this, and what does it cost?

The stand-in. `fontTools.pens.cu2quPen.Cu2QuMultiPen` converts several
compatible cubic sources at once, choosing one segment count per curve that
satisfies the error bound for *every* source -- one plan, coordinates
evaluated per master. It is what `fontmake` uses for every TrueType variable
font it ships. It is not identical to what the spec proposes (plan at the
reference width, which is the axis maximum, and replay); cu2qu takes the
per-curve maximum over all masters instead. The two agree whenever the maximum
falls at the reference width, which is the spec's own argument for choosing
that reference. Treat the ratios below as the right order of magnitude, not as
a prediction of the package's output.

Inputs are the CFF masters from `build_masters.py`, which are point-compatible
by construction because cubics need no conversion. Run `build_masters.py`
first. Outputs land in `out/plan_once/`, which is gitignored with the rest of
`out/`.

Two baselines are reported for the size ratio, because they answer different
questions and differ by ~4 points:

- against this probe's own static 2.0 master: what a plan-once pipeline would
  cost relative to a plan-once static build. This is the apples-to-apples
  number and the one README quotes.
- against the package's `static_2.0_glyf.otf`: what a plan-once variable font
  would cost relative to the per-width static output that exists today. Lower,
  because the per-width static is more thriftily subdivided than any joint
  plan can be.

Byte counts come from `gates.outline_bytes`, so the ratios are on exactly the
same footing as the gate table.
"""

import io
import logging
import pathlib
import sys

from fontTools.designspaceLib import (
    AxisDescriptor,
    DesignSpaceDocument,
    SourceDescriptor,
)
from fontTools.pens.cu2quPen import Cu2QuMultiPen
from fontTools.pens.recordingPen import RecordingPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont, newTable
from fontTools.varLib import build as varlib_build
from fontTools.varLib.instancer import instantiateVariableFont

sys.path.insert(0, str(pathlib.Path(__file__).parent))
import gates  # noqa: E402 - same directory, and its byte counting is the point

OUT = pathlib.Path(__file__).parent / "out"
WORK = OUT / "plan_once"

WIDTHS = ["1.33", "1.5", "2.0"]
REFERENCE = "2.0"  # the axis maximum, and varLib's default instance
# Font units at upem 1000. Swept below, because a single value proves nothing.
TOLERANCES = [0.5, 1.0, 2.0, 4.0]
HEADLINE = 1.0


def convert_jointly(max_err):
    """Rebuild the three CFF masters as TrueType under ONE shared quad plan.

    Every master is drawn into a shared `Cu2QuMultiPen`, so each cubic gets a
    single segment count that holds for all three widths. Compare
    `build_masters.py`'s output, where each width is converted alone.
    """
    masters = [TTFont(OUT / f"static_{w}_cff.otf") for w in WIDTHS]
    order = masters[0].getGlyphOrder()
    glyph_sets = [m.getGlyphSet() for m in masters]
    converted = [{} for _ in masters]

    for name in order:
        # Record each master's pen ops, then replay them in lockstep. The
        # multi-pen needs all masters' arguments for one segment at once.
        records = []
        for glyph_set in glyph_sets:
            pen = RecordingPen()
            glyph_set[name].draw(pen)
            records.append(pen.value)

        operations = [[op for op, _ in record] for record in records]
        if any(ops != operations[0] for ops in operations):
            raise AssertionError(f"{name}: CFF masters are not pen-compatible")

        sinks = [TTGlyphPen(None) for _ in masters]
        multi = Cu2QuMultiPen(sinks, max_err)
        for step, (operation, _) in enumerate(records[0]):
            arguments = [record[step][1] for record in records]
            if not arguments[0]:
                getattr(multi, operation)()
            else:
                # Cu2QuMultiPen takes one argument: the per-master arg tuples.
                getattr(multi, operation)(arguments)

        for index, sink in enumerate(sinks):
            converted[index][name] = sink.glyph()

    paths = []
    for index, master in enumerate(masters):
        buffer = io.BytesIO()
        master.save(buffer)
        font = TTFont(io.BytesIO(buffer.getvalue()))
        font.setGlyphOrder(order)
        metrics = dict(font["hmtx"].metrics)

        del font["CFF "]
        glyf = newTable("glyf")
        glyf.glyphOrder = order
        glyf.glyphs = converted[index]
        font["glyf"] = glyf
        font["loca"] = newTable("loca")
        font.sfntVersion = "\x00\x01\x00\x00"
        font["head"].indexToLocFormat = 0
        font["head"].glyphDataFormat = 0

        maxp = font["maxp"]
        maxp.tableVersion = 0x00010000
        for field, value in (
            ("maxZones", 1),
            ("maxTwilightPoints", 0),
            ("maxStorage", 0),
            ("maxFunctionDefs", 0),
            ("maxInstructionDefs", 0),
            ("maxStackElements", 0),
            ("maxSizeOfInstructions", 0),
            ("maxComponentElements", 0),
            ("maxComponentDepth", 0),
        ):
            setattr(maxp, field, value)

        # TrueType requires lsb == xMin; 0.5.2 fixed the package's own writer
        # for exactly this, and a probe that got it wrong would reintroduce
        # the phantom-point shift that muddied the Task 4 matrix.
        hmtx = font["hmtx"]
        for name in order:
            glyph = glyf[name]
            glyph.recalcBounds(glyf)
            hmtx[name] = (metrics[name][0], getattr(glyph, "xMin", 0))

        WORK.mkdir(parents=True, exist_ok=True)
        path = WORK / f"joint_{WIDTHS[index]}_{max_err}_glyf.ttf"
        font.save(path)
        paths.append(path)
    return paths


def point_counts(path):
    font = TTFont(path)
    return {
        name: (
            0
            if font["glyf"][name].numberOfContours == 0
            else len(font["glyf"][name].coordinates)
        )
        for name in font.getGlyphOrder()
    }


def merge(paths, max_err):
    """Same two-master, default-at-maximum design space as build_variable.py."""
    document = DesignSpaceDocument()
    axis = AxisDescriptor()
    axis.tag, axis.name = "wght", "Weight"
    axis.minimum, axis.maximum, axis.default = 1.33, 2.0, 2.0
    document.addAxis(axis)

    for width, path in zip(WIDTHS, paths):
        if width not in ("1.33", REFERENCE):
            continue  # two masters, matching build_variable.py
        source = SourceDescriptor()
        source.path = str(path)
        source.font = TTFont(path)
        source.location = {"Weight": float(width)}
        source.copyInfo = width == REFERENCE
        document.addSource(source)

    warnings = []

    class Capture(logging.Handler):
        def emit(self, record):
            if record.levelno >= logging.WARNING:
                warnings.append(record.getMessage())

    handler = Capture()
    logging.getLogger("fontTools").addHandler(handler)
    try:
        variable, _, _ = varlib_build(document, optimize=True)
    finally:
        logging.getLogger("fontTools").removeHandler(handler)

    path = WORK / f"joint_variable_{max_err}_gvar.ttf"
    variable.save(path)
    return path, warnings


def worst_deviation(variable_path, static_paths):
    """gates.gate_correctness, against this probe's own static masters."""
    worst = 0.0
    for width, static_path in zip(WIDTHS, static_paths):
        instance = instantiateVariableFont(
            TTFont(variable_path), {"wght": float(width)}
        )
        buffer = io.BytesIO()
        instance.save(buffer)
        instance = TTFont(io.BytesIO(buffer.getvalue()))

        static = TTFont(static_path)
        for name in static.getGlyphOrder():
            if name in (".notdef", "space"):
                continue
            a = gates.outlines(instance, name)
            b = gates.outlines(static, name)
            if len(a) != len(b):
                raise AssertionError(f"@{width} {name}: {len(a)} points vs {len(b)}")
            worst = max(worst, max((abs(x - y) for x, y in zip(a, b)), default=0))
    return worst


def main():
    print("== point counts, per-width conversion (what the package emits) ==")
    for width in WIDTHS:
        print(f"  {width:5}", point_counts(OUT / f"static_{width}_glyf.otf"))

    package_baseline = gates.outline_bytes(OUT / f"static_{REFERENCE}_glyf.otf")

    for max_err in TOLERANCES:
        paths = convert_jointly(max_err)
        counts = [point_counts(path) for path in paths]
        names = [n for n in counts[0] if n != "space"]
        incompatible = [n for n in names if len({c[n] for c in counts}) != 1]

        print(f"\n== joint (plan-once) conversion, max_err {max_err} ==")
        for name in names:
            values = [c[name] for c in counts]
            flag = "MISMATCH" if name in incompatible else "OK"
            print(f"  {name:10} {values}  {flag}")

        if incompatible:
            print("  plan-once did NOT restore compatibility; stopping")
            return 1

        variable, warnings = merge(paths, max_err)
        print("  varLib warnings:", warnings or "none")

        font = TTFont(variable)
        varying = [
            name
            for name in font.getGlyphOrder()
            if any(
                any(d is not None and d != (0, 0) for d in tuple_.coordinates)
                for tuple_ in font["gvar"].variations.get(name, [])
            )
        ]
        print("  glyphs carrying deltas:", varying)

        worst = worst_deviation(variable, paths)
        verdict = "PASS" if worst <= gates.TOLERANCE else "FAIL"
        print(
            f"  correctness worst {worst:.2f} units "
            f"[{verdict}, tolerance {gates.TOLERANCE}]"
        )

        scaling = gates.outline_bytes(variable)
        own = gates.outline_bytes(paths[WIDTHS.index(REFERENCE)])
        print(
            f"  size vs own plan-once static {REFERENCE}: "
            f"{scaling} vs {own} = {scaling / own:.2f}x"
        )
        print(
            f"  size vs package per-width static {REFERENCE}: "
            f"{scaling} vs {package_baseline} = {scaling / package_baseline:.2f}x"
        )
        if max_err == HEADLINE:
            print("  ^ the figures README quotes")

    return 0


if __name__ == "__main__":
    sys.exit(main())
