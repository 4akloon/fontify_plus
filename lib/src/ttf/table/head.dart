import 'dart:math' as math;
import 'dart:typed_data';

import '../../utils/exception.dart';
import '../../utils/ttf.dart';

import 'abstract.dart';
import 'all.dart';
import 'table_record_entry.dart';

const _kMagicNumber = 0x5F0F3CF5;
const _kMacStyleRegular = 0;
const _kIndexToLocFormatShort = 0;
const _kIndexToLocFormatLong = 1;

const _kUnitsPerEmDefault = 1028;
const _kLowestRecPPEMdefault = 8;

const _kHeaderTableSize = 54;

class HeaderTable extends FontTable {
  HeaderTable(
    TableRecordEntry entry,
    this.fontRevision, 
    this.checkSumAdjustment,
    this.flags,
    this.unitsPerEm,
    this.created,
    this.modified,
    this.xMin,
    this.yMin,
    this.xMax,
    this.yMax,
    this.macStyle,
    this.lowestRecPPEM,
    this.indexToLocFormat
  ) : 
    majorVersion = 1,
    minorVersion = 0,
    fontDirectionHint = 2,
    glyphDataFormat = 0,
    magicNumber = _kMagicNumber,
    super.fromTableRecordEntry(entry);

  HeaderTable._(
    TableRecordEntry entry, 
    this.majorVersion, 
    this.minorVersion, 
    this.fontRevision,
    this.checkSumAdjustment, 
    this.magicNumber, 
    this.flags, 
    this.unitsPerEm, 
    this.created, 
    this.modified, 
    this.xMin, 
    this.yMin, 
    this.xMax, 
    this.yMax, 
    this.macStyle,
    this.lowestRecPPEM,
    this.fontDirectionHint, 
    this.indexToLocFormat, 
    this.glyphDataFormat
  ) : super.fromTableRecordEntry(entry);

  factory HeaderTable.fromByteData(ByteData data, TableRecordEntry entry) => 
    HeaderTable._(
      entry,
      data.getUint16(entry.offset),
      data.getUint16(entry.offset + 2),
      Revision.fromInt32(data.getInt32(entry.offset + 4)),
      data.getUint32(entry.offset + 8),
      data.getUint32(entry.offset + 12),
      data.getUint16(entry.offset + 16),
      data.getUint16(entry.offset + 18),
      getDateTime(data.getInt64(entry.offset + 20)),
      getDateTime(data.getInt64(entry.offset + 28)),
      data.getInt16(entry.offset + 36),
      data.getInt16(entry.offset + 38),
      data.getInt16(entry.offset + 40),
      data.getInt16(entry.offset + 42),
      data.getUint16(entry.offset + 44),
      data.getUint16(entry.offset + 46),
      data.getInt16(entry.offset + 48),
      data.getInt16(entry.offset + 50),
      data.getInt16(entry.offset + 52)
    );

  factory HeaderTable.create(GlyphDataTable glyf, Revision revision) {
    if (revision == null || revision.int32value == 0) {
      throw TableDataFormatException('revision must not be null');
    }

    final now = DateTime.now();
    final glyphList = glyf.glyphList;

    final xMin = glyphList.fold<int>(0, (prev, glyph) => math.min(prev, glyph.header.xMin));
    final yMin = glyphList.fold<int>(0, (prev, glyph) => math.min(prev, glyph.header.yMin));
    final xMax = glyphList.fold<int>(0, (prev, glyph) => math.max(prev, glyph.header.xMax));
    final yMax = glyphList.fold<int>(0, (prev, glyph) => math.max(prev, glyph.header.yMax));
    
    return HeaderTable(
      null,
      revision,
      0,
      0x000B,
      _kUnitsPerEmDefault,
      now,
      now,
      xMin,
      yMin,
      xMax,
      yMax,
      _kMacStyleRegular,
      _kLowestRecPPEMdefault,
      glyf.size < 0x20000 ? _kIndexToLocFormatShort : _kIndexToLocFormatLong
    );
  }

  final int majorVersion;
  final int minorVersion;
  final Revision fontRevision;
  final int checkSumAdjustment;
  final int magicNumber;
  final int flags;
  final int unitsPerEm;
  final DateTime created;
  final DateTime modified;
  final int xMin;
  final int yMin;
  final int xMax;
  final int yMax;
  final int macStyle;
  final int lowestRecPPEM;
  final int fontDirectionHint;
  final int indexToLocFormat;
  final int glyphDataFormat;

  int get size => _kHeaderTableSize;
}