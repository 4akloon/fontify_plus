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

    test('the axis lines are byte-for-byte what they have always been', () {
      // Pinned verbatim, not by `contains`: Step 4 of this feature adds a
      // second wording for the interior-default case, and the no-default
      // wording must come out of that change untouched — generated files are
      // committed by users, so a stray comma rewrites every one of them.
      final source = generateFlutterClass(
        glyphList: _glyphList,
        className: 'MyIcons',
        strokeWidthRange: StrokeWidthRange(1.33, 2),
      );

      expect(
        source,
        contains(
          '/// Variable stroke width: 1.33 … 2.0 (`wght` axis).\n'
          '/// Set the width explicitly: '
          'Icon(MyIcons.arrowUp, size: 16, weight: 1.33)\n'
          '///\n',
        ),
      );
    });

    test('an interior default is named alongside the range', () {
      final source = generateFlutterClass(
        glyphList: _glyphList,
        className: 'MyIcons',
        strokeWidthRange: StrokeWidthRange(1.33, 2),
        defaultStrokeWidth: 1.5,
      );

      expect(
        source,
        contains(
          '/// Variable stroke width: 1.33 … 2.0 (`wght` axis), default 1.5.\n'
          '/// `Icon` with no `weight` draws 1.5, not the maximum.\n'
          '/// Set the width explicitly: '
          'Icon(MyIcons.arrowUp, size: 16, weight: 1.33)\n'
          '///\n',
        ),
      );
    });

    test('a default two decimals cannot represent is named in full', () {
      // 1.665 is the midpoint of [1.33, 2] and what the size gate builds, so
      // this is not a contrived value. Rounded to 1.67 the comment would name
      // a width the font does not default to: a reader who copies it into
      // `weight:` gets a different instance from the one the comment calls
      // the default. The axis value has to survive the round trip.
      final source = generateFlutterClass(
        glyphList: _glyphList,
        className: 'MyIcons',
        strokeWidthRange: StrokeWidthRange(1.33, 2),
        defaultStrokeWidth: 1.665,
      );

      expect(source, contains('default 1.665.'));
      expect(source, contains('draws 1.665, not the maximum'));
      expect(source, isNot(contains('1.67')));
    });

    test('a range endpoint two decimals cannot represent is named in full', () {
      // The same rounding reaches the endpoints, where it is worse: rounded
      // to 1.0 the copy-paste line would hand the reader a `weight:` *below*
      // the axis minimum, which the renderer silently clamps.
      final source = generateFlutterClass(
        glyphList: _glyphList,
        className: 'MyIcons',
        strokeWidthRange: StrokeWidthRange(1.005, 2),
      );

      expect(source, contains('Variable stroke width: 1.005 … 2.0'));
      expect(source, contains('weight: 1.005)'));
    });

    test('a default width without a range documents no axis at all', () {
      // `svgToOtf` rejects this pairing, but `generateFlutterClass` is a
      // separate public entry point that never sees the font: with no range
      // there is no axis to place the default on, so there is nothing
      // truthful to say about it.
      final source = generateFlutterClass(
        glyphList: _glyphList,
        className: 'MyIcons',
        defaultStrokeWidth: 1.5,
      );

      expect(source, isNot(contains('Variable stroke width')));
      expect(source, isNot(contains('default 1.5')));
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
