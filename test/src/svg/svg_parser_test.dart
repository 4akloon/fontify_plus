import 'dart:async';

import 'package:fontify_plus/src/svg/stroke/stroke_properties.dart';
import 'package:fontify_plus/src/svg/svg_parser.dart';
import 'package:fontify_plus/src/utils/exception.dart';
import 'package:fontify_plus/src/utils/logger.dart';
import 'package:test/test.dart';
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart' as vg;

SvgGeometry parse(String body, {String viewBox = '0 0 24 24'}) =>
    parseSvgGeometry(
      'icon',
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="$viewBox">$body</svg>',
    );

void main() {
  group('parseSvgGeometry viewport', () {
    test('reports the viewport extent', () {
      final geometry = parse('<path d="M0 0 H1"/>', viewBox: '0 0 16 32');

      expect(geometry.width, 16);
      expect(geometry.height, 32);
    });

    test('normalises a viewBox with a non-zero minimum', () {
      // vgc folds the minimum into the coordinates, so the extent is a size
      // and the geometry has already been shifted onto the origin.
      final geometry = parse('<path d="M-4 -4 H4"/>', viewBox: '-8 -8 16 16');

      expect(geometry.width, 16);
      expect(geometry.height, 16);
      expect(geometry.shapes, hasLength(1));
    });

    test('accepts width and height with no viewBox', () {
      final geometry = parseSvgGeometry(
        'icon',
        '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32">'
            '<path d="M0 0 H32"/></svg>',
      );

      expect(geometry.width, 32);
    });
  });

  group('parseSvgGeometry shapes', () {
    test('converts shape elements to paths', () {
      final geometry = parse('<circle cx="8" cy="8" r="4"/>');

      expect(geometry.shapes, hasLength(1));
      expect(geometry.shapes.single.filled, isTrue);
    });

    test('expands use and defs', () {
      final geometry = parse(
        '<defs><path id="s" d="M0 0 H8 V8 H0 Z"/></defs>'
        '<use href="#s" x="2" y="2"/>',
      );

      expect(geometry.shapes, hasLength(1));
    });

    test('reads presentation properties from a style attribute', () {
      // Illustrator and some Figma exports write stroke properties this way.
      // Ignoring style= is what made such icons come out blank.
      final geometry = parse(
        '<path style="fill:none;stroke:#000;stroke-width:1.5;'
        'stroke-linecap:square" d="M4 4 L20 20"/>',
      );

      final shape = geometry.shapes.single;
      expect(shape.filled, isFalse);
      expect(shape.stroke!.width, 1.5);
      expect(shape.stroke!.cap, LineCap.square);
    });

    test('reports a filled and stroked path once, carrying both', () {
      final geometry = parse(
        '<path d="M2 2 H22 V22 H2 Z" fill="#f00" stroke="#00f" '
        'stroke-width="3"/>',
      );

      final shape = geometry.shapes.single;
      expect(shape.filled, isTrue);
      expect(shape.stroke, isNotNull);
    });

    test('drops a path that paints nothing', () {
      // fill="none" with no stroke encloses no ink. Keeping it produced a
      // filled glyph from geometry the author had switched off.
      final geometry = parse('<path fill="none" d="M2 2 H10 V10 H2 Z"/>');

      expect(geometry.shapes, isEmpty);
    });

    test('drops a path whose fill is fully transparent', () {
      // vgc reports a transparent fill as a Fill with zero alpha, not as no
      // fill. Icon sets use this for invisible hit targets, which would
      // otherwise fill the whole glyph.
      expect(
        parse('<path fill="#00000000" d="M0 0 H24 V24 H0 Z"/>').shapes,
        isEmpty,
      );
      expect(
        parse(
          '<path fill="#000" fill-opacity="0" d="M0 0 H24 V24 H0 Z"/>',
        ).shapes,
        isEmpty,
      );
    });

    test('drops a path whose stroke is fully transparent', () {
      expect(
        parse(
          '<path fill="none" stroke="#000" stroke-opacity="0" '
          'd="M0 12 H24"/>',
        ).shapes,
        isEmpty,
      );
    });

    test('keeps a path filled with a gradient', () {
      // A gradient paints whatever its stops say, so the base colour's alpha
      // must not be what decides.
      final geometry = parse(
        '<defs><linearGradient id="g"><stop offset="0" stop-color="#000"/>'
        '<stop offset="1" stop-color="#fff"/></linearGradient></defs>'
        '<path fill="url(#g)" d="M0 0 H24 V24 H0 Z"/>',
      );

      expect(geometry.shapes, hasLength(1));
      expect(geometry.shapes.single.filled, isTrue);
    });

    test('preserves the evenodd fill rule', () {
      final geometry = parse(
        '<path fill-rule="evenodd" d="M2 2h20v20H2Z M6 6h12v12H6Z"/>',
      );

      expect(geometry.shapes.single.path.fillType, vg.PathFillType.evenOdd);
    });

    test('applies stroke-dasharray', () {
      // vgc cuts the path into dashes, and each dash is outlined separately.
      // Previously the attribute was ignored and the stroke came out solid.
      final solid = parse(
        '<path stroke="#000" fill="none" stroke-width="2" d="M0 12 H24"/>',
      );
      final dashed = parse(
        '<path stroke="#000" fill="none" stroke-width="2" '
        'stroke-dasharray="4 2" d="M0 12 H24"/>',
      );

      expect(
        dashed.shapes.single.path.commands.length,
        greaterThan(solid.shapes.single.path.commands.length),
      );
    });

    test('returns no shapes for an empty svg', () {
      expect(parse('').shapes, isEmpty);
    });
  });

  group('parseSvgGeometry masks and clips', () {
    test('does not treat a mask shape as ink', () {
      // The command stream is saveLayer, content, mask, mask shape, restore,
      // restore. Walking path commands naively draws the mask itself.
      final geometry = parse(
        '<defs><mask id="m"><rect width="12" height="24" fill="#fff"/></mask>'
        '</defs><g mask="url(#m)"><path d="M0 0 H24 V24 H0 Z"/></g>',
      );

      expect(geometry.shapes, hasLength(1));
    });

    test('keeps drawing after a mask region ends', () {
      final geometry = parse(
        '<defs><mask id="m"><rect width="12" height="24" fill="#fff"/></mask>'
        '</defs><g mask="url(#m)"><path d="M0 0 H24 V24 H0 Z"/></g>'
        '<path d="M0 0 H4 V4 H0 Z"/>',
      );

      expect(geometry.shapes, hasLength(2));
    });

    test('does not leak mask geometry when the mask contains a clip', () {
      // The stream becomes saveLayer, content, mask, clip, mask shape, restore,
      // mask shape, restore, restore. A depth counter decrements on the clip's
      // own restore and lets the rest of the mask through as ink.
      final geometry = parse(
        '<defs><clipPath id="c"><rect width="6" height="24"/></clipPath>'
        '<mask id="m"><g clip-path="url(#c)">'
        '<rect width="12" height="24" fill="#fff"/></g>'
        '<rect x="12" width="12" height="24" fill="#fff"/></mask></defs>'
        '<g mask="url(#m)"><path d="M0 0 H24 V24 H0 Z"/></g>',
      );

      expect(geometry.shapes, hasLength(1));
    });

    test('does not leak mask geometry when the mask contains a group', () {
      // An opacity group inside the mask emits its own saveLayer/restore pair,
      // with the same effect on a depth counter as the clip above.
      final geometry = parse(
        '<defs><mask id="m"><g opacity="0.5">'
        '<rect width="12" height="24" fill="#fff"/></g>'
        '<rect x="12" width="12" height="24" fill="#fff"/></mask></defs>'
        '<g mask="url(#m)"><path d="M0 0 H24 V24 H0 Z"/></g>',
      );

      expect(geometry.shapes, hasLength(1));
    });

    test('keeps a clip path out of the ink', () {
      final geometry = parse(
        '<defs><clipPath id="c"><rect width="12" height="24"/></clipPath></defs>'
        '<g clip-path="url(#c)"><path d="M0 0 H24 V24 H0 Z"/></g>',
      );

      expect(geometry.shapes, hasLength(1));
    });
  });

  group('parseSvgGeometry warnings', () {
    late List<String> printed;
    late Level previousLevel;

    setUp(() {
      previousLevel = logger.level;
      logger.level = Level.trace;
      printed = [];
    });

    tearDown(() => logger.level = previousLevel);

    /// Runs [body] capturing everything the logger prints.
    void capturingPrints(void Function() body) => runZoned(
      body,
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, line) => printed.add(line),
      ),
    );

    test('warns that a clip path was dropped, naming the icon', () {
      capturingPrints(
        () => parseSvgGeometry(
          'clipped_icon',
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
              '<defs><clipPath id="c"><rect width="12" height="24"/></clipPath>'
              '</defs><g clip-path="url(#c)">'
              '<path d="M0 0 H24 V24 H0 Z"/></g></svg>',
        ),
      );

      expect(
        printed.join('\n'),
        allOf(contains('clipped_icon'), contains('clip')),
      );
    });

    test('warns that text was dropped, naming the icon', () {
      capturingPrints(
        () => parseSvgGeometry(
          'texty_icon',
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
              '<text x="2" y="12" font-size="10">Hi</text></svg>',
        ),
      );

      expect(
        printed.join('\n'),
        allOf(contains('texty_icon'), contains('text')),
      );
    });

    test('says nothing for an icon it fully understands', () {
      capturingPrints(
        () => parseSvgGeometry(
          'plain_icon',
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
              '<path d="M0 0 H24 V24 H0 Z" fill="#000"/></svg>',
        ),
      );

      expect(printed, isEmpty);
    });
  });

  group('parseSvgGeometry errors', () {
    test('wraps a malformed viewBox, naming the icon', () {
      expect(
        () => parse('<path d="M0 0 H1"/>', viewBox: '24 24'),
        throwsA(
          isA<SvgParserException>().having(
            (e) => e.message,
            'message',
            allOf(contains('icon'), contains('viewBox')),
          ),
        ),
      );
    });

    test('wraps missing dimensions', () {
      expect(
        () => parseSvgGeometry(
          'icon',
          '<svg xmlns="http://www.w3.org/2000/svg"><path d="M0 0 H1"/></svg>',
        ),
        throwsA(isA<SvgParserException>()),
      );
    });

    test('wraps malformed XML', () {
      expect(
        () => parseSvgGeometry('icon', '<svg viewBox="0 0 1 1"><path d="M0 0"'),
        throwsA(isA<SvgParserException>()),
      );
    });

    test('wraps a non-SVG document', () {
      expect(
        () => parseSvgGeometry('icon', '<html><body>nope</body></html>'),
        throwsA(isA<SvgParserException>()),
      );
    });
  });
}
