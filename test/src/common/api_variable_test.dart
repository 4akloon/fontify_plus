import 'dart:convert';
import 'dart:typed_data';

import 'package:fontify_plus/src/common/api.dart';
import 'package:fontify_plus/src/common/glyph/glyph_masters.dart';
import 'package:fontify_plus/src/common/stroke_width_range.dart';
import 'package:fontify_plus/src/job/fontify_exception.dart';
import 'package:fontify_plus/src/otf/otf.dart';
import 'package:fontify_plus/src/otf/writer.dart';
import 'package:fontify_plus/src/utils/otf.dart';
import 'package:test/test.dart';

const _strokedSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">'
    '<path d="M12 5V19M5 12H19" stroke="#000" stroke-width="1.5" '
    'stroke-linecap="round"/></svg>';

const _otherStrokedSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">'
    '<path d="M5 12L10 17L19 8" stroke="#000" stroke-width="1.5" '
    'stroke-linecap="round" stroke-linejoin="round"/></svg>';

/// An interior width for the three-master tests, strictly inside the range
/// every test here builds against.
const _defaultWidth = 1.5;

/// Every table in an encoded font, as a view over the bytes actually written.
///
/// The tests below read `fvar` and `STAT` back out of the SFNT rather than off
/// the in-memory table objects. Those objects are the two things a caller
/// hands the same value to, so comparing them can only ever confirm that one
/// variable reached two constructors — the failure this guards against is the
/// value reaching only one *encoder*, which is visible only in the bytes.
Map<String, ByteData> _tablesOf(ByteData font) {
  final numTables = font.getUint16(4);
  final tables = <String, ByteData>{};

  for (var i = 0; i < numTables; i++) {
    final entry = 12 + i * 16;
    final tag = String.fromCharCodes([
      for (var c = 0; c < 4; c++) font.getUint8(entry + c),
    ]);
    final offset = font.getUint32(entry + 8);
    final length = font.getUint32(entry + 12);

    tables[tag] = ByteData.sublistView(font, offset, offset + length);
  }

  return tables;
}

/// `fvar`'s three axis coordinates — minimum, default, maximum — in the raw
/// 16.16 fixed point the table stores, undivided so that a comparison against
/// `STAT` is exact rather than merely close.
({int min, int fixedDefault, int max}) _fvarAxis(ByteData fvar) {
  const axesArray = 16;

  expect(fvar.getUint16(8), 1, reason: 'expected exactly one axis');

  return (
    min: fvar.getInt32(axesArray + 4),
    fixedDefault: fvar.getInt32(axesArray + 8),
    max: fvar.getInt32(axesArray + 12),
  );
}

/// Every coordinate `STAT` names a format 1 axis value at, in raw 16.16,
/// followed through the table's own offset array rather than assumed
/// contiguous.
List<int> _statAxisValues(ByteData stat) {
  final axisValueCount = stat.getUint16(12);
  final offsetToAxisValueOffsets = stat.getUint32(14);

  return [
    for (var i = 0; i < axisValueCount; i++)
      stat.getInt32(
        offsetToAxisValueOffsets +
            stat.getUint16(offsetToAxisValueOffsets + i * 2) +
            8,
      ),
  ];
}

