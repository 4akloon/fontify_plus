"""Prototype SVGs whose two masters are point-compatible by construction."""
import math

VIEWBOX = 24
# Circle-to-cubic constant: handle length for a 90 degree arc.
K = 4 / 3 * math.tan(math.pi / 8)


def _circle_path(cx, cy, r):
    """A circle as four cubic arcs, always four segments regardless of r."""
    h = r * K
    return (
        f"M{cx} {cy - r:.4f}"
        f"C{cx + h:.4f} {cy - r:.4f} {cx + r:.4f} {cy - h:.4f} {cx + r:.4f} {cy}"
        f"C{cx + r:.4f} {cy + h:.4f} {cx + h:.4f} {cy + r:.4f} {cx} {cy + r:.4f}"
        f"C{cx - h:.4f} {cy + r:.4f} {cx - r:.4f} {cy + h:.4f} {cx - r:.4f} {cy}"
        f"C{cx - r:.4f} {cy - h:.4f} {cx - h:.4f} {cy - r:.4f} {cx} {cy - r:.4f}Z"
    )


def _svg(body):
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" '
        f'viewBox="0 0 {VIEWBOX} {VIEWBOX}" fill="none">{body}</svg>'
    )


def plus(width):
    """Straight strokes only: never subdivided, so compatible at any width."""
    return _svg(
        f'<path d="M12 5V19M5 12H19" stroke="#000" stroke-width="{width}" '
        f'stroke-linecap="round"/>'
    )


def ring(width):
    """Pre-offset circle: the stroke band drawn as two filled contours.

    Offsetting is done here rather than by fontify_plus so both masters have
    four arcs per contour whatever the width.
    """
    outer = _circle_path(12, 12, 8 + width / 2)
    inner = _circle_path(12, 12, 8 - width / 2)
    return _svg(f'<path d="{outer}{inner}" fill="#000" fill-rule="evenodd"/>')


def dot(width):
    """A fill: identical in every master, so all of its deltas are zero."""
    del width
    return _svg(f'<path d="{_circle_path(12, 12, 4)}" fill="#000"/>')


GLYPHS = {"plus": plus, "ring": ring, "dot": dot}
