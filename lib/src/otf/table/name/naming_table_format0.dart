import 'dart:typed_data';

import '../../../common/constant.dart';
import '../../../utils/otf.dart';
import '../table_record_entry.dart';
import 'name_id.dart';
import 'name_record.dart';
import 'name_string_codec.dart';
import 'naming_table.dart';
import 'naming_table_format0_header.dart';

/// Record templates to write, sorted by platform and encoding ID.
///
/// Every string is written once per template, so a consumer on either platform
/// finds it.
const _kNameRecordTemplateList = [
  /// Macintosh English with Roman encoding
  NameRecord.template(
    platformID: kPlatformMacintosh,
    encodingID: 0,
    languageID: 0,
  ),

  /// Windows English (US) with UTF-16BE encoding
  NameRecord.template(
    platformID: kPlatformWindows,
    encodingID: 1,
    languageID: 0x0409,
  ),
];

class NamingTableFormat0 extends NamingTable {
  NamingTableFormat0(super.entry, this.header, this.stringList)
    : super.fromTableRecordEntry();

  factory NamingTableFormat0.create(
    String fontName,
    String? description,
    Revision revision, {
    String? axisName,
  }) {
    final stringForNameMap = _defaultStrings(
      fontName,
      description,
      revision,
      axisName,
    );

    final stringList = [
      for (var i = 0; i < _kNameRecordTemplateList.length; i++)
        ...stringForNameMap.values,
    ];

    final recordList = <NameRecord>[];
    var stringOffset = 0;

    for (final template in _kNameRecordTemplateList) {
      final encode = encoderFor(template);

      for (final entry in stringForNameMap.entries) {
        final units = encode(entry.value);

        recordList.add(
          template.copyWith(
            nameID: kNameIDmap.getValueForKey(entry.key),
            length: units.length,
            offset: stringOffset,
          ),
        );

        stringOffset += units.length;
      }
    }

    return NamingTableFormat0(
      null,
      NamingTableFormat0Header.create(recordList),
      stringList,
    );
  }

  static NamingTableFormat0? fromByteData(
    ByteData byteData,
    TableRecordEntry entry,
  ) {
    final header = NamingTableFormat0Header.fromByteData(byteData, entry);

    if (header == null) {
      return null;
    }

    final storageAreaOffset = entry.offset + header.size;

    final stringList = [
      for (final record in header.nameRecordList)
        decoderFor(record)(
          List.generate(
            record.length,
            (i) => byteData.getUint8(storageAreaOffset + record.offset + i),
          ),
        ),
    ];

    return NamingTableFormat0(entry, header, stringList);
  }

  /// Values for name ids in sorted order
  ///
  /// [axisName], when given, is appended last: iteration order here is
  /// record order, and 256 ([NameID.strokeWidthAxis]) is the highest ID
  /// this package writes, so appending keeps every platform's records
  /// sorted by nameID as the `name` table spec requires.
  static Map<NameID, String> _defaultStrings(
    String fontName,
    String? description,
    Revision revision,
    String? axisName,
  ) => {
    NameID.copyright: 'Copyright $kVendorName ${DateTime.now().year}',
    NameID.fontFamily: fontName,
    NameID.fontSubfamily: 'Regular',
    NameID.uniqueID: fontName,
    NameID.fullFontName: fontName,
    NameID.version: 'Version ${revision.major}.${revision.minor}',
    NameID.postScriptName: fontName.getPostScriptString(),
    NameID.manufacturer: kVendorName,
    NameID.description: description ?? 'Generated using $kVendorName',
    NameID.urlVendor: kVendorUrl,
    NameID.strokeWidthAxis: ?axisName,
  };

  final NamingTableFormat0Header header;
  final List<String> stringList;

  @override
  String get familyName => getStringByNameId(NameID.fontFamily)!;

  @override
  int get size =>
      header.size + header.nameRecordList.fold<int>(0, (p, r) => p + r.length);

  @override
  String? getStringByNameId(NameID nameId) {
    final nameID = kNameIDmap.getValueForKey(nameId);
    final index = header.nameRecordList.indexWhere((e) => e.nameID == nameID);

    return index == -1 ? null : stringList[index];
  }

  @override
  void encodeToBinary(ByteData byteData) {
    header.encodeToBinary(byteData.sublistView(0, header.size));

    final storageAreaOffset = header.size;

    for (var i = 0; i < header.nameRecordList.length; i++) {
      final record = header.nameRecordList[i];

      var charOffset = storageAreaOffset + record.offset;

      for (final charCode in encoderFor(record)(stringList[i])) {
        byteData.setUint8(charOffset++, charCode);
      }
    }
  }
}
