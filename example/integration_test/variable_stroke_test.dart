import 'dart:typed_data';

import 'package:fontify_plus_example/variable_stroke_probe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Both candidate formats, tested side by side on one engine in one run.
const _variableFamilies = {'gvar': 'ProtoGvar', 'CFF2': 'ProtoCff2'};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<Uint8List> render(
    WidgetTester tester,
    String family, {
    double? weight,
    int codePoint = kRing,
  }) async {
    final key = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: GlyphProbe(
          boundaryKey: key,
          family: family,
          weight: weight,
          codePoint: codePoint,
        ),
      ),
    );
    await tester.pumpAndSettle();

    return capture(key);
  }

  for (final entry in _variableFamilies.entries) {
    final format = entry.key;
    final family = entry.value;

    group(format, () {
      testWidgets('at 1.5 matches the static font built at 1.5', (
        tester,
      ) async {
        for (final glyph in [kRing, kPlus]) {
          final variable = await render(
            tester,
            family,
            weight: 1.5,
            codePoint: glyph,
          );
          final reference = await render(
            tester,
            'ProtoStatic150',
            codePoint: glyph,
          );

          expect(
            difference(variable, reference),
            lessThan(0.02),
            reason: 'glyph $glyph drifted from its static reference',
          );
        }
      });

      testWidgets('the axis is not silently ignored', (tester) async {
        for (final glyph in [kRing, kPlus]) {
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
          // that catches it.
          expect(
            difference(thin, thick),
            greaterThan(0.01),
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

        expect(difference(thin, thick), lessThan(0.005));
      });

      testWidgets('a weight outside the axis clamps instead of failing', (
        tester,
      ) async {
        final beyond = await render(tester, family, weight: 8);
        final atMax = await render(tester, family, weight: 2);

        expect(difference(beyond, atMax), lessThan(0.02));
      });
    });
  }
}
