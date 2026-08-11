// A variable font assembled from two masters. Every piece — point-compatible
// masters, blended CFF2 charstrings, the variation store, `fvar`, `STAT`, the
// axis name record — was built and tested separately; this is the first test
// that puts them together and looks at the result.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fontify_plus/src/common/generic_glyph.dart';
import 'package:fontify_plus/src/common/stroke_width_range.dart';
import 'package:fontify_plus/src/otf/defaults.dart';
import 'package:fontify_plus/src/otf/glyph_fitting.dart';
import 'package:fontify_plus/src/otf/otf.dart';
import 'package:fontify_plus/src/otf/table/all.dart';
import 'package:fontify_plus/src/otf/writer.dart';
import 'package:fontify_plus/src/utils/otf.dart';
import 'package:test/test.dart';

/// The stroke widths the design system in `doc/` names, and the range every
/// test here builds against.
final _range = StrokeWidthRange(1.33, 2);

/// The two default glyphs (`.notdef`, `space`) every font starts with, so
/// the first icon in a font built from one SVG is glyph 2.
const _firstIconGlyphIndex = 2;

String _svg(String name) => File('example/svg/$name.svg').readAsStringSync();

/// Builds a variable font from one SVG's two masters.
OpenTypeFont _variableFontFrom(
  String name,
  String xmlString, {
  bool? normalize,
}) => _variableFontFromAll({name: xmlString}, normalize: normalize);

/// Builds a variable font from several SVGs' masters, in the given order.
OpenTypeFont _variableFontFromAll(
  Map<String, String> svgMap, {
  bool? normalize,
}) {
  final masters = [
    for (final entry in svgMap.entries)
      GlyphMasterBuilder(_range).fromSvg(entry.key, entry.value),
  ];

  return OpenTypeFont.createFromGlyphs(
    glyphList: [for (final m in masters) m.max],
    minGlyphList: [for (final m in masters) m.min],
    strokeWidthRange: _range,
    fontName: 'Variable Icons',
    normalize: normalize,
  );
}

/// Every icon in `example/svg`, in the order the checked-in font uses.
Map<String, String> _exampleSvgs() => {
  for (final name in ['arrow_right', 'plus', 'check', 'menu']) name: _svg(name),
};

// ---------------------------------------------------------------------------
// A CFF2 charstring reader, just wide enough for what this package writes.
//
// The fitted masters are not reachable from the built font any other way: the
// only place the *minimum* master's geometry survives is the blend deltas
// inside the charstrings, since `head`, `hhea` and `hmtx` are all computed
// from the default master alone (deliberately — see `otf_builder.dart`). So
// the test that matters most here has to read the charstrings back.
//
// This deliberately supports only the operators
// `char_string_form.dart` can emit — `r/h/v moveto`, `r/h/v lineto`,
// `rrcurveto`, `vvcurveto`, `hhcurveto` and `blend` — and throws on anything
// else, so that an encoder change this reader cannot follow fails loudly
// instead of yielding a plausible wrong box.
// ---------------------------------------------------------------------------

/// The bounding box of one master's points, in font units.
///
/// Not [math.Rectangle]: font coordinates run y-up, so that class's `top` and
/// `bottom` would name the wrong edges.
class _InkBox {
  const _InkBox({
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
  });

  final double xMin;
  final double xMax;
  final double yMin;
  final double yMax;

  double get centreX => (xMin + xMax) / 2;

  double get centreY => (yMin + yMax) / 2;

  double get longestSide => math.max(xMax - xMin, yMax - yMin);
}

