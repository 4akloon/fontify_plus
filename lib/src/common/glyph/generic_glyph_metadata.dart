/// Metadata for a generic glyph.
class GenericGlyphMetadata {
  GenericGlyphMetadata({this.charCode, this.name, this.preview});

  /// Assigned while the font is built, not while the glyph is parsed.
  int? charCode;

  String? name;

  /// Minified SVG source, for dartdoc previews.
  String? preview;

  /// Deep copy
  GenericGlyphMetadata copy() =>
      GenericGlyphMetadata(charCode: charCode, name: name, preview: preview);
}
