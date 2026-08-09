import 'dart:async';

import 'package:fontify_plus/src/otf/debugger.dart';
import 'package:test/test.dart';

/// Runs [body] with `print` captured instead of written to stdout.
List<String> capturePrints(void Function() body) {
  final lines = <String>[];

  runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => lines.add(line),
    ),
  );

  return lines;
}

void main() {
  group('OTFDebugger', () {
    test('debugUnsupportedTable names the table', () {
      final lines = capturePrints(
        () => debuggerOTF.debugUnsupportedTable('fooo'),
      );

      expect(lines.single, contains('Unsupported table: fooo'));
    });

    test('debugUnsupportedTableVersion names the table and version', () {
      final lines = capturePrints(
        () => debuggerOTF.debugUnsupportedTableVersion('OS/2', 99),
      );

      expect(lines.single, contains('OS/2'));
      expect(lines.single, contains('99'));
    });

    test('debugUnsupportedTableFormat names the table and format', () {
      final lines = capturePrints(
        () => debuggerOTF.debugUnsupportedTableFormat('cmap', 3),
      );

      expect(lines.single, contains('cmap'));
      expect(lines.single, contains('3'));
    });

    test('debugUnsupportedFeature names the feature', () {
      final lines = capturePrints(
        () => debuggerOTF.debugUnsupportedFeature('composite glyphs'),
      );

      expect(lines.single, contains('composite glyphs'));
    });
  });
}
