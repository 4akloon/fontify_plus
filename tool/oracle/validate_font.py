"""Validates a generated font against fonttools, an independent implementation.

Usage: validate_font.py [--variable] FONT [FONT ...]

`--variable` asserts that every font listed really is variable, so that a
build which quietly produced a static font fails here instead of passing as
"static font, parses and round-trips".

SCOPE: this reads the variation *metadata* back with an implementation that
is not this package's, and checks that the whole font survives a save/reload
round trip. It does not instance the font and compare outlines against
separately built static masters, subset it, or run it through OTS -- those
are Task 24's, and until they land a font whose blend deltas are wrong still
passes here.

HISTORY: this branch used to be unable to go red for anything fontify_plus
did, because the package emitted no fvar/STAT and the only variable fixture
was one varLib built. Phase 4 changed the first half -- the builder now
writes CFF2, fvar and STAT, and this script has been run by hand against a
font it produced. CI still feeds it example/fonts/proto/variable_cff2.otf;
replacing that fixture with the package's own output is Task 24 too.
"""
import io
import sys

from fontTools.ttLib import TTFont


def validate(path, require_variable=False):
    font = TTFont(path)

    buffer = io.BytesIO()
    font.save(buffer)
    TTFont(io.BytesIO(buffer.getvalue()))

    if "fvar" not in font:
        if require_variable:
            raise AssertionError("no fvar table, so this font is static")
        return "static font, parses and round-trips"

    axis = font["fvar"].axes[0]
    if "STAT" not in font:
        raise AssertionError("variable font without a STAT table")
    if axis.minValue >= axis.maxValue:
        raise AssertionError(f"empty axis range {axis.minValue}-{axis.maxValue}")

    # OTS rejects a variable font whose axisNameID resolves to nothing, and a
    # font picker showing a blank axis label is the visible symptom.
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


if __name__ == "__main__":
    arguments = sys.argv[1:]
    options = [a for a in arguments if a.startswith("--")]
    paths = [a for a in arguments if not a.startswith("--")]

    unknown = [a for a in options if a != "--variable"]
    if unknown or not paths:
        print(f"usage: {sys.argv[0]} [--variable] FONT [FONT ...]")
        sys.exit(2)

    for path in paths:
        try:
            print(f"{path}: {validate(path, '--variable' in options)}")
        except Exception as error:  # noqa: BLE001 - report every font
            print(f"{path}: FAIL {error}")
            sys.exit(1)
