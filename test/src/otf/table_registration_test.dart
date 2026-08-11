import 'package:fontify_plus/src/otf/otf.dart';
import 'package:fontify_plus/src/utils/otf.dart';
import 'package:test/test.dart';

void main() {
  test('fvar and STAT are in the encode set', () {
    // Not a tautology: the encoder skips any tag missing from this set
    // silently, so a variable font would otherwise be written with no axis
    // and no error. This is the assertion that makes that unmissable.
    expect(debugTableTagsToEncode, contains(kFvarTag));
    expect(debugTableTagsToEncode, contains(kStatTag));
  });
}
