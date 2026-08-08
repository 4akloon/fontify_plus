import 'dart:typed_data';

import '../../../utils/otf.dart';
import '../abstract.dart';
import '../feature_list.dart';
import '../lookup.dart';
import '../script_list.dart';
import '../table_record_entry.dart';
import 'gsub_header.dart';

/// The `GSUB` table: which scripts, features and lookups the font declares.
///
/// Written with one empty ligature lookup. An icon font substitutes nothing,
/// but the table has to be well formed for the font to validate.
class GlyphSubstitutionTable extends FontTable {
  GlyphSubstitutionTable(
    super.entry,
    this.header,
    this.scriptListTable,
    this.featureListTable,
    this.lookupListTable,
  ) : super.fromTableRecordEntry();

  factory GlyphSubstitutionTable.fromByteData(
    ByteData byteData,
    TableRecordEntry entry,
  ) {
    final header = GlyphSubstitutionTableHeader.fromByteData(byteData, entry);

    return GlyphSubstitutionTable(
      entry,
      header,
      ScriptListTable.fromByteData(
        byteData,
        entry.offset + header.scriptListOffset!,
      ),
      FeatureListTable.fromByteData(
        byteData,
        entry.offset + header.featureListOffset!,
      ),
      LookupListTable.fromByteData(
        byteData,
        entry.offset + header.lookupListOffset!,
      ),
    );
  }

  factory GlyphSubstitutionTable.create() => GlyphSubstitutionTable(
        null,
        GlyphSubstitutionTableHeader.create(),
        ScriptListTable.create(),
        FeatureListTable.create(),
        LookupListTable.create(),
      );

  final GlyphSubstitutionTableHeader header;

  final ScriptListTable scriptListTable;
  final FeatureListTable featureListTable;
  final LookupListTable lookupListTable;

  @override
  int get size =>
      header.size +
      scriptListTable.size +
      featureListTable.size +
      lookupListTable.size;

  @override
  void encodeToBinary(ByteData byteData) {
    var relativeOffset = header.size;

    scriptListTable.encodeToBinary(
      byteData.sublistView(relativeOffset, scriptListTable.size),
    );
    header.scriptListOffset = relativeOffset;
    relativeOffset += scriptListTable.size;

    featureListTable.encodeToBinary(
      byteData.sublistView(relativeOffset, featureListTable.size),
    );
    header.featureListOffset = relativeOffset;
    relativeOffset += featureListTable.size;

    lookupListTable.encodeToBinary(
      byteData.sublistView(relativeOffset, lookupListTable.size),
    );
    header.lookupListOffset = relativeOffset;

    header.encodeToBinary(byteData.sublistView(0, header.size));
  }
}
