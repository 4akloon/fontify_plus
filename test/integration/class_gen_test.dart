import 'package:fontify_plus/fontify_plus.dart';
import 'package:test/test.dart';

const _svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16">
<path d="M3 3 H13 V13 H3 Z" fill="#000" />
</svg>
''';

/// Runs the real pipeline: char codes are assigned while building the font, so
/// the class generator cannot be exercised on bare glyphs.
String generate(List<String> names, {String? package}) {
  final result = svgToOtf(
    svgMap: {for (final name in names) name: _svg},
    fontName: 'My Icons',
  );

  return generateFlutterClass(
    glyphList: result.glyphList,
    className: 'MyIcons',
    familyName: result.font.familyName,
    package: package,
    fontFileName: 'MyIcons.otf',
  );
}

/// Names of the generated `static const IconData` members.
List<String> memberNames(String source) => RegExp(
  r'static const IconData (\w+) =',
).allMatches(source).map((m) => m.group(1)!).toList();

void main() {
  group('FlutterClassGenerator', () {
    test('names members in lowerCamelCase', () {
      // Dart's convention for constants. snake_case members trip
      // `constant_identifier_names` in any project using standard lints, which
      // makes the generated file fail analysis in its consumer.
      final source = generate([
        'arrow_down_01',
        'more_vertical',
        'alert_02',
        'text_align_left_01',
      ]);

      expect(
        memberNames(source),
        containsAll([
          'arrowDown01',
          'moreVertical',
          'alert02',
          'textAlignLeft01',
        ]),
      );
    });

    test('emits no member containing an underscore', () {
      final source = generate(['a_b', 'c-d', 'e f']);

      expect(memberNames(source), everyElement(isNot(contains('_'))));
    });

    test('disambiguates colliding names without breaking camelCase', () {
      // "arrow-up" and "arrow_up" both normalize to "arrowUp".
      final source = generate(['arrow-up', 'arrow_up', 'arrow up']);
      final names = memberNames(source);

      expect(names.toSet(), hasLength(names.length), reason: 'must be unique');
      expect(names, everyElement(isNot(contains('_'))));
      expect(names.first, 'arrowUp');
    });

    test('does not reuse a trailing digit as a collision counter', () {
      // `alert_02` becomes `alert02`; a duplicate must not be handed `alert03`,
      // which usually names a different icon in the same set.
      final source = generate(['alert_02', 'alert-02']);

      expect(memberNames(source), isNot(contains('alert03')));
    });

    test('declares the class abstract final', () {
      // `abstract final` states the intent directly: the class is a namespace
      // of constants, so it can be neither instantiated nor extended. A private
      // constructor only blocks the first, and leaves an unused member behind.
      final source = generate(['icon']);

      expect(source, contains('abstract final class MyIcons {'));
      expect(source, isNot(contains('MyIcons._()')));
    });

    test('declares the font package when one is given', () {
      final source = generate(['icon'], package: 'design_system');

      expect(
        source,
        contains("static const fontPackage = 'design_system'"),
      );
      expect(source, contains('fontPackage: fontPackage'));
    });

    test('omits the font package when none is given', () {
      final source = generate(['icon']);

      expect(source, isNot(contains('fontPackage')));
    });
  });
}
