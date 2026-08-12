import 'dart:convert';

import '../common/constant.dart';
import '../common/generic_glyph.dart';
import '../common/stroke_width_range.dart';
import '../otf/defaults.dart';
import '../svg/svg_preview.dart';
import 'class_gen/dart_identifier.dart';
import 'class_gen/icon_name_allocator.dart';
import 'logger.dart';

const _kDefaultIndent = 2;
const _kDefaultClassName = 'fontify_plusIcons';
const _kDefaultFontFileName = 'fontify_plus_icons.otf';

/// UTF-8 size above which a generated file loses its previews when
/// [FlutterClassGenerator] decides for itself: IntelliJ-family IDEs stop
/// analyzing files over `idea.max.intellisense.filesize` (2500 KB), so the
/// budget stays under that cliff.
const _kPreviewSizeBudget = 2 * 1024 * 1024;

/// Generates a Flutter-compatible class holding an [IconData] per glyph.
///
/// [IconData]: https://api.flutter.dev/flutter/widgets/IconData-class.html
class FlutterClassGenerator {
  /// * [glyphList] is a list of non-default glyphs.
  /// * [className] is generated class' name (preferably, in PascalCase).
  /// * [familyName] is font's family name to use in IconData.
  /// * [package] is the name of a font package. Used to provide a font through
  /// package dependency.
  /// * [fontFileName] is font file's name. Used in generated docs for class.
  /// * [indent] is a number of spaces in leading indentation for class'
  /// members. Defaults to 2.
  /// * [strokeWidthRange], when given, documents the variable `wght` axis in the
  /// class comment.
  /// * [preview] — when false, dartdoc previews are omitted; when true, they
  /// are always emitted; when null (the default), they are emitted unless
  /// the generated file would exceed 2 MiB, in which case they are dropped
  /// with a warning.
  FlutterClassGenerator(
    this.glyphList, {
    String? className,
    String? familyName,
    String? fontFileName,
    String? package,
    int? indent,
    StrokeWidthRange? strokeWidthRange,
    bool? preview,
  }) : _indent = ' ' * (indent ?? _kDefaultIndent),
       _className = toDartIdentifier(className ?? _kDefaultClassName),
       _familyName = familyName ?? kDefaultFontFamily,
       _fontFileName = fontFileName ?? _kDefaultFontFileName,
       _iconVarNames = _allocateNames(glyphList),
       _package = package?.isEmpty ?? true ? null : package,
       _strokeWidthRange = strokeWidthRange,
       _preview = preview;

  final List<GenericGlyph> glyphList;
  final String _fontFileName;
  final String _className;
  final String _familyName;
  final String _indent;
  final String? _package;
  final List<String> _iconVarNames;
  final StrokeWidthRange? _strokeWidthRange;
  final bool? _preview;

  static List<String> _allocateNames(List<GenericGlyph> glyphList) {
    final allocator = IconNameAllocator();

    return [
      for (final glyph in glyphList) allocator.allocate(glyph.metadata.name!),
    ];
  }

  bool get _hasPackage => _package != null;

  /// Generates content for a class' file.
  String generate() {
    final content = _generate(previews: _preview ?? true);

    if (_preview != null ||
        utf8.encode(content).length <= _kPreviewSizeBudget) {
      return content;
    }

    final stripped = _generate(previews: false);

    logger.w(
      'Dropped dartdoc previews: with them the generated class for '
      '${glyphList.length} icons is ${utf8.encode(content).length} bytes, '
      'over the $_kPreviewSizeBudget-byte budget that keeps IDE code '
      'insight working; without them it is '
      '${utf8.encode(stripped).length} bytes. Pass preview: true or '
      '--preview to keep previews anyway, or preview: false / --no-preview '
      'to silence this warning.',
    );

    return stripped;
  }

  String _generate({required bool previews}) {
    final members = [
      "static const iconFontFamily = '$_familyName';",
      if (_hasPackage) "static const iconFontPackage = '$_package';",
      for (var i = 0; i < glyphList.length; i++)
        ..._iconConstant(i, previews: previews),
    ];

    final body = members.map((e) => e.isEmpty ? '' : '$_indent$e').join('\n');

    return '${_header()}$_axisDocComment$_docComment'
        'abstract final class $_className {\n'
        '$body\n'
        '}\n';
  }

  List<String> _iconConstant(int index, {required bool previews}) {
    final metadata = glyphList[index].metadata;
    final hex = '0x${metadata.charCode!.toRadixString(16)}';

    return [
      '',
      '/// ${metadata.name!}',
      if (previews && metadata.preview != null) ...[
        '///',
        '/// ![${metadata.name!}](${svgPreviewDataUri(metadata.preview!)})',
      ],
      'static const IconData ${_iconVarNames[index]} = IconData(',
      '$_indent$hex,',
      '${_indent}fontFamily: iconFontFamily,',
      if (_hasPackage) '${_indent}fontPackage: iconFontPackage,',
      ');',
    ];
  }

  String _header() =>
      '''
// Generated code: do not hand-edit.

// Generated using $kVendorName.
// Copyright © ${DateTime.now().year} $kVendorName ($kVendorUrl).

import 'package:flutter/widgets.dart';

''';

  String get _axisDocComment {
    final range = _strokeWidthRange;

    if (range == null) {
      return '';
    }

    final min = _formatAxisValue(range.min);
    final max = _formatAxisValue(range.max);
    final exampleIcon = _iconVarNames.firstOrNull ?? 'icon';

    return '/// Variable stroke width: $min … $max (`wght` axis).\n'
        '/// Set the width explicitly: '
        'Icon($_className.$exampleIcon, '
        'size: 16, weight: $min)\n'
        '///\n';
  }

  /// Formats axis values for generated docs: `2` reads as `2.0`, `1.33` as `1.33`.
  static String _formatAxisValue(double value) {
    final rounded = (value * 100).roundToDouble() / 100;

    if (rounded == rounded.roundToDouble()) {
      return rounded.toStringAsFixed(1);
    }

    final text = rounded.toStringAsFixed(2);

    return text.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  String get _docComment =>
      '''
/// Identifiers for the icons.
///
/// Use with the [Icon] class to show specific icons.
///
/// Icons are identified by their name as listed below.
///
/// To use this class, make sure you declare the font in your
/// project's `pubspec.yaml` file in the `fonts` section. This ensures that
/// the "$_familyName" font is included in your application. This font is used
/// to display the icons. For example:
///
/// ```yaml
/// flutter:
///   fonts:
///     - family: $_familyName
///       fonts:
///         - asset: fonts/$_fontFileName
/// ```
''';
}
