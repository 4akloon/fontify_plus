import '../common/constant.dart';
import '../common/generic_glyph.dart';
import '../common/stroke_width_range.dart';
import '../otf/defaults.dart';
import 'class_gen/dart_identifier.dart';
import 'class_gen/icon_name_allocator.dart';

const _kDefaultIndent = 2;
const _kDefaultClassName = 'fontify_plusIcons';
const _kDefaultFontFileName = 'fontify_plus_icons.otf';

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
  /// * [defaultStrokeWidth], when given alongside [strokeWidthRange], names
  /// the width the axis opens at. Without it a reader has to know the
  /// convention that the range's maximum is the default; with an interior
  /// default that convention is wrong and there is nothing in the generated
  /// file to correct it from. Ignored without [strokeWidthRange], since a
  /// width with no axis to sit on describes nothing. When both are given,
  /// throws [ArgumentError] unless [defaultStrokeWidth] lies strictly
  /// between [StrokeWidthRange.min] and [StrokeWidthRange.max] — otherwise
  /// the generated comment would name a default the font never opens at.
  FlutterClassGenerator(
    this.glyphList, {
    String? className,
    String? familyName,
    String? fontFileName,
    String? package,
    int? indent,
    StrokeWidthRange? strokeWidthRange,
    double? defaultStrokeWidth,
  }) : _indent = ' ' * (indent ?? _kDefaultIndent),
       _className = toDartIdentifier(className ?? _kDefaultClassName),
       _familyName = familyName ?? kDefaultFontFamily,
       _fontFileName = fontFileName ?? _kDefaultFontFileName,
       _iconVarNames = _allocateNames(glyphList),
       _package = package?.isEmpty ?? true ? null : package,
       _strokeWidthRange = strokeWidthRange,
       _defaultStrokeWidth = defaultStrokeWidth {
    // Mirrors `OpenTypeFontBuilder`'s own check (`lib/src/otf/otf_builder.dart`):
    // this constructor is likewise a Dart-API surface, not a CLI/YAML surface,
    // so a bad pairing is an `ArgumentError` here too. Without this,
    // `_axisDocComment` would render a default the font never opens at — a
    // reader could copy it straight into `weight:` and get silently clamped
    // to something else. `strokeWidthRange == null` is left alone: that carve
    // out belongs to `_axisDocComment` (a width with no axis to sit on
    // describes nothing), not to this check.
    if (strokeWidthRange != null &&
        defaultStrokeWidth != null &&
        !(strokeWidthRange.min < defaultStrokeWidth &&
            defaultStrokeWidth < strokeWidthRange.max)) {
      throw ArgumentError(
        'defaultStrokeWidth must lie strictly between the ends of '
        'strokeWidthRange; got defaultStrokeWidth: $defaultStrokeWidth, '
        'strokeWidthRange: $strokeWidthRange',
      );
    }
  }

  final List<GenericGlyph> glyphList;
  final String _fontFileName;
  final String _className;
  final String _familyName;
  final String _indent;
  final String? _package;
  final List<String> _iconVarNames;
  final StrokeWidthRange? _strokeWidthRange;
  final double? _defaultStrokeWidth;

  static List<String> _allocateNames(List<GenericGlyph> glyphList) {
    final allocator = IconNameAllocator();

    return [
      for (final glyph in glyphList) allocator.allocate(glyph.metadata.name!),
    ];
  }

  bool get _hasPackage => _package != null;

  /// Generates content for a class' file.
  String generate() {
    final members = [
      "static const iconFontFamily = '$_familyName';",
      if (_hasPackage) "static const iconFontPackage = '$_package';",
      for (var i = 0; i < glyphList.length; i++) ..._iconConstant(i),
    ];

    final body = members.map((e) => e.isEmpty ? '' : '$_indent$e').join('\n');

    return '${_header()}$_axisDocComment$_docComment'
        'abstract final class $_className {\n'
        '$body\n'
        '}\n';
  }

  List<String> _iconConstant(int index) {
    final metadata = glyphList[index].metadata;
    final hex = '0x${metadata.charCode!.toRadixString(16)}';

    return [
      '',
      '/// ${metadata.name!}',
      if (metadata.preview != null) ...[
        '///',
        '/// <img src="data:image/svg+xml;base64,${metadata.preview}" width="32"/>',
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

    // Added to the existing lines rather than replacing them, so that the
    // no-default wording stays exactly the string it has always been —
    // generated classes are committed files, and rewording one reruns every
    // user's diff. The "not the maximum" half earns its line: the maximum is
    // what this axis defaults to everywhere else, so a reader who knows the
    // convention would otherwise read the wrong width off the range.
    final defaultWidth = _defaultStrokeWidth;

    var defaultClause = '';
    var defaultLine = '';
    if (defaultWidth != null) {
      final formatted = _formatAxisValue(defaultWidth);
      defaultClause = ', default $formatted';
      defaultLine =
          '/// `Icon` with no `weight` draws $formatted, not the maximum.\n';
    }

    return '/// Variable stroke width: $min … $max (`wght` axis)'
        '$defaultClause.\n'
        '$defaultLine'
        '/// Set the width explicitly: '
        'Icon($_className.$exampleIcon, '
        'size: 16, weight: $min)\n'
        '///\n';
  }

  /// Formats axis values for generated docs: `2` reads as `2.0`, `1.33` as `1.33`.
  ///
  /// Every value this prints is meant to be copied into `weight:`, so it may
  /// never name a width the font does not have. Two decimals are enough for
  /// the widths icon sets are actually drawn at and read better than a raw
  /// `toString`, but they cannot be *rounded* to: at three decimals — the
  /// midpoint of `[1.33, 2]` is 1.665, which the size gate builds — 1.67 is a
  /// different instance from the default it would be labelling, and a range
  /// starting at 1.005 would print a minimum of 1.0 that sits below the axis
  /// and gets silently clamped. So two decimals are used only when they are
  /// lossless, and anything else falls back to the shortest decimal that
  /// round-trips.
  static String _formatAxisValue(double value) {
    final rounded = (value * 100).roundToDouble() / 100;

    if (rounded != value) {
      return value.toString();
    }

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
