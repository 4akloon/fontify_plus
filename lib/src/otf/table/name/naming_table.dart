import 'dart:typed_data';

import '../../../utils/otf.dart';
import '../../debugger.dart';
import '../abstract.dart';
import '../table_record_entry.dart';
import 'name_id.dart';
import 'naming_table_format0.dart';

const kNameFormat0 = 0x0;

/// The `name` table: the font's human-readable strings.
abstract class NamingTable extends FontTable {
  NamingTable.fromTableRecordEntry(super.entry) : super.fromTableRecordEntry();

  static NamingTable? fromByteData(ByteData byteData, TableRecordEntry entry) {
    final format = byteData.getUint16(entry.offset);

    if (format == kNameFormat0) {
      return NamingTableFormat0.fromByteData(byteData, entry);
    }

    debuggerOTF.debugUnsupportedTableFormat(kNameTag, format);

    return null;
  }

  /// Builds a `name` table.
  ///
  /// * [axisName], when given, is written under [NameID.strokeWidthAxis] so
  /// `fvar`'s `axisNameID` and `STAT`'s `valueNameID` resolve to a string —
  /// OTS rejects a variable font whose name table is missing it. Omitted for
  /// a static font, which carries no axis to name.
  static NamingTable? create(
    String fontName,
    String? description,
    Revision revision, {
    int format = kNameFormat0,
    String? axisName,
  }) {
    if (format == kNameFormat0) {
      return NamingTableFormat0.create(
        fontName,
        description,
        revision,
        axisName: axisName,
      );
    }

    debuggerOTF.debugUnsupportedTableFormat(kNameTag, format);

    return null;
  }

  String get familyName;

  String? getStringByNameId(NameID nameId);
}
