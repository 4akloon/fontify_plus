import 'dart:typed_data';

import 'package:fontify_plus/src/otf/table/post/post_script_data.dart';
import 'package:fontify_plus/src/otf/table/post/post_script_table_header.dart';
import 'package:fontify_plus/src/otf/table/post/post_script_version_20.dart';
import 'package:fontify_plus/src/utils/otf.dart';
import 'package:test/test.dart';

void main() {
  group('PostScriptVersion30', () {
    test('has zero size and encodes nothing', () {
      final data = PostScriptVersion30();

      expect(data.size, 0);
      expect(() => data.encodeToBinary(ByteData(0)), returnsNormally);
    });

    test('reports version 3.0', () {
      final data = PostScriptVersion30();

      expect(data.version.major, 3);
      expect(data.version.minor, 0);
    });
  });

  group('PostScriptData.fromByteData', () {
    test('dispatches version 2.0 headers to PostScriptVersion20', () {
      final header = PostScriptTableHeader.create(const Revision(2, 0));
      final v20 = PostScriptVersion20.create(['a']);
      final bytes = ByteData(v20.size);
      v20.encodeToBinary(bytes);

      final decoded = PostScriptData.fromByteData(bytes, 0, header);

      expect(decoded, isA<PostScriptVersion20>());
    });

    test('dispatches version 3.0 headers to PostScriptVersion30', () {
      final header = PostScriptTableHeader.create(const Revision(3, 0));

      final decoded = PostScriptData.fromByteData(ByteData(0), 0, header);

      expect(decoded, isA<PostScriptVersion30>());
    });

    test('returns null for an unsupported version', () {
      final header = PostScriptTableHeader.create(const Revision(1, 0));

      final decoded = PostScriptData.fromByteData(ByteData(0), 0, header);

      expect(decoded, isNull);
    });
  });
}
