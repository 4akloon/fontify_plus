import 'dart:typed_data';

import '../../../common/generic_glyph.dart';
import '../../../utils/otf.dart';
import '../abstract.dart';
import '../table_record_entry.dart';
import 'post_script_data.dart';
import 'post_script_table_header.dart';
import 'post_script_version_20.dart';

/// The `post` table: PostScript metadata and, optionally, glyph names.
class PostScriptTable extends FontTable {
  PostScriptTable(super.entry, this.header, this.data)
    : super.fromTableRecordEntry();

  factory PostScriptTable.fromByteData(
    ByteData byteData,
    TableRecordEntry entry,
  ) {
    final header = PostScriptTableHeader.fromByteData(byteData, entry);

    return PostScriptTable(
      entry,
      header,
      PostScriptData.fromByteData(
        byteData,
        entry.offset + kPostHeaderSize,
        header,
      ),
    );
  }

  /// Creates post table.
  ///
  /// [glyphList] contains non-default characters.
  /// If [usePostV2] is true, version 2 table is generated.
  factory PostScriptTable.create(List<GenericGlyph> glyphList, bool usePostV2) {
    final data = usePostV2
        ? PostScriptVersion20.create(
            [for (final glyph in glyphList) glyph.metadata.name ?? ''],
          )
        : const PostScriptVersion30();

    return PostScriptTable(
      null,
      PostScriptTableHeader.create(data.version),
      data,
    );
  }

  final PostScriptTableHeader header;
  final PostScriptData? data;

  @override
  int get size => header.size + (data?.size ?? 0);

  @override
  void encodeToBinary(ByteData byteData) {
    header.encodeToBinary(byteData);
    data?.encodeToBinary(byteData.sublistView(header.size, data!.size));
  }
}
