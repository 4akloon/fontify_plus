import 'dart:io';

import 'package:fontify_plus/fontify_plus.dart';

/// Regenerates fonts from [fontify_plus.yaml].
///
/// From `example/`:
/// ```sh
/// dart run tool/generate.dart
/// ```
void main() {
  final config = parseFontifyConfig(
    File('fontify_plus.yaml').readAsStringSync(),
  );

  for (final result in runFontJobs(config.resolve())) {
    final label = result.name ?? 'job';
    stdout.writeln('Wrote ${result.otf.glyphList.length} icons ($label).');
  }
}
