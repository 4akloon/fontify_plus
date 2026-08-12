import 'package:fontify_plus/src/common/generic_glyph.dart';
import 'package:fontify_plus/src/otf/cff/cff2_region_context.dart';
import 'package:test/test.dart';

/// A triangle whose size stands in for one stroke-width master.
///
/// [width] only scales the outline; the command structure stays identical
/// across calls, which is what keeps two of these compatible as masters.
GenericGlyph _glyphAt(double width) => GenericGlyph.fromSvg(
  'icon',
  '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
      '<path d="M0 0 L${10 * width} 0 L${10 * width} ${10 * width} Z"/></svg>',
);

void main() {
  group('Cff2RegionContext', () {
    test('two masters get a one-region store', () {
      final context = Cff2RegionContext(1);

      expect(context.vstoreData, isNotNull);
      expect(context.vstoreData!.store.variationRegionList.regionCount, 1);
    });

    test('three masters get a two-region store', () {
      final context = Cff2RegionContext(2);

      expect(context.vstoreData, isNotNull);
      expect(context.vstoreData!.store.variationRegionList.regionCount, 2);
    });

    test('encodeAndBlend still requires masters.length - 1 == regionCount', () {
      final context = Cff2RegionContext(2);

      expect(
        () => context.encodeAndBlend([_glyphAt(1.5), _glyphAt(1.33)]), // only 2
        throwsArgumentError,
      );
    });
  });
}
