import 'package:fontify_plus/src/common/generic_glyph.dart';
import 'package:fontify_plus/src/otf/otf.dart';
import 'package:fontify_plus/src/otf/writer.dart';
import 'package:fontify_plus/src/svg/svg.dart';
import 'package:test/test.dart';

OpenTypeFont _buildFont() {
  final svg = Svg.parse(
    'icon',
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
        '<path d="M0 0 L10 0 L10 10 Z"/></svg>',
  );

  return OpenTypeFont.createFromGlyphs(
    glyphList: [GenericGlyph.fromSvg(svg)],
    fontName: 'Test',
  );
}

void main() {
  group('OTFWriter.write', () {
    test('produces exactly font.size bytes', () {
      final font = _buildFont();

      final bytes = OTFWriter().write(font);

      expect(bytes.lengthInBytes, font.size);
    });

    test('writes the offset table\'s sfnt version at the very start', () {
      final font = _buildFont();

      final bytes = OTFWriter().write(font);

      expect(bytes.getUint32(0), font.offsetTable.sfntVersion);
    });
  });
}
