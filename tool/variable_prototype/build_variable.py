"""Merges the static masters into variable fonts, one per candidate format."""
import pathlib

from fontTools.designspaceLib import AxisDescriptor, DesignSpaceDocument, SourceDescriptor
from fontTools.varLib import build

OUT = pathlib.Path(__file__).parent / "out"
MIN, MAX = 1.33, 2.0


def designspace(fmt):
    doc = DesignSpaceDocument()

    axis = AxisDescriptor()
    axis.name = "Weight"
    axis.tag = "wght"
    axis.minimum, axis.default, axis.maximum = MIN, MAX, MAX
    doc.addAxis(axis)

    for width in (MIN, MAX):
        source = SourceDescriptor()
        source.path = str(OUT / f"static_{width}_{fmt}.otf")
        source.location = {"Weight": width}
        if width == MAX:
            source.copyInfo = True
        doc.addSource(source)

    return doc


def emit(fmt, filename, optimize=True):
    font, _, _ = build(designspace(fmt), optimize=optimize)
    path = OUT / filename
    font.save(path)
    return path


if __name__ == "__main__":
    print("CFF2   ", emit("cff", "variable_cff2.otf"))
    print("gvar   ", emit("glyf", "variable_gvar.ttf"))
    print("gvar-  ", emit("glyf", "variable_gvar_noiup.ttf", optimize=False))