/// The ink box every master of one CFF2 [charString] draws.
///
/// Entry 0 is the default master; entry `r + 1` is the master reached by
/// setting region `r`'s scalar to 1, which for this package's single-region
/// store is the axis minimum. Boxes are measured over *every* point including
/// off-curve control points, matching what [GenericGlyph.metrics] measures, so
/// the two are directly comparable.
List<_InkBox> _masterInkBoxes(Uint8List charString, int masterCount) {
  final regionCount = masterCount - 1;
  final view = ByteData.sublistView(charString);

  final x = List<double>.filled(masterCount, 0);
  final y = List<double>.filled(masterCount, 0);
  final xMin = List<double>.filled(masterCount, double.infinity);
  final yMin = List<double>.filled(masterCount, double.infinity);
  final xMax = List<double>.filled(masterCount, double.negativeInfinity);
  final yMax = List<double>.filled(masterCount, double.negativeInfinity);

  // One entry per operand on the argument stack; one value per master. A
  // literal pushes the same value for every master, a `blend` replaces the
  // literals it consumes with per-master values.
  var stack = <List<double>>[];

  void push(double value) => stack.add(List<double>.filled(masterCount, value));

  void step(int m, double dx, double dy) {
    x[m] += dx;
    y[m] += dy;
    xMin[m] = math.min(xMin[m], x[m]);
    xMax[m] = math.max(xMax[m], x[m]);
    yMin[m] = math.min(yMin[m], y[m]);
    yMax[m] = math.max(yMax[m], y[m]);
  }

  void curve(int m, List<double> d) {
    step(m, d[0], d[1]);
    step(m, d[2], d[3]);
    step(m, d[4], d[5]);
  }

  void draw(int operator) {
    for (var m = 0; m < masterCount; m++) {
      final a = [for (final operand in stack) operand[m]];

      switch (operator) {
        case 21: // rmoveto
          step(m, a[0], a[1]);
        case 22: // hmoveto
          step(m, a[0], 0);
        case 4: // vmoveto
          step(m, 0, a[0]);
        case 5: // rlineto
          for (var i = 0; i < a.length; i += 2) {
            step(m, a[i], a[i + 1]);
          }
        case 6: // hlineto
        case 7: // vlineto
          // Both alternate axes after every delta; they differ only in which
          // axis the first one moves along.
          var horizontal = operator == 6;

          for (final delta in a) {
            step(m, horizontal ? delta : 0, horizontal ? 0 : delta);
            horizontal = !horizontal;
          }
        case 8: // rrcurveto
          for (var i = 0; i < a.length; i += 6) {
            curve(m, a.sublist(i, i + 6));
          }
        case 26: // vvcurveto: dx1? {dya dxb dyb dyc}+
          var i = 0;
          var dx1 = 0.0;

          if (a.length.isOdd) {
            dx1 = a[0];
            i = 1;
          }

          for (; i < a.length; i += 4) {
            curve(m, [dx1, a[i], a[i + 1], a[i + 2], 0, a[i + 3]]);
            // The optional leading delta adjusts the first curve only.
            dx1 = 0;
          }
        case 27: // hhcurveto: dy1? {dxa dxb dyb dxc}+
          var i = 0;
          var dy1 = 0.0;

          if (a.length.isOdd) {
            dy1 = a[0];
            i = 1;
          }

          for (; i < a.length; i += 4) {
            curve(m, [a[i], dy1, a[i + 1], a[i + 2], a[i + 3], 0]);
            dy1 = 0;
          }
        default:
          throw UnsupportedError(
            'This reader does not decode charstring operator $operator',
          );
      }
    }

    stack = [];
  }

  /// Replaces the `n` default values and their `n * regionCount` deltas with
  /// `n` per-master operands.
  void resolveBlend() {
    final n = stack.removeLast().first.toInt();
    final consumed = n * (1 + regionCount);
    final operands = stack.sublist(stack.length - consumed);
    stack.removeRange(stack.length - consumed, stack.length);

    for (var o = 0; o < n; o++) {
      final base = operands[o].first;

      stack.add([
        base,
        // Deltas are grouped by operand, region-minor — the order
        // `blendCommands` documents and writes.
        for (var r = 0; r < regionCount; r++)
          base + operands[n + o * regionCount + r].first,
      ]);
    }
  }

  var i = 0;

  while (i < charString.length) {
    final b0 = charString[i];

    if (b0 == 28) {
      push(view.getInt16(i + 1).toDouble());
      i += 3;
    } else if (b0 == 29) {
      push(view.getInt32(i + 1).toDouble());
      i += 5;
    } else if (b0 == 255) {
      push(view.getInt32(i + 1) / 0x10000);
      i += 5;
    } else if (b0 >= 32 && b0 <= 246) {
      push((b0 - 139).toDouble());
      i += 1;
    } else if (b0 >= 247 && b0 <= 250) {
      push(((b0 - 247) * 256 + charString[i + 1] + 108).toDouble());
      i += 2;
    } else if (b0 >= 251 && b0 <= 254) {
      push((-(b0 - 251) * 256 - charString[i + 1] - 108).toDouble());
      i += 2;
    } else if (b0 == 16) {
      resolveBlend();
      i += 1;
    } else {
      draw(b0);
      i += 1;
    }
  }

  return [
    for (var m = 0; m < masterCount; m++)
      _InkBox(xMin: xMin[m], xMax: xMax[m], yMin: yMin[m], yMax: yMax[m]),
  ];
}

