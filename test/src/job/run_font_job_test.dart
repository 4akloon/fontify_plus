import 'dart:io';
import 'dart:typed_data';

import 'package:fontify_plus/src/common/stroke_width_range.dart';
import 'package:fontify_plus/src/job/font_job.dart';
import 'package:fontify_plus/src/job/fontify_exception.dart';
import 'package:fontify_plus/src/job/run_font_job.dart';
import 'package:fontify_plus/src/otf/io.dart';
import 'package:test/test.dart';

/// The `wght` axis as the written font file actually encodes it.
typedef WghtAxis = ({double min, double defaultValue, double max});

/// Reads the `wght` axis straight out of a written font's `fvar` table.
///
/// [readFromFile] deliberately skips `fvar` (#12), and `FontJobResult` hands
/// back the in-memory table the builder was given — neither one proves what
/// landed on disk. Parsing the bytes is what makes this a test of the whole
/// hand-off, from [FontJob] through `svgToOtf` to the file a font tool would
/// open.
WghtAxis _wghtAxisOf(String fontPath) {
  final bytes = File(fontPath).readAsBytesSync();
  final data = ByteData.sublistView(bytes);

  // sfnt header: sfntVersion (4), numTables (2), then searchRange /
  // entrySelector / rangeShift (2 each) before the table records at 12.
  final numTables = data.getUint16(4);
  int? fvarOffset;
  for (var i = 0; i < numTables; i++) {
    final record = 12 + i * 16;
    final tag = String.fromCharCodes(bytes.sublist(record, record + 4));
    if (tag == 'fvar') {
      fvarOffset = data.getUint32(record + 8);
      break;
    }
  }

  if (fvarOffset == null) {
    fail('The font at $fontPath has no fvar table, so it is not variable.');
  }

  // fvar: a 16-byte header, then one 20-byte axis record whose values are
  // 16.16 fixed point after the 4-byte tag.
  final axis = fvarOffset + data.getUint16(fvarOffset + 4);
  double fixed(int at) => data.getInt32(at) / 65536;

  expect(
    String.fromCharCodes(bytes.sublist(axis, axis + 4)),
    'wght',
    reason: 'the one axis this package writes is the stroke width axis',
  );

  return (
    min: fixed(axis + 4),
    defaultValue: fixed(axis + 8),
    max: fixed(axis + 12),
  );
}

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
    expect(source, contains('static const IconData aX ='));
    expect(source, contains('static const IconData bX ='));
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

  // The two lines these cover - `strokeWidthRange:` and
  // `defaultStrokeWidth:` on runFontJob's svgToOtf call - are the seam
  // between a resolved job and font generation. Everything on either side of
  // them is tested elsewhere; drop either line and the CLI silently emits a
  // font with a narrower axis, or none at all, with nothing else to notice.
  test('runFontJob writes a wght axis spanning the job range', () {
    final fontPath = '${tempDir.path}/ranged.otf';

    runFontJob(
      FontJob(
        inputSvgDir: 'example/svg',
        outputFontFile: fontPath,
        strokeWidthRange: StrokeWidthRange(1.33, 2),
      ),
    );

    final axis = _wghtAxisOf(fontPath);
    expect(axis.min, closeTo(1.33, 1e-4));
    expect(axis.max, closeTo(2, 1e-4));
    // With no defaultStrokeWidth the axis defaults to the range maximum.
    expect(axis.defaultValue, closeTo(2, 1e-4));
  });

  test('runFontJob defaults the wght axis to the job default width', () {
    final defaulted = '${tempDir.path}/defaulted.otf';
    final undefaulted = '${tempDir.path}/undefaulted.otf';
    const range = (min: 1.33, max: 2.0);

    runFontJob(
      FontJob(
        inputSvgDir: 'example/svg',
        outputFontFile: defaulted,
        strokeWidthRange: StrokeWidthRange(range.min, range.max),
        defaultStrokeWidth: 1.5,
      ),
    );
    runFontJob(
      FontJob(
        inputSvgDir: 'example/svg',
        outputFontFile: undefaulted,
        strokeWidthRange: StrokeWidthRange(range.min, range.max),
      ),
    );

    final axis = _wghtAxisOf(defaulted);
    expect(axis.defaultValue, closeTo(1.5, 1e-4));
    expect(axis.min, closeTo(range.min, 1e-4));
    expect(axis.max, closeTo(range.max, 1e-4));

    // The interior default is not just an fvar edit: it adds a third master
    // and a second variation region, so the same job without it cannot
    // produce the same file.
    expect(
      File(defaulted).readAsBytesSync(),
      isNot(File(undefaulted).readAsBytesSync()),
    );
  });

  // The `defaultStrokeWidth:` line on runFontJob's *generateFlutterClass*
  // call, which is a second, separate hand-off from the svgToOtf one above.
  // Drop it and the font still opens at the interior width while the class
  // its users read keeps claiming the maximum — a silent contradiction no
  // font-level assertion can see.
  test('runFontJob names the job default width in the generated class', () {
    final result = runFontJob(
      FontJob(
        inputSvgDir: 'example/svg',
        outputFontFile: '${tempDir.path}/documented.otf',
        outputClassFile: '${tempDir.path}/documented.dart',
        className: 'Documented',
        strokeWidthRange: StrokeWidthRange(1.33, 2),
        defaultStrokeWidth: 1.5,
      ),
    );

    final source = result.classSource!;
    expect(source, contains('Variable stroke width: 1.33 … 2.0'));
    expect(source, contains('default 1.5'));
    // The written file, not just the returned string: the class the user
    // compiles against is the one on disk.
    expect(
      File('${tempDir.path}/documented.dart').readAsStringSync(),
      contains('default 1.5'),
    );
  });

  test('runFontJob reuses head timestamps from an existing output font', () {
    final root = Directory('${tempDir.path}/svg_ts')..createSync();
    File('${root.path}/a.svg').writeAsStringSync(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
      '<path d="M0 0h24v24H0z"/></svg>',
    );
    final fontPath = '${tempDir.path}/ts.otf';

    runFontJob(
      FontJob(inputSvgDir: root.path, outputFontFile: fontPath),
    );
    final first = readFromFile(fontPath);
    final firstBytes = File(fontPath).readAsBytesSync();

    runFontJob(
      FontJob(inputSvgDir: root.path, outputFontFile: fontPath),
    );
    final second = readFromFile(fontPath);

    expect(second.head.created, first.head.created);
    expect(second.head.modified, first.head.modified);
    expect(File(fontPath).readAsBytesSync(), firstBytes);
  });
}
