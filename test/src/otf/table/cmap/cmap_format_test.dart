import 'package:fontify_plus/src/otf/table/cmap/cmap_format.dart';
import 'package:test/test.dart';

void main() {
  group('cmap format constants', () {
    test('are pairwise distinct', () {
      expect({kCmapFormat0, kCmapFormat4, kCmapFormat12}, hasLength(3));
    });
  });
}