void main() {
  group('svgToOtf with strokeWidthRange', () {
    test('a range without stroke outlining is an error, not a warning', () {
      // There is nothing to vary: outlineStrokes: false treats path data as
      // fill geometry, and a fill does not depend on stroke width. Silently
      // producing a font whose axis moves nothing is the worst outcome.
      expect(
        () => svgToOtf(
          svgMap: {'a': _strokedSvg},
          outlineStrokes: false,
          strokeWidthRange: StrokeWidthRange(1.33, 2),
        ),
        throwsA(
          isA<FontifyException>().having(
            (e) => e.message,
            'message',
            contains('outlineStrokes'),
          ),
        ),
      );
    });

    test('a range with TrueType outlines is an error', () {
      expect(
        () => svgToOtf(
          svgMap: {'a': _strokedSvg},
          useOpenType: false,
          strokeWidthRange: StrokeWidthRange(1.33, 2),
        ),
        throwsA(
          isA<FontifyException>().having(
            (e) => e.message,
            'message',
            contains('useOpenType'),
          ),
        ),
      );
    });

    test('a range with the defaults left null builds normally', () {
      // outlineStrokes: null and useOpenType: null mean "use the default",
      // which is true for both — validation must not mistake "unset" for
      // "false".
      expect(
        () => svgToOtf(
          svgMap: {'a': _strokedSvg},
          strokeWidthRange: StrokeWidthRange(1.33, 2),
        ),
        returnsNormally,
      );
    });

    test('builds a variable font with both masters', () {
      final result = svgToOtf(
        svgMap: {'a': _strokedSvg},
        strokeWidthRange: StrokeWidthRange(1.33, 2),
      );

      expect(result.font.tableMap.containsKey(kFvarTag), isTrue);
      expect(result.font.tableMap.containsKey(kCFF2Tag), isTrue);
    });

    test('without a range nothing about the output changes', () {
      final result = svgToOtf(svgMap: {'a': _strokedSvg});

      expect(result.font.tableMap.containsKey(kFvarTag), isFalse);
      expect(result.font.tableMap.containsKey(kCFFTag), isTrue);
    });

    test('the default instance is built from the maximum-width master', () {
      // Regression guard: swapping `glyphList = masters.min` / `minGlyphList
      // = masters.max` in svgToOtf leaves every other assertion in this
      // file, the full suite, byte identity and even the oracle's
      // "default 2.0" report green — none of them look at *which* geometry
      // the default instance actually draws, only that a default exists.
      // `createFromGlyphs` only mutates `glyphList`'s glyph *metadata*
      // (assigning charcodes), never its outlines, so `result.glyphList`'s
      // points survive unfitted and can be compared directly against a
      // freshly built, unfitted `max` master.
      final range = StrokeWidthRange(1.33, 2);
      final result = svgToOtf(
        svgMap: {'a': _strokedSvg},
        strokeWidthRange: range,
      );
      final direct = GlyphMasterBuilder(range).fromSvg('a', _strokedSvg);

      expect(result.glyphList.single.pointList, direct.max.pointList);
      expect(
        result.glyphList.single.pointList,
        isNot(equals(direct.min.pointList)),
      );
    });

    test(
      'generateFlutterClass sees a charcode on every range-built glyph',
      () {
        // Regression guard: `_generateCharCodes` (otf_builder.dart) writes
        // charcodes only onto the list handed to `createFromGlyphs` as
        // `glyphList`. If `svgToOtf` ever returned `minGlyphList` as
        // `result.glyphList` instead — same length, same order, so every
        // other assertion here would still pass — `generateFlutterClass`
        // would silently emit a class with zero `IconData` constants: no
        // error, no warning.
        final result = svgToOtf(
          svgMap: {'a': _strokedSvg, 'b': _strokedSvg},
          strokeWidthRange: StrokeWidthRange(1.33, 2),
        );

        expect(
          result.glyphList.map((g) => g.metadata.charCode),
          everyElement(isNotNull),
        );

        final source = generateFlutterClass(
          glyphList: result.glyphList,
          className: 'RangeIcons',
          familyName: result.font.familyName,
        );

        expect('static const IconData'.allMatches(source), hasLength(2));
      },
    );
  });

  group('svgToOtf with defaultStrokeWidth', () {
    test('a default width without a range is an error naming the value', () {
      // A width names a point *on* an axis. With no `strokeWidthRange` the
      // static path runs, writing neither `fvar` nor `STAT`, and the value
      // would be dropped without a word.
      expect(
        () => svgToOtf(
          svgMap: {'a': _strokedSvg},
          defaultStrokeWidth: _defaultWidth,
        ),
        throwsA(
          isA<FontifyException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('defaultStrokeWidth'),
              contains('strokeWidthRange'),
              contains('$_defaultWidth'),
            ),
          ),
        ),
      );
    });

    test('a default width at an endpoint is an error naming the value', () {
      // Strict on both sides: at an endpoint the third master duplicates the
      // endpoint master it sits on, so the font pays for a second variation
      // region to describe a width it already had, and `STAT` names two axis
      // values at one coordinate.
      for (final bad in [1.33, 2.0]) {
        expect(
          () => svgToOtf(
            svgMap: {'a': _strokedSvg},
            strokeWidthRange: StrokeWidthRange(1.33, 2),
            defaultStrokeWidth: bad,
          ),
          throwsA(
            isA<FontifyException>().having(
              (e) => e.message,
              'message',
              allOf(contains('defaultStrokeWidth'), contains('$bad')),
            ),
          ),
          reason: 'defaultStrokeWidth $bad',
        );
      }
    });

    test('a default width outside the range is an error, NaN included', () {
      // NaN loses every ordering test it is given, so a pair of `<`
      // comparisons written the obvious way would let it through and only
      // surface as a bare `UnsupportedError` from `fvar`'s 16.16 conversion,
      // three layers down.
      for (final bad in [1.0, 2.5, double.nan]) {
        expect(
          () => svgToOtf(
            svgMap: {'a': _strokedSvg},
            strokeWidthRange: StrokeWidthRange(1.33, 2),
            defaultStrokeWidth: bad,
          ),
          throwsA(
            isA<FontifyException>().having(
              (e) => e.message,
              'message',
              contains('defaultStrokeWidth'),
            ),
          ),
          reason: 'defaultStrokeWidth $bad',
        );
      }
    });

    test('the misconfiguration surfaces as this API\'s own exception type', () {
      // `OpenTypeFontBuilder` checks the same rules and throws
      // `ArgumentError`, which is right for a builder handed a bad argument
      // but wrong here: a caller of `svgToOtf` should get the vocabulary its
      // `outlineStrokes` and `useOpenType` conflicts already speak, and the
      // one the CLI's error reporting knows how to render. Delegating would
      // change the type without changing any other assertion in this file.
      expect(
        () => svgToOtf(
          svgMap: {'a': _strokedSvg},
          strokeWidthRange: StrokeWidthRange(1.33, 2),
          defaultStrokeWidth: 2,
        ),
        throwsA(isNot(isA<ArgumentError>())),
      );
    });

    test('an interior default builds a three-master variable font', () {
      final result = svgToOtf(
        svgMap: {'a': _strokedSvg},
        strokeWidthRange: StrokeWidthRange(1.33, 2),
        defaultStrokeWidth: _defaultWidth,
      );

      expect(result.font.tableMap, contains(kCFF2Tag));
      expect(result.font.tableMap, isNot(contains(kCFFTag)));

      // The two-region store is the whole point of routing `maxGlyphList`
      // through: with one region the scalar is zero above the default, so
      // every width in (1.5, 2.0] would render identically to 1.5 while
      // `fvar` went on declaring a maximum.
      expect(
        result.font.cff2!.vstoreData!.store.variationRegionList.regionCount,
        2,
      );
    });

    test('the encoded fvar and STAT agree on the interior default', () {
      // Read out of the written bytes, not off the table objects: passing one
      // variable into two `create` calls proves nothing about what each of
      // them encoded. Compared as raw 16.16 integers so the agreement is
      // exact.
      final result = svgToOtf(
        svgMap: {'a': _strokedSvg},
        strokeWidthRange: StrokeWidthRange(1.33, 2),
        defaultStrokeWidth: _defaultWidth,
      );

      final tables = _tablesOf(OTFWriter().write(result.font));

      expect(tables, contains(kFvarTag));
      expect(tables, contains(kStatTag));

      final axis = _fvarAxis(tables[kFvarTag]!);
      final statValues = _statAxisValues(tables[kStatTag]!);

      expect(axis.fixedDefault, (_defaultWidth * 65536).round());
      expect(axis.min, (1.33 * 65536).round());
      expect(axis.max, (2.0 * 65536).round());

      // `STAT` names every width the font distinguishes, and the default has
      // to be among them: it is the instance a font picker opens on, so a
      // `STAT` that omits it leaves the one width users see first unnamed.
      expect(statValues, [axis.min, axis.fixedDefault, axis.max]);
    });

    test('the default instance is the interior master, not the maximum', () {
      // The mistake this catches — routing `m.max` into `glyphList` and
      // dropping `atDefault` — leaves `fvar`, `STAT`, the region count and
      // the whole suite green: nothing else looks at *which* drawing the
      // default instance carries. `createFromGlyphs` mutates only metadata,
      // so these points survive unfitted and compare directly against a
      // freshly built master.
      final range = StrokeWidthRange(1.33, 2);
      final result = svgToOtf(
        svgMap: {'a': _strokedSvg},
        strokeWidthRange: range,
        defaultStrokeWidth: _defaultWidth,
      );

      final direct = GlyphMasterBuilder(
        range,
        defaultWidth: _defaultWidth,
      ).fromSvg('a', _strokedSvg);

      expect(result.glyphList.single.pointList, direct.atDefault!.pointList);
      expect(
        result.glyphList.single.pointList,
        isNot(equals(direct.max.pointList)),
      );
      expect(
        result.glyphList.single.pointList,
        isNot(equals(direct.min.pointList)),
      );
    });

    test('charcodes and previews land on the returned default master', () {
      // `_generateCharCodes` writes onto whichever list is handed to
      // `createFromGlyphs` as `glyphList`, and with an interior default that
      // is now the `atDefault` master rather than the `max` one. The preview
      // blobs are attached in `svgToOtf` to the same list, so both have to
      // still be on the glyphs `SvgToOtfResult` returns — otherwise
      // `generateFlutterClass` emits a class with no constants and no docs,
      // silently.
      final svgMap = {'a': _strokedSvg, 'b': _otherStrokedSvg};
      final result = svgToOtf(
        svgMap: svgMap,
        strokeWidthRange: StrokeWidthRange(1.33, 2),
        defaultStrokeWidth: _defaultWidth,
      );

      expect(
        result.glyphList.map((g) => g.metadata.charCode),
        everyElement(isNotNull),
      );
      expect(
        result.glyphList.map((g) => g.metadata.preview),
        [for (final svg in svgMap.values) base64Encode(utf8.encode(svg))],
      );

      final source = generateFlutterClass(
        glyphList: result.glyphList,
        className: 'DefaultIcons',
        familyName: result.font.familyName,
      );

      expect('static const IconData'.allMatches(source), hasLength(2));
    });

    test('omitting it reproduces the pre-existing two-master bytes', () {
      // The reference below is the exact pipeline `svgToOtf` ran before
      // `defaultStrokeWidth` existed: two masters, `glyphList` at the
      // maximum, no `maxGlyphList`, no default width. Byte equality — not
      // table presence — is what rules out the new parameter perturbing the
      // old path, since `null` flowing into `GlyphMasterBuilder`,
      // `maxGlyphList` or `fvar` would still produce a font that builds.
      final svgMap = {'a': _strokedSvg, 'b': _otherStrokedSvg};
      final range = StrokeWidthRange(1.33, 2);

      final masters = [
        for (final e in svgMap.entries)
          GlyphMasterBuilder(range).fromSvg(e.key, e.value),
      ];

      final reference = OpenTypeFont.createFromGlyphs(
        glyphList: [for (final m in masters) m.max],
        normalize: true,
        usePostV2: false,
        minGlyphList: [for (final m in masters) m.min],
        strokeWidthRange: range,
      );

      final actual = svgToOtf(svgMap: svgMap, strokeWidthRange: range).font;

      expect(
        OTFWriter().write(actual).buffer.asUint8List(),
        OTFWriter().write(reference).buffer.asUint8List(),
      );
    });
  });
}
