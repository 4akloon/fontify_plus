/// Metadata for a generic glyph.
class GenericGlyphMetadata {
  GenericGlyphMetadata({this.charCode, this.name});

  /// Assigned while the font is built, not while the glyph is parsed.
  int? charCode;

  String? name;

  /// Deep copy
  GenericGlyphMetadata copy() =>
      GenericGlyphMetadata(charCode: charCode, name: name);
}
