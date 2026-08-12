import 'package:fontify_plus/src/common/api.dart';
import 'package:fontify_plus/src/common/generic_glyph.dart';
import 'package:fontify_plus/src/common/stroke_width_range.dart';
import 'package:fontify_plus/src/otf/defaults.dart';
import 'package:fontify_plus/src/utils/flutter_class_gen.dart';
import 'package:test/test.dart';

GenericGlyph _glyph(String name, int charCode, {String? preview}) =>
    GenericGlyph.empty()
      ..metadata.name = name
      ..metadata.charCode = charCode
      ..metadata.preview = preview;

final _glyphList = [
  _glyph('arrow_up', 0xE001),
  _glyph('arrow_down', 0xE002),
];

void main() {
  group('FlutterClassGenerator.generate defaults', () {
    test('uses the default class name when none is given', () {
      final source = FlutterClassGenerator([_glyph('icon', 0xE001)]).generate();

      expect(source, contains('abstract final class fontify_plusIcons {'));
    });

    test('uses kDefaultFontFamily for iconFontFamily when none is given', () {
      final source = FlutterClassGenerator([_glyph('icon', 0xE001)]).generate();

      expect(
        source,
        contains("static const iconFontFamily = '$kDefaultFontFamily';"),
      );
    });

    test('omits the font package constant and argument when none is given', () {
      final source = FlutterClassGenerator([_glyph('icon', 0xE001)]).generate();

      expect(source, isNot(contains('iconFontPackage')));
      expect(source, isNot(contains('fontPackage:')));
    });

    test('indents members by 2 spaces by default', () {
      final source = FlutterClassGenerator([_glyph('icon', 0xE001)]).generate();

      expect(source, contains('\n  static const iconFontFamily'));
    });
  });

  group('FlutterClassGenerator.generate custom options', () {
    test('uses the given class name, family name, and indent', () {
      final source = FlutterClassGenerator(
        [_glyph('icon', 0xE001)],
        className: 'MyIcons',
        familyName: 'My Icon Font',
        indent: 4,
      ).generate();

      expect(source, contains('abstract final class MyIcons {'));
      expect(
        source,
        contains("static const iconFontFamily = 'My Icon Font';"),
      );
      expect(source, contains('\n    static const iconFontFamily'));
    });

    test('adds the font package constant and argument when given', () {
      final source = FlutterClassGenerator(
        [_glyph('icon', 0xE001)],
        package: 'design_system',
      ).generate();

      expect(
        source,
        contains("static const iconFontPackage = 'design_system';"),
      );
      expect(source, contains('fontPackage: iconFontPackage'));
    });

    test('treats an empty package string the same as no package', () {
      final source = FlutterClassGenerator(
        [_glyph('icon', 0xE001)],
        package: '',
      ).generate();

      expect(source, isNot(contains('iconFontPackage')));
    });

    test('mentions the given font file name in the doc comment', () {
      final source = FlutterClassGenerator(
        [_glyph('icon', 0xE001)],
        fontFileName: 'custom_icons.otf',
      ).generate();

      expect(source, contains('asset: fonts/custom_icons.otf'));
    });
  });

  group('FlutterClassGenerator icon members', () {
    test(
      'emits one IconData constant per glyph, named after its allocated identifier',
      () {
        final source = FlutterClassGenerator([
          _glyph('arrow_up', 0xE001),
          _glyph('arrow_down', 0xE002),
        ]).generate();

        expect(source, contains('static const IconData arrowUp ='));
        expect(source, contains('static const IconData arrowDown ='));
      },
    );

    test('encodes IconData with indented named arguments', () {
      final source = FlutterClassGenerator([_glyph('icon', 0xE001)]).generate();

      expect(
        source,
        contains(
          'static const IconData icon = IconData(\n'
          '    0xe001,\n'
          '    fontFamily: iconFontFamily,\n'
          '  );',
        ),
      );
    });

    test('includes fontPackage when a package is set', () {
      final source = FlutterClassGenerator(
        [_glyph('icon', 0xE001)],
        package: 'my_icons',
      ).generate();

      expect(
        source,
        contains(
          'static const IconData icon = IconData(\n'
          '    0xe001,\n'
          '    fontFamily: iconFontFamily,\n'
          '    fontPackage: iconFontPackage,\n'
          '  );',
        ),
      );
    });

    test('documents each constant with the glyph\'s original name', () {
      final source = FlutterClassGenerator([
        _glyph('arrow_up', 0xE001),
      ]).generate();

      expect(source, contains('/// arrow_up'));
    });

    test('emits an img dartdoc line when preview is set', () {
      final source = FlutterClassGenerator([
        _glyph('arrow_up', 0xE001, preview: 'cHJldmlldw=='),
      ]).generate();

      expect(
        source,
        contains(
          '/// <img src="data:image/svg+xml;base64,cHJldmlldw==" width="32"/>',
        ),
      );
    });

    test('omits img dartdoc when preview is null', () {
      final source = FlutterClassGenerator([
        _glyph('arrow_up', 0xE001),
      ]).generate();

      expect(source, isNot(contains('<img src=')));
    });
  });

  group('FlutterClassGenerator header', () {
    test('marks the file as generated and imports the widgets library', () {
      final source = FlutterClassGenerator([_glyph('icon', 0xE001)]).generate();

      expect(source, contains('// Generated code: do not hand-edit.'));
      expect(source, contains("import 'package:flutter/widgets.dart';"));
    });
  });

  group('FlutterClassGenerator variable stroke width', () {
    test('a variable font documents its axis in the class comment', () {
      final source = generateFlutterClass(
        glyphList: _glyphList,
        className: 'MyIcons',
        strokeWidthRange: StrokeWidthRange(1.33, 2),
      );

      expect(source, contains('Variable stroke width: 1.33 … 2.0'));
      expect(source, contains('wght'));
      expect(source, contains('Icon(MyIcons.'));
      expect(source, contains('weight: 1.33'));
    });

    test('a static font gains no axis lines at all', () {
      final source = generateFlutterClass(
        glyphList: _glyphList,
        className: 'MyIcons',
      );

      expect(source, isNot(contains('Variable stroke width')));
      expect(source, isNot(contains('wght')));
    });

    test('the class shape is unchanged either way', () {
      final variable = generateFlutterClass(
        glyphList: _glyphList,
        className: 'MyIcons',
        strokeWidthRange: StrokeWidthRange(1.33, 2),
      );

      expect(variable, contains('abstract final class MyIcons {'));
      expect(variable, contains('static const IconData'));
      expect(variable, isNot(contains('double strokeWidthFor')));
    });
  });
}
