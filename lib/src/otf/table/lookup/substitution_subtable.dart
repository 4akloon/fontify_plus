import 'dart:typed_data';

import '../../../common/codable/binary.dart';
import '../../debugger.dart';
import 'ligature_substitution_subtable.dart';

/// One substitution rule set within a lookup.
abstract class SubstitutionSubtable implements BinaryCodable {
  const SubstitutionSubtable();

  /// Reads the subtable at [offset], or null when [lookupType] is one this
  /// package does not implement.
  static SubstitutionSubtable? fromByteData(
    ByteData byteData,
    int offset,
    int lookupType,
  ) {
    if (lookupType == 4) {
      return LigatureSubstitutionSubtable.fromByteData(byteData, offset);
    }

    debuggerOTF.debugUnsupportedTableFormat('Lookup', lookupType);

    return null;
  }

  int get maxContext;
}
