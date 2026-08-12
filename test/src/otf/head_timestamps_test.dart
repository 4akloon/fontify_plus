import 'dart:io';

import 'package:fontify_plus/fontify_plus.dart';
import 'package:test/test.dart';

void main() {
  test('tryReadHeadTimestamps reads dates without loading other tables', () {
    final dir = Directory.systemTemp.createTempSync('fontify_head_ts_');
    addTearDown(() => dir.deleteSync(recursive: true));

    final path = '${dir.path}/v.otf';
    final created = DateTime.utc(2019, 6, 15, 12);
    final modified = DateTime.utc(2021, 3, 1, 8);

    final font = svgToOtf(
      svgMap: {
        'line':
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
            '<path d="M4 12h16" stroke="#000" stroke-width="2"/></svg>',
      },
      fontName: 'Ts',
      strokeWidthRange: StrokeWidthRange(1, 2),
      created: created,
      modified: modified,
    ).font;

    writeToFile(path, font);

    final times = tryReadHeadTimestamps(path);

    expect(times, isNotNull);
    expect(times!.created.toUtc(), created);
    expect(times.modified.toUtc(), modified);
  });

  test('tryReadHeadTimestamps returns null for a missing file', () {
    expect(tryReadHeadTimestamps('no/such/font.otf'), isNull);
  });
}
