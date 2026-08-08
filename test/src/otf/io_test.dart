import 'dart:async';
import 'dart:io';

import 'package:fontify_plus/src/common/generic_glyph.dart';
import 'package:fontify_plus/src/otf/io.dart';
import 'package:fontify_plus/src/otf/otf.dart';
import 'package:test/test.dart';

OpenTypeFont _buildFont() {
  final glyph = GenericGlyph.fromSvg(
    'icon',
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
        '<path d="M0 0 L10 0 L10 10 Z"/></svg>',
  );

  return OpenTypeFont.createFromGlyphs(
    glyphList: [glyph],
    fontName: 'Test',
    useOpenType: true,
  );
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fontify_plus_io_test');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('writeToFile / readFromFile', () {
    test('round-trips a font through disk', () {
      final font = _buildFont();
      final path = '${tempDir.path}/test.otf';

      writeToFile(path, font);
      final decoded = readFromFile(path);

      expect(decoded.familyName, 'Test');
      expect(File(path).existsSync(), isTrue);
    });

    test(
      'warns when an OpenType (CFF) font is written without an .otf extension',
      () {
        final font = _buildFont();
        final path = '${tempDir.path}/test.ttf';

        final printLines = <String>[];
        runZoned(
          () => writeToFile(path, font),
          zoneSpecification: ZoneSpecification(
            print: (self, parent, zone, line) => printLines.add(line),
          ),
        );

        expect(printLines, isNotEmpty);
      },
    );
  });
}
