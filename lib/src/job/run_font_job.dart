import 'dart:io';

import 'package:path/path.dart' as p;

import '../common/api.dart';
import '../otf/io.dart';
import '../utils/logger.dart';
import 'font_job.dart';
import 'fontify_exception.dart';

/// {@category api}
/// Runs one [FontJob]: reads SVGs, builds the font, writes outputs.
FontJobResult runFontJob(FontJob job) {
  final jobStopwatch = Stopwatch()..start();
  final label = job.name ?? job.outputFontFile;
  logger.i('Generating font "$label"');

  final svgDir = Directory(job.inputSvgDir);
  if (!svgDir.existsSync() ||
      svgDir.statSync().type != FileSystemEntityType.directory) {
    throw FontifyException(
      "The input directory is not a directory or it doesn't exist "
      '(${job.inputSvgDir}).',
    );
  }

  final classFile = job.outputClassFile == null
      ? null
      : File(job.outputClassFile!);
  final fontFile = File(job.outputFontFile);

  if (classFile?.existsSync() ?? false) {
    logger.t(
      'Output file for a Flutter class already exists (${classFile!.path}) - '
      'overwriting it',
    );
  }

  if (fontFile.existsSync()) {
    logger.t(
      'Output file for a font file already exists (${fontFile.path}) - '
      'overwriting it',
    );
  }

  final svgFileList = svgDir
      .listSync(recursive: job.recursive)
      .where((e) => p.extension(e.path).toLowerCase() == '.svg')
      .toList();

  if (svgFileList.isEmpty) {
    throw FontifyException(
      "The input directory doesn't contain any SVG file "
      '(${job.inputSvgDir}).',
    );
  }

  final svgMap = {
    for (final f in svgFileList)
      _svgKey(svgDir.path, f.path): File(f.path).readAsStringSync(),
  };

  // head only — full readFromFile warns on unread fvar/STAT (#12).
  final timestamps = tryReadHeadTimestamps(fontFile.path);

  final otfResult = svgToOtf(
    svgMap: svgMap,
    outlineStrokes: job.outlineStrokes,
    preview: job.preview,
    normalize: job.normalize,
    useOpenType: job.useOpenType,
    fontName: job.fontName,
    created: timestamps?.created,
    modified: timestamps?.modified,
    strokeWidthRange: job.strokeWidthRange,
    defaultStrokeWidth: job.defaultStrokeWidth,
  );

  writeToFile(job.outputFontFile, otfResult.font);

  String? classSource;
  if (classFile != null) {
    final fontFileName = p.basename(job.outputFontFile);
    classSource = generateFlutterClass(
      glyphList: otfResult.glyphList,
      className: job.className,
      indent: job.indent,
      fontFileName: fontFileName,
      familyName: otfResult.font.familyName,
      package: job.package,
      strokeWidthRange: job.strokeWidthRange,
      defaultStrokeWidth: job.defaultStrokeWidth,
    );
    classFile.writeAsStringSync(classSource);
  } else {
    logger.t(
      'No output path for Flutter class was specified - '
      'skipping class generation.',
    );
  }

  logger.i(
    'Generated "$label" in ${jobStopwatch.elapsedMilliseconds}ms',
  );

  return FontJobResult(
    name: job.name,
    otf: otfResult,
    classSource: classSource,
  );
}

String _svgKey(String inputSvgDir, String filePath) {
  final relative = p.relative(filePath, from: inputSvgDir);
  final withoutExt = p.withoutExtension(relative);
  return withoutExt.replaceAll(r'\', '/');
}

/// {@category api}
/// Runs [jobs] sequentially; stops on the first failure.
List<FontJobResult> runFontJobs(Iterable<FontJob> jobs) {
  return [for (final job in jobs) runFontJob(job)];
}
