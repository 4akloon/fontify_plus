/// Byte encoding table — a 256-entry map, kept only for Macintosh
/// compatibility.
const kCmapFormat0 = 0;

/// Segment mapping to delta values — the BMP workhorse.
const kCmapFormat4 = 4;

/// Segmented coverage — the same idea as format 4, with 32-bit char codes.
const kCmapFormat12 = 12;
