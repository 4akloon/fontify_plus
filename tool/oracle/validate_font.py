"""Validates a generated font against fonttools, an independent implementation.

CAVEAT: the variable-font branch below (the `if "fvar" not in font` check)
is exercised in CI only by example/fonts/proto/variable_cff2.otf, which was
built by fontTools' own varLib, not by this package -- fontify_plus does not
emit fvar/STAT yet (see lib/src/otf/otf.dart's _kTableTagsToEncode and
lib/src/otf/reader.dart's _createTableFromEntry, neither of which is wired
for those tags). So today this branch is fontTools validating fontTools; it
cannot go red for anything fontify_plus does. It becomes a real gate once
Phase 4 wires fvar/STAT into the builder and this script runs against a
variable font fontify_plus generated itself.
"""
import io
import sys

from fontTools.ttLib import TTFont


def validate(path):
    font = TTFont(path)

    buffer = io.BytesIO()
    font.save(buffer)
    TTFont(io.BytesIO(buffer.getvalue()))

    if "fvar" not in font:
        return "static font, parses and round-trips"

    axis = font["fvar"].axes[0]
    if "STAT" not in font:
        raise AssertionError("variable font without a STAT table")
    if axis.minValue >= axis.maxValue:
        raise AssertionError(f"empty axis range {axis.minValue}-{axis.maxValue}")

    return (
        f"variable font, axis {axis.axisTag} "
        f"{axis.minValue}-{axis.maxValue} default {axis.defaultValue}"
    )


if __name__ == "__main__":
    for path in sys.argv[1:]:
        try:
            print(f"{path}: {validate(path)}")
        except Exception as error:  # noqa: BLE001 - report every font
            print(f"{path}: FAIL {error}")
            sys.exit(1)
