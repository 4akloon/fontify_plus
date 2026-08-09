import '../common/constant.dart';
import '../common/generic_glyph.dart';
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
  FlutterClassGenerator(
    this.glyphList, {
    String? className,
    String? familyName,
    String? fontFileName,
    String? package,
    int? indent,
  }) : _indent = ' ' * (indent ?? _kDefaultIndent),
       _className = toDartIdentifier(className ?? _kDefaultClassName),
       _familyName = familyName ?? kDefaultFontFamily,
       _fontFileName = fontFileName ?? _kDefaultFontFileName,
       _iconVarNames = _allocateNames(glyphList),
       _package = package?.isEmpty ?? true ? null : package;

  final List<GenericGlyph> glyphList;
  final String _fontFileName;
  final String _className;
  final String _familyName;
  final String _indent;
  final String? _package;
  final List<String> _iconVarNames;

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

    return '${_header()}$_docComment'
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
      '${_indent}$hex,',
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
