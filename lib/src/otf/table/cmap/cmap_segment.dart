/// A run of consecutive character codes mapping to consecutive glyph IDs.
///
/// Both cmap formats this package writes store the map as runs rather than
/// per-character entries, so the same segment list feeds both.
class CmapSegment {
  CmapSegment({
    required this.startCode,
    required this.endCode,
    required this.startGlyphID,
  });

  final int startCode;
  final int endCode;
  final int startGlyphID;

  int get idDelta => startGlyphID - startCode;
}

/// Groups [charCodeList] into the longest possible runs.
///
/// The list is in glyph order, so a run breaks wherever the char codes stop
/// being consecutive.
List<CmapSegment> generateSegments(List<int> charCodeList) {
  var startCharCode = -1;
  var prevCharCode = -1;
  var startGlyphId = -1;

  final segmentList = <CmapSegment>[];

  void saveSegment() {
    segmentList.add(
      CmapSegment(
        startCode: startCharCode,
        endCode: prevCharCode,
        startGlyphID: startGlyphId + 1, // +1 because of .notdef
      ),
    );
  }

  for (var glyphId = 0; glyphId < charCodeList.length; glyphId++) {
    final charCode = charCodeList[glyphId];

    if (prevCharCode + 1 != charCode && startCharCode != -1) {
      // Save a segment, if there's a gap between previous and current codes
      saveSegment();

      // Next segment starts with new code
      startCharCode = charCode;
      startGlyphId = glyphId;
    } else if (startCharCode == -1) {
      // Start a new segment
      startCharCode = charCode;
      startGlyphId = glyphId;
    }

    prevCharCode = charCode;
  }

  // Closing the last segment
  if (startCharCode != -1 && prevCharCode != -1) {
    saveSegment();
  }

  return segmentList;
}
