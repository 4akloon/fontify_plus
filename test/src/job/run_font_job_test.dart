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

  test('runFontJob uses relative paths as glyph keys under recursive scan', () {
    final root = Directory('${tempDir.path}/svg')..createSync();
    Directory('${root.path}/a').createSync();
    Directory('${root.path}/b').createSync();
    File('${root.path}/a/x.svg').writeAsStringSync(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
      '<path d="M0 0h24v24H0z"/></svg>',
    );
    File('${root.path}/b/x.svg').writeAsStringSync(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
      '<path d="M12 2v20"/></svg>',
    );

    final classPath = '${tempDir.path}/icons.dart';
    final result = runFontJob(
      FontJob(
        inputSvgDir: root.path,
        outputFontFile: '${tempDir.path}/icons.otf',
        outputClassFile: classPath,
        className: 'Icons',
        recursive: true,
      ),
    );

    expect(
      result.otf.glyphList.map((g) => g.metadata.name),
      unorderedEquals(['a/x', 'b/x']),
    );
    final source = File(classPath).readAsStringSync();
    expect(source, contains('/// a/x'));
    expect(source, contains('/// b/x'));
    expect(source, contains('static const IconData x ='));
    expect(source, contains('static const IconData x2 ='));
  });

  test('runFontJob keeps basename keys for a flat directory', () {
    final root = Directory('${tempDir.path}/flat')..createSync();
    File('${root.path}/arrow.svg').writeAsStringSync(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
      '<path d="M0 0h24v24H0z"/></svg>',
    );

    final result = runFontJob(
      FontJob(
        inputSvgDir: root.path,
        outputFontFile: '${tempDir.path}/flat.otf',
        className: 'Flat',
      ),
    );

    expect(result.otf.glyphList.single.metadata.name, 'arrow');
  });
}
