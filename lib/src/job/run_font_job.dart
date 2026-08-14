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

  // Sorted, because [Directory.listSync] returns entries in whatever order
  // the filesystem holds them and that order is not a promise. It is close
  // enough to insertion order on APFS and on overlayfs to look stable, but
  // ext4 stores directory entries in a hash order that depends on the names
  // themselves, so a checkout on Linux can hand these back in a different
  // order than the machine the icons were authored on — and, observed on a
  // CI runner, in a different order on two runs of the same commit.
  //
  // Nothing downstream re-sorts. Charcodes are handed out by position from
  // kUnicodePrivateUseAreaStart, so this order *is* the codepoint
  // assignment: reordering the list silently renumbers every icon. A font
  // regenerated after that renders the wrong glyph for every IconData
  // constant already shipped against the old numbering, with no error
  // anywhere — the codepoints all still exist, they just mean something
  // else now.
  //
  // Sorted by the icon's own name rather than by path so the numbering
  // follows what the generated class shows the caller, and so it does not
  // change with where the directory happens to live.
  final svgEntries = [
    for (final f in svgFileList)
      (key: _svgKey(svgDir.path, f.path), path: f.path),
  ]..sort((a, b) => a.key.compareTo(b.key));

  final svgMap = {
    for (final entry in svgEntries)
      entry.key: File(entry.path).readAsStringSync(),
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
      preview: job.preview,
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
