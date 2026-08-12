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

/// An interior width for the three-master tests, strictly inside [_range].
const _defaultWidth = 1.5;

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

/// Builds a three-master variable font from one SVG, defaulting to
/// [_defaultWidth].
///
/// [glyphList] carries the *interior default* master, not the maximum — the
/// pairing `OpenTypeFontBuilder` documents and the one that makes the store
/// two-region.
OpenTypeFont _threeMasterFontFrom(String name, String xmlString) {
  final masters = GlyphMasterBuilder(
    _range,
    defaultWidth: _defaultWidth,
  ).fromSvg(name, xmlString);

  return OpenTypeFont.createFromGlyphs(
    glyphList: [masters.atDefault!],
    minGlyphList: [masters.min],
    maxGlyphList: [masters.max],
    strokeWidthRange: _range,
    defaultStrokeWidth: _defaultWidth,
    fontName: 'Variable Icons',
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

  return _instanceInkBoxes(charString, regionCount, [
    // The default master: every region contributes nothing.
    List<double>.filled(regionCount, 0),
    // Master r + 1: region r alone contributes in full.
    for (var r = 0; r < regionCount; r++)
      [
        for (var i = 0; i < regionCount; i++)
          if (i == r) 1.0 else 0.0,
      ],
  ]);
}

/// The ink box one CFF2 [charString] draws at each of several instances.
///
/// Each row of [regionScalars] is one instance, given as the scalar every
/// region contributes at it — which is exactly what a rasterizer computes from
/// the variation store's region list and then multiplies each delta by. So
/// this measures instances *between* the masters, not only the masters
/// themselves, which is the only way to tell an axis that interpolates from
/// one that has quietly stopped varying.
///
/// See [_masterInkBoxes] for the measurement convention.
List<_InkBox> _instanceInkBoxes(
  Uint8List charString,
  int regionCount,
  List<List<double>> regionScalars,
) {
  final instanceCount = regionScalars.length;
  final view = ByteData.sublistView(charString);

  final x = List<double>.filled(instanceCount, 0);
  final y = List<double>.filled(instanceCount, 0);
  final xMin = List<double>.filled(instanceCount, double.infinity);
  final yMin = List<double>.filled(instanceCount, double.infinity);
  final xMax = List<double>.filled(instanceCount, double.negativeInfinity);
  final yMax = List<double>.filled(instanceCount, double.negativeInfinity);

  // One entry per operand on the argument stack; one value per instance. A
  // literal pushes the same value for every instance, a `blend` replaces the
  // literals it consumes with per-instance values.
  var stack = <List<double>>[];

  void push(double value) =>
      stack.add(List<double>.filled(instanceCount, value));

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
    for (var m = 0; m < instanceCount; m++) {
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
  /// `n` per-instance operands.
  void resolveBlend() {
    final n = stack.removeLast().first.toInt();
    final consumed = n * (1 + regionCount);
    final operands = stack.sublist(stack.length - consumed);
    stack.removeRange(stack.length - consumed, stack.length);

    for (var o = 0; o < n; o++) {
      final base = operands[o].first;

      stack.add([
        for (final scalars in regionScalars)
          [
            // Deltas are grouped by operand, region-minor — the order
            // `CharStringBlender` documents and writes.
            for (var r = 0; r < regionCount; r++)
              scalars[r] * operands[n + o * regionCount + r].first,
          ].fold(base, (sum, delta) => sum + delta),
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
    for (var m = 0; m < instanceCount; m++)
      _InkBox(xMin: xMin[m], xMax: xMax[m], yMin: yMin[m], yMax: yMax[m]),
  ];
}

/// The scalar each region of a three-master font contributes at stroke [width].
///
/// Reproduces what a rasterizer does with the region list this package writes
/// for an interior default: region 0 runs from the axis minimum (peak) to the
/// default, region 1 from the default to the maximum (peak). Normalized
/// coordinates put the minimum at -1, the default at 0 and the maximum at +1,
/// and a region's scalar falls linearly from 1 at its peak to 0 at the far end
/// of its span — and is 0 outside it entirely, which is the whole reason an
/// interior default needs two regions rather than one.
List<double> _regionScalarsAt(double width) {
  if (width <= _defaultWidth) {
    return [(_defaultWidth - width) / (_defaultWidth - _range.min), 0];
  }

  return [0, (width - _defaultWidth) / (_range.max - _defaultWidth)];
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

    test('OTFWriter emits fvar and STAT into the SFNT directory', () {
      // tableMap membership and the encode-set registration test both stay
      // green if encode silently drops those tags. The directory on the wire
      // is what a consumer actually sees.
      final font = _variableFontFrom('check', _svg('check'));
      final bytes = OTFWriter().write(font);
      final numTables = bytes.getUint16(4);
      final tags = {
        for (var i = 0; i < numTables; i++)
          TableRecordEntry.fromByteData(
            bytes,
            kOffsetTableLength + i * kTableRecordEntryLength,
          ).tag,
      };

      expect(tags, contains(kFvarTag));
      expect(tags, contains(kStatTag));
      expect(tags, contains(kCFF2Tag));
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
      // The default width is the same pairing one field over, and the same
      // failure in reverse: an `fvar` default that `STAT` names no axis value
      // for is a default instance style matching cannot reconcile with any
      // named stop. The two `create` calls sit five lines apart in
      // `OpenTypeFontBuilder`, so passing it to one and not the other is the
      // realistic mistake, and it is invisible in every other assertion here.
      expect(font.stat!.defaultWidth, font.fvar!.defaultWidth);
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

  group('a variable font built from three masters', () {
    test('carries a two-region CFF2 variation store', () {
      // Two regions is the whole point of the third master: with the default
      // at an interior width, normalized space runs -1 → 0 → +1, and a
      // region's scalar is zero outside its own span, so one region peaking
      // at the minimum would leave every width above the default unvaried.
      final font = _threeMasterFontFrom('check', _svg('check'));

      expect(font.cff2!.vstoreData!.store.variationRegionList.regionCount, 2);
      expect(
        font.cff2!.vstoreData!.store.variationRegionList.regions.map(
          (r) => r.peakCoord,
        ),
        // F2Dot14 -1.0 and +1.0: one region peaks at the axis minimum, the
        // other at its maximum. Their order is what pairs region 0 with the
        // second master and region 1 with the third.
        [0xC000, 0x4000],
      );
    });

    test('a two-master font stays one region, so the count discriminates', () {
      // Without this, the assertion above would pass on a builder that
      // ignored maxGlyphList entirely if the store were two-region for
      // everything.
      final font = _variableFontFrom('check', _svg('check'));

      expect(font.cff2!.vstoreData!.store.variationRegionList.regionCount, 1);
    });

    test('the third master is the widest, and the default sits between', () {
      // Order is load-bearing: master 1 feeds region 0 (peaking at the axis
      // minimum) and master 2 feeds region 1 (peaking at the maximum).
      // Passing them the other way round encodes and sanitizes fine and
      // simply interpolates backwards, so nothing but the geometry catches
      // it.
      final font = _threeMasterFontFrom('check', _svg('check'));

      final boxes = _masterInkBoxes(
        font.cff2!.charStringsData.data[_firstIconGlyphIndex],
        3,
      );
      final defaultBox = boxes[0];
      final minBox = boxes[1];
      final maxBox = boxes[2];

      expect(minBox.xMin, greaterThan(defaultBox.xMin));
      expect(minBox.xMax, lessThan(defaultBox.xMax));
      expect(maxBox.xMin, lessThan(defaultBox.xMin));
      expect(maxBox.xMax, greaterThan(defaultBox.xMax));
      expect(minBox.yMin, greaterThan(defaultBox.yMin));
      expect(maxBox.yMax, greaterThan(defaultBox.yMax));
    });

    test("every master shares the default master's transform", () {
      // Same shared-placement property the two-master group pins, extended to
      // the third: all three boxes swing around one centre, and the *default*
      // master — not the widest one — is the one fitted into the em band.
      final font = _threeMasterFontFrom('check', _svg('check'));

      final boxes = _masterInkBoxes(
        font.cff2!.charStringsData.data[_firstIconGlyphIndex],
        3,
      );

      for (var m = 1; m < boxes.length; m++) {
        expect(boxes[m].centreX, closeTo(boxes[0].centreX, 2), reason: 'm$m');
        expect(boxes[m].centreY, closeTo(boxes[0].centreY, 2), reason: 'm$m');
      }

      // Which master reaches the em band is what discriminates, and nesting
      // alone does not say: the boxes come out ordered min < default < max
      // whichever of them was fitted. `NormalizedFitting` scales its
      // reference until that reference's longest side fills the band
      // (ascender - descender, which is the em), so with the default master
      // as the reference the wider max master necessarily overflows — and
      // sourcing the placement from `maxGlyphList` instead would put the max
      // master on the band and shrink the default to about 93% of it
      // (measured: 928 rather than 1038 for this glyph).
      //
      // Greater-than-or-equal rather than equal because
      // `GenericGlyphMetrics` truncates the pre-fitting longest side to an
      // int, so the scale is computed against a slightly understated
      // reference and the fitted result overshoots the band by a few percent.
      final band = kDefaultOpenTypeUnitsPerEm.toDouble();

      expect(boxes[0].longestSide, greaterThanOrEqualTo(band));
      expect(boxes[2].longestSide, greaterThan(boxes[0].longestSide));
    });

    test('fvar defaults the axis to defaultStrokeWidth', () {
      final font = _threeMasterFontFrom('check', _svg('check'));

      expect(font.fvar!.range.min, _range.min);
      expect(font.fvar!.range.max, _range.max);
      expect(font.fvar!.defaultWidth, _defaultWidth);
    });

    test('fvar and STAT report the same defaultWidth', () {
      // The exact coupling the two `create` calls in `OpenTypeFontBuilder`
      // make easy to break: they sit five lines apart, so threading the value
      // into one and leaving the other on `range.max` is the realistic
      // mistake, and it is invisible everywhere else — the font parses,
      // sanitizes and renders, it just opens on an instance `STAT` names no
      // axis value for. Read back off a built font rather than trusting that
      // one variable was passed twice.
      final font = _threeMasterFontFrom('check', _svg('check'));

      expect(font.stat!.defaultWidth, font.fvar!.defaultWidth);
      expect(font.stat!.defaultWidth, _defaultWidth);
      expect(font.stat!.range.min, font.fvar!.range.min);
      expect(font.stat!.range.max, font.fvar!.range.max);
    });

    test('every width the axis declares renders distinctly', () {
      // The property the two-region store exists to provide, measured the way
      // a rasterizer would: resolve each blend at the region scalars that
      // coordinate produces, rather than only looking at the masters.
      //
      // A one-region store — which is what omitting `maxGlyphList` used to
      // produce — has its only region end at the default, so its scalar is
      // zero above it and every width in (1.5, 2.0] collapses onto 1.5. That
      // font encodes, round-trips and sanitizes; monotone widening across the
      // whole declared range is what actually rules it out.
      final font = _threeMasterFontFrom('check', _svg('check'));
      final charString = font.cff2!.charStringsData.data[_firstIconGlyphIndex];

      const widths = [1.33, 1.4, 1.5, 1.75, 2.0];
      final boxes = _instanceInkBoxes(charString, 2, [
        for (final width in widths) _regionScalarsAt(width),
      ]);

      for (var i = 1; i < widths.length; i++) {
        expect(
          boxes[i].longestSide,
          greaterThan(boxes[i - 1].longestSide),
          reason: 'width ${widths[i]} is no wider than ${widths[i - 1]}',
        );
      }
    });

    test('encodes, and reads back with its two-region store intact', () {
      final font = _threeMasterFontFrom('check', _svg('check'));
      final bytes = OTFWriter().write(font);
      final reread = OpenTypeFont.fromByteData(bytes);

      expect(
        reread.cff2!.vstoreData!.store.variationRegionList.regionCount,
        2,
      );
    });
  });

  group("the two-master path is unchanged by the third master's arrival", () {
    test('its bytes are the ones the pre-three-master builder produced', () {
      // `byte_identity_test.dart` is the real gate — it pins the shipped
      // example font, built through the whole pipeline, against a checked-in
      // file. This states the same property one layer down, directly against
      // `OpenTypeFontBuilder`, so a regression points at this class rather
      // than at anything between it and the CLI.
      //
      // The digest below was captured from the builder as it stood before
      // `maxGlyphList`/`defaultStrokeWidth` existed. Both are omitted here, so
      // it must not move: FNV-1a/32 over the encoded font, which needs no
      // dependency and no binary fixture, and whose only job is to be
      // different if any byte is.
      final masters = [
        for (final entry in _exampleSvgs().entries)
          GlyphMasterBuilder(_range).fromSvg(entry.key, entry.value),
      ];

      final font = OpenTypeFont.createFromGlyphs(
        glyphList: [for (final m in masters) m.max],
        minGlyphList: [for (final m in masters) m.min],
        strokeWidthRange: _range,
        fontName: 'Variable Icons',
      );

      final bytes = OTFWriter().write(font).buffer.asUint8List();

      var digest = 0x811c9dc5;

      for (final byte in bytes) {
        digest = ((digest ^ byte) * 0x01000193) & 0xffffffff;
      }

      expect(bytes.length, 2672, reason: 'font size changed');
      expect(digest, 0x950a605d, reason: 'font bytes changed');
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

    test('a maximum master of a differing length is rejected', () {
      expect(
        () => OpenTypeFont.createFromGlyphs(
          glyphList: [...glyphs(), ...glyphs()],
          minGlyphList: [...glyphs(), ...glyphs()],
          maxGlyphList: glyphs(),
          strokeWidthRange: _range,
          defaultStrokeWidth: _defaultWidth,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            allOf(contains('maxGlyphList'), contains('same length')),
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

  group('the default width is validated against the range', () {
    List<GenericGlyph> glyphs() => [
      GenericGlyph.fromSvg('check', _svg('check')),
    ];

    test('a default width without a range is rejected', () {
      // A width names a point *on* an axis. With no axis, the static path
      // writes neither `fvar` nor `STAT` and the value is simply dropped.
      expect(
        () => OpenTypeFont.createFromGlyphs(
          glyphList: glyphs(),
          defaultStrokeWidth: _defaultWidth,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('defaultStrokeWidth'),
              contains('strokeWidthRange'),
            ),
          ),
        ),
      );
    });

    for (final bad in [1.0, 1.33, 2.0, 2.5, double.nan]) {
      test('a default width of $bad is rejected as outside 1.33-2.0', () {
        // Strict at both ends. Outside the range, `fvar`'s default coordinate
        // names a width no master sits at; equal to an endpoint, the third
        // master duplicates one that already exists and `STAT` names two axis
        // values at one coordinate. Neither is detectable downstream — both
        // encode, sanitize and only misbehave when rendered or listed.
        expect(
          () => OpenTypeFont.createFromGlyphs(
            glyphList: glyphs(),
            minGlyphList: glyphs(),
            strokeWidthRange: _range,
            defaultStrokeWidth: bad,
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('defaultStrokeWidth'),
                contains('$bad'),
                contains('StrokeWidthRange(1.33, 2.0)'),
              ),
            ),
          ),
          reason: 'defaultStrokeWidth $bad',
        );
      });
    }

    test('a width strictly inside the range is accepted', () {
      // The other half of the loop above: the boundary rejections
      // discriminate only because an interior width gets through.
      expect(
        () => OpenTypeFont.createFromGlyphs(
          glyphList: glyphs(),
          minGlyphList: glyphs(),
          maxGlyphList: glyphs(),
          strokeWidthRange: _range,
          defaultStrokeWidth: _defaultWidth,
        ),
        returnsNormally,
      );
    });
  });

  group('the third master needs something to be a third master for', () {
    List<GenericGlyph> glyphs() => [
      GenericGlyph.fromSvg('check', _svg('check')),
    ];

    test('a maximum master alone is rejected, naming both preconditions', () {
      expect(
        () => OpenTypeFont.createFromGlyphs(
          glyphList: glyphs(),
          maxGlyphList: glyphs(),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('maxGlyphList'),
              contains('minGlyphList'),
              contains('defaultStrokeWidth'),
            ),
          ),
        ),
      );
    });

    test('a maximum master without a default width is rejected', () {
      // With the default still at the range's maximum, `glyphList` already is
      // the widest drawing: a third master would duplicate it and buy a
      // second variation region, and a second delta behind every blended
      // value, to describe a width the font already had.
      expect(
        () => OpenTypeFont.createFromGlyphs(
          glyphList: glyphs(),
          minGlyphList: glyphs(),
          maxGlyphList: glyphs(),
          strokeWidthRange: _range,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('maxGlyphList'),
              contains('defaultStrokeWidth'),
              isNot(contains('minGlyphList: null')),
            ),
          ),
        ),
      );
    });

    test('a maximum master without a minimum master is rejected', () {
      // This combination never reaches the maxGlyphList rule: a range without
      // a minimum master trips the both-or-neither pairing check first, so
      // what is pinned here is that the *pairing* check catches it and names
      // the pair. Asserting on that message rather than on the bare word
      // "minGlyphList" is what keeps this from being a tautology that would
      // pass on any of the four errors above.
      expect(
        () => OpenTypeFont.createFromGlyphs(
          glyphList: glyphs(),
          maxGlyphList: glyphs(),
          strokeWidthRange: _range,
          defaultStrokeWidth: _defaultWidth,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('minGlyphList'),
              contains('strokeWidthRange'),
              contains('must both be set'),
            ),
          ),
        ),
      );
    });

    test('an interior default without a maximum master is rejected', () {
      // The converse of the rule above, and the reason it cannot be left to
      // the caller: this is the one bad combination that produces a font
      // which encodes, round-trips and sanitizes. With only two masters the
      // store gets one region, ending at the default, so its scalar is zero
      // above it: every width in (1.5, 2.0] renders identically to 1.5 —
      // nearly half the declared axis dead — while `fvar` still declares a
      // maximum and `STAT` still names an instance at it.
      expect(
        () => OpenTypeFont.createFromGlyphs(
          glyphList: glyphs(),
          minGlyphList: glyphs(),
          strokeWidthRange: _range,
          defaultStrokeWidth: _defaultWidth,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('defaultStrokeWidth'),
              contains('maxGlyphList'),
              contains('$_defaultWidth'),
            ),
          ),
        ),
      );
    });
  });
}