void main() {
  group('a variable font built from two masters', () {
    test('carries CFF2, fvar and STAT, and no CFF 1', () {
      final font = _variableFontFrom('check', _svg('check'));

      expect(font.tableMap, contains(kCFF2Tag));
      expect(font.tableMap, contains(kFvarTag));
      expect(font.tableMap, contains(kStatTag));
      expect(font.tableMap, isNot(contains(kCFFTag)));
    });

    test("names the axis, so fvar's axisNameID resolves", () {
      // OTS validates fvar's axisNameID and every STAT valueNameID against
      // the name table and rejects a font whose string is missing.
      final font = _variableFontFrom('check', _svg('check'));

      expect(
        font.name.getStringByNameId(NameID.strokeWidthAxis),
        kStrokeWidthAxisName,
      );
      expect(
        font.fvar!.axisNameID,
        kNameIDmap.getValueForKey(NameID.strokeWidthAxis),
      );
      expect(
        font.stat!.axisNameID,
        kNameIDmap.getValueForKey(NameID.strokeWidthAxis),
      );
    });

    test('spans the configured range, defaulting to its maximum', () {
      final font = _variableFontFrom('check', _svg('check'));

      expect(font.fvar!.range.min, _range.min);
      expect(font.fvar!.range.max, _range.max);
    });

    test('STAT names the endpoints of the axis fvar declares', () {
      // Making the separately-built tables agree is this task's whole job,
      // and this is the pairing nothing else checks. A STAT built from a
      // different range parses, sanitizes and passes the oracle — it just
      // declares format 1 axis values sitting *off* the axis, so
      // STAT-driven style matching offers instances no `fvar` coordinate
      // can select.
      final font = _variableFontFrom('check', _svg('check'));

      expect(font.stat!.range.min, font.fvar!.range.min);
      expect(font.stat!.range.max, font.fvar!.range.max);
    });

    test(
      'pins usWeightClass to 400 even though the axis is a stroke width',
      () {
        // An honest usWeightClass for a 1.33-2.0 stroke-width axis would be 2
        // ("Extra-thin"), which generic tooling reads as thinner than Thin.
        // 400 is the deliberate lie; this is the assertion Task 18 deferred
        // until a variable font existed to make it against.
        final font = _variableFontFrom('check', _svg('check'));

        expect(font.os2.version0.usWeightClass, 400);
      },
    );

    test('works with normalize: false, on a uniform one-em advance', () {
      // The one reachable combination the rest of this file does not touch.
      // `ArtboardFitting` takes a different `placementFor` branch — it never
      // translates — so "both masters share one transform" has to hold for
      // it too, and the advance stops being each glyph's ink and becomes the
      // em.
      final font = _variableFontFrom('check', _svg('check'), normalize: false);

      expect(font.tableMap, contains(kCFF2Tag));
      expect(font.tableMap, contains(kFvarTag));
      expect(
        font.hmtx.hMetrics[_firstIconGlyphIndex].advanceWidth,
        kDefaultOpenTypeUnitsPerEm,
      );

      final boxes = _masterInkBoxes(
        font.cff2!.charStringsData.data[_firstIconGlyphIndex],
        2,
      );

      expect(boxes[1].xMin, greaterThan(boxes[0].xMin));
      expect(boxes[1].xMax, lessThan(boxes[0].xMax));
      expect(boxes[1].centreX, closeTo(boxes[0].centreX, 2));
      expect(boxes[1].centreY, closeTo(boxes[0].centreY, 2));
    });

    test('encodes and reads back without throwing', () {
      final font = _variableFontFrom('check', _svg('check'));
      final bytes = OTFWriter().write(font);

      expect(() => OpenTypeFont.fromByteData(bytes), returnsNormally);
    });

    test('reading a variable font back drops fvar and STAT, and says so', () {
      // Documented limitation, pinned so it is a decision rather than a
      // surprise: this package writes variation tables it cannot read.
      // Anything doing read-modify-write must not route a variable font
      // through OTFReader. Tracked in
      // https://github.com/4akloon/fontify_plus/issues/12.
      final font = _variableFontFrom('check', _svg('check'));
      final reread = OpenTypeFont.fromByteData(OTFWriter().write(font));

      expect(reread.tableMap, isNot(contains(kFvarTag)));
      expect(reread.tableMap, isNot(contains(kStatTag)));
      expect(reread.tableMap, contains(kCFF2Tag));
    });
  });

  group('both masters land on one transform', () {
    test("the minimum master's ink box sits strictly inside the maximum's", () {
      // This is the assertion the shared-placement design exists for. Fitting
      // each master on its own would scale the thinner one *up* until its own
      // longest side filled the same em band, so the two boxes would come out
      // the same size — a font that parses, sanitizes and renders correctly
      // at both endpoints while every interpolated width sits on a bent
      // centreline.
      final font = _variableFontFrom('check', _svg('check'));

      final boxes = _masterInkBoxes(
        font.cff2!.charStringsData.data[_firstIconGlyphIndex],
        2,
      );
      final maxBox = boxes[0];
      final minBox = boxes[1];

      expect(minBox.xMin, greaterThan(maxBox.xMin));
      expect(minBox.xMax, lessThan(maxBox.xMax));
      expect(minBox.yMin, greaterThan(maxBox.yMin));
      expect(minBox.yMax, lessThan(maxBox.yMax));
    });

    test('the shared transform is the default master, not the minimum', () {
      // Containment above says the two masters share *a* transform; it says
      // nothing about *whose*. Deriving the placement from `minGlyphList`
      // instead satisfies every other assertion in this file — and every
      // other test in the suite, the byte-identity gate and the oracle —
      // while scaling the thin master to fill the band and dragging the
      // thick one 6-8% past it. Overflowing glyphs clip against their
      // neighbours and sit oversized beside every other font in the UI.
      //
      // Checked on all four example icons, because the two that already sit
      // exactly on the em (`plus`, `menu`) have no slack to absorb a
      // mis-sourced placement.
      final font = _variableFontFromAll(_exampleSvgs());
      final charStrings = font.cff2!.charStringsData.data;

      for (var i = _firstIconGlyphIndex; i < charStrings.length; i++) {
        expect(
          _masterInkBoxes(charStrings[i], 2)[0].longestSide,
          lessThanOrEqualTo(kDefaultOpenTypeUnitsPerEm.toDouble()),
          reason: 'glyph $i overflows the em square',
        );
      }
    });

    test('independently fitting the minimum master would scale it up', () {
      // The other half of the assertion above: "strictly inside" only
      // discriminates because independent fitting really would not produce a
      // smaller box. `GlyphFitting.fit` scales each glyph until its *own*
      // longest side fills the em band, so the thinner master — whose ink
      // box starts smaller — is scaled by more, and ends up at least as
      // large as the thicker one rather than nested inside it.
      final masters = GlyphMasterBuilder(
        _range,
      ).fromSvg('check', _svg('check'));
      const fitting = NormalizedFitting(
        ascender: kDefaultOpenTypeUnitsPerEm - kDefaultBaselineExtension,
        descender: -kDefaultBaselineExtension,
      );

      //
      // The comparison is strict only because `GenericGlyphMetrics`
      // truncates each extreme to an int independently, and does so on the
      // *raw* artboard where a unit is worth ~55 font units, which makes the
      // two scale factors differ by more than the band. Exact metrics would
      // put both masters' longest sides at 1000 and turn this red — while
      // improving the code. If that happens, weaken it to
      // `greaterThanOrEqualTo`; the property being pinned is "not smaller",
      // and it is `>=` that the test above depends on.
      final fittedMin = fitting.fit(masters.min).metrics;
      final fittedMax = fitting.fit(masters.max).metrics;

      expect(
        math.max(fittedMin.width, fittedMin.height),
        greaterThan(math.max(fittedMax.width, fittedMax.height)),
      );
    });

    test('the two masters share a box centre', () {
      // The centreline is what interpolation swings around: a shared scale
      // that nonetheless moved the glyph sideways between masters would still
      // bend every width between them, and "strictly inside" alone does not
      // rule that out — a box can be nested and off-centre.
      //
      // Not exact, for two separate reasons, and the smaller one dominates:
      //
      // * Truncation. Each master's coordinates go through `p.x.toInt()`
      //   independently on the way into a charstring, which can move either
      //   edge of either box by up to a unit. This is all of `check`'s drift:
      //   at full double precision its two centres agree to 16 digits, and
      //   the 0.5 below appears only after truncation.
      // * Geometry, up to about a unit. A stroke grows by half its width
      //   along the outward normal, which cancels in the centre exactly only
      //   where the box's two extremes face opposite ways. `arrow_right`'s do
      //   not quite: its masters' x centres genuinely differ by 0.962 before
      //   any rounding.
      //
      // Measured across all four example icons the worst case is `arrow_right`
      // at exactly 1.0, so the tolerance is 2 rather than sitting on that
      // boundary — `closeTo` is inclusive, and a gate that passes only
      // because of that is not a gate. There is room for it: the failure
      // being guarded against moves this centre by 34 units.
      final font = _variableFontFromAll(_exampleSvgs());
      final charStrings = font.cff2!.charStringsData.data;

      for (var i = _firstIconGlyphIndex; i < charStrings.length; i++) {
        final boxes = _masterInkBoxes(charStrings[i], 2);
        final maxBox = boxes[0];
        final minBox = boxes[1];

        expect(minBox.centreX, closeTo(maxBox.centreX, 2), reason: 'glyph $i');
        expect(minBox.centreY, closeTo(maxBox.centreY, 2), reason: 'glyph $i');
      }
    });
  });

  group('a static font is untouched by the variable path', () {
    test('carries CFF 1 and neither fvar nor STAT', () {
      // The byte-identity integration gate is the real check here; this
      // states the same thing where a reader of this file will see it.
      final font = OpenTypeFont.createFromGlyphs(
        glyphList: [GenericGlyph.fromSvg('check', _svg('check'))],
        fontName: 'Static Icons',
      );

      expect(font.tableMap, contains(kCFFTag));
      expect(font.tableMap, isNot(contains(kCFF2Tag)));
      expect(font.tableMap, isNot(contains(kFvarTag)));
      expect(font.tableMap, isNot(contains(kStatTag)));
      expect(font.name.getStringByNameId(NameID.strokeWidthAxis), isNull);
    });
  });

  group('the master/range pairing is validated', () {
    List<GenericGlyph> glyphs() => [
      GenericGlyph.fromSvg('check', _svg('check')),
    ];

    test('a minimum master without a range is rejected', () {
      expect(
        () => OpenTypeFont.createFromGlyphs(
          glyphList: glyphs(),
          minGlyphList: glyphs(),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            allOf(contains('minGlyphList'), contains('strokeWidthRange')),
          ),
        ),
      );
    });

    test('a range without a minimum master is rejected', () {
      expect(
        () => OpenTypeFont.createFromGlyphs(
          glyphList: glyphs(),
          strokeWidthRange: _range,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            allOf(contains('minGlyphList'), contains('strokeWidthRange')),
          ),
        ),
      );
    });

    test('masters of differing lengths are rejected', () {
      // The two lists are indexed together, glyph for glyph; a length
      // mismatch is a caller pairing the wrong masters, not something to
      // discover as a RangeError deep inside the CFF2 builder.
      expect(
        () => OpenTypeFont.createFromGlyphs(
          glyphList: [...glyphs(), ...glyphs()],
          minGlyphList: glyphs(),
          strokeWidthRange: _range,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('same length'),
          ),
        ),
      );
    });

    test('a range with TrueType outlines is rejected', () {
      // There is no TrueType variable branch: that would be `gvar`, which
      // this package does not write. Falling back to a static TTF would hand
      // the caller a font whose axis silently does not exist.
      expect(
        () => OpenTypeFont.createFromGlyphs(
          glyphList: glyphs(),
          minGlyphList: glyphs(),
          strokeWidthRange: _range,
          useOpenType: false,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('useOpenType'),
          ),
        ),
      );
    });
  });
}
