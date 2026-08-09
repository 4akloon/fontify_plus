import '../common/generic_glyph.dart';

/// How a glyph is fitted onto the em square.
///
/// Replaces a nullable ascender/descender/fontHeight triple that could only be
/// checked at runtime: each way of fitting now carries exactly the values it
/// needs, so an inconsistent combination cannot be expressed.
abstract class GlyphFitting {
  const GlyphFitting();

  GenericGlyph fit(GenericGlyph glyph);
}

/// Scales each glyph so its own longest side fills the em band, then centres
/// it.
///
/// Discards how much of its artboard an icon was drawn to occupy, which is
/// design information — a full-bleed circle and a small arrow end up the same
/// size. Only appropriate for icons collected from mismatched sources.
class NormalizedFitting extends GlyphFitting {
  const NormalizedFitting({required this.ascender, required this.descender});

  final int ascender;
  final int descender;

  @override
  GenericGlyph fit(GenericGlyph glyph) => glyph
      .resize(ascender: ascender, descender: descender)
      .center(ascender, descender);
}

/// Maps each glyph's artboard onto the em square.
///
/// The relative sizes the icons were drawn at survive, which is what an icon
/// set almost always wants.
class ArtboardFitting extends GlyphFitting {
  const ArtboardFitting({required this.fontHeight});

  final int fontHeight;

  @override
  GenericGlyph fit(GenericGlyph glyph) => glyph.resize(fontHeight: fontHeight);
}
