import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fontify_plus_example/variable_stroke_probe.dart';
import 'package:integration_test/integration_test.dart';

/// One candidate format and the static masters it is judged against.
class _Candidate {
  const _Candidate(this.format, this.variable, this.staticPrefix);

  final String format;
  final String variable;

  /// Static families of the SAME outline format, suffixed 133/150/200.
  ///
  /// Judging a glyf-based variable font against a CFF reference measures the
  /// gap between two writers rather than the quality of the interpolation.
  final String staticPrefix;

  String get thin => '${staticPrefix}133';
  String get mid => '${staticPrefix}150';
  String get thick => '${staticPrefix}200';
}

    # gvar was a candidate through Phase 0 but lost the format decision (Task 5):
    # glyf's cubic-to-quadratic conversion is width-dependent and the package
    // does not yet plan it once across masters, so `ring` (uniE002) comes out
    // point-incompatible and varLib drops its variation entirely — reconfirmed
    // against fonts freshly rebuilt by tool/variable_prototype/, not just
    // historically. See tool/variable_prototype/README.md ("Decision: CFF2 +
    // blend"). Keeping a candidate here that fails by design would make this
    // standing gate red on every run, so only the winning format is exercised.
    // Proto families are rebuilt by tool/build_proto_fonts.py (package CLI,
    // not varLib).
const _candidates = [_Candidate('CFF2', 'ProtoCff2', 'ProtoCff')];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<Uint8List> render(
    WidgetTester tester,
    String family, {
    double? weight,
    int codePoint = kRing,
  }) async {
    final key = GlobalKey();
    const probeSize = 48.0;

    await tester.pumpWidget(
      MaterialApp(
        home: GlyphProbe(
          boundaryKey: key,
          family: family,
          weight: weight,
          codePoint: codePoint,
          size: probeSize,
        ),
      ),
    );
    await tester.pumpAndSettle();

    return capture(key, expectedSide: probeSize * 2);
  }

  /// How much rebuilding the font at the two widths changes the raster.
  ///
  /// Every threshold below is a fraction of this rather than an absolute
  /// constant, so the assertions survive a change of render size, window
  /// size, antialiasing or glyph geometry — none of which say anything about
  /// whether the axis works.
  Future<double> staticSpan(
    WidgetTester tester,
    _Candidate candidate,
    int glyph,
  ) async {
    final thin = await render(tester, candidate.thin, codePoint: glyph);
    final thick = await render(tester, candidate.thick, codePoint: glyph);

    return difference(thin, thick);
  }

  for (final candidate in _candidates) {
    final family = candidate.variable;

    group(candidate.format, () {
      testWidgets('at 1.5 matches the static font built at 1.5', (
        tester,
      ) async {
        for (final glyph in [kRing, kPlus]) {
          final span = await staticSpan(tester, candidate, glyph);
          final variable = await render(
            tester,
            family,
            weight: 1.5,
            codePoint: glyph,
          );
          final reference = await render(
            tester,
            candidate.mid,
            codePoint: glyph,
          );

          expect(
            difference(variable, reference),
            lessThan(0.2 * span),
            reason: 'glyph $glyph drifted from its static reference',
          );
        }
      });

      testWidgets('the axis is not silently ignored', (tester) async {
        for (final glyph in [kRing, kPlus]) {
          final span = await staticSpan(tester, candidate, glyph);

          // Without this floor, a font that failed to load zeroes both sides
          // of the comparison below and the test passes on nothing.
          expect(
            span,
            greaterThan(0.005),
            reason:
                'the static pair itself shows no width change — did the '
                'fonts load?',
          );

          final thin = await render(
            tester,
            family,
            weight: 1.33,
            codePoint: glyph,
          );
          final thick = await render(
            tester,
            family,
            weight: 2,
            codePoint: glyph,
          );

          // An engine that drops the axis renders both widths identically and
          // passes every other check in this file. This is the one assertion
          // that catches it, and it asks the right question: does moving the
          // axis move the raster as much as rebuilding the font does?
          expect(
            difference(thin, thick),
            greaterThan(0.6 * span),
            reason: 'glyph $glyph did not change with the axis',
          );
        }
      });

      testWidgets('a fill does not move with the axis', (tester) async {
        // kDot has no stroke, so its deltas are all zero. If it changes, the
        // font is varying something it should not.
        final thin = await render(
          tester,
          family,
          weight: 1.33,
          codePoint: kDot,
        );
        final thick = await render(tester, family, weight: 2, codePoint: kDot);

        expect(difference(thin, thick), lessThan(0.001));
      });

      testWidgets('a weight outside the axis clamps instead of failing', (
        tester,
      ) async {
        final span = await staticSpan(tester, candidate, kRing);
        final beyond = await render(tester, family, weight: 8);
        final atMax = await render(tester, family, weight: 2);

        expect(difference(beyond, atMax), lessThan(0.2 * span));
      });
    });
  }
}
