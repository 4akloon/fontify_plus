import 'dart:io';

import 'package:fontify_plus/src/job/font_job.dart';
import 'package:fontify_plus/src/job/fontify_exception.dart';
import 'package:fontify_plus/src/job/run_font_job.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fontify_plus_job_test');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('runFontJob writes otf and optional class file', () {
    final fontPath = '${tempDir.path}/icons.otf';
    final classPath = '${tempDir.path}/icons.dart';

    final result = runFontJob(
      FontJob(
        inputSvgDir: 'test/assets/svg',
        outputFontFile: fontPath,
        outputClassFile: classPath,
        className: 'TestIcons',
      ),
    );

    expect(File(fontPath).existsSync(), isTrue);
    expect(File(fontPath).lengthSync(), greaterThan(0));
    expect(result.classSource, contains('class TestIcons'));
    expect(File(classPath).readAsStringSync(), contains('class TestIcons'));
  });

  test('runFontJob throws when the SVG directory has no .svg files', () {
    final empty = Directory('${tempDir.path}/empty')..createSync();
    final fontPath = '${tempDir.path}/out.otf';

    expect(
      () => runFontJob(
        FontJob(inputSvgDir: empty.path, outputFontFile: fontPath),
      ),
      throwsA(isA<FontifyException>()),
    );
    expect(File(fontPath).existsSync(), isFalse);
  });
}
