import 'dart:typed_data';

import '../../utils/otf.dart';
import '../debugger.dart';

import 'abstract.dart';
import 'glyf.dart';
import 'table_record_entry.dart';

const _kVersion0 = 0x00005000;
const _kVersion1 = 0x00010000;

const _kTableSizeForVersion = {
  _kVersion0: 6,
  _kVersion1: 32,
};

class MaximumProfileTable extends FontTable {
  MaximumProfileTable.v0(super.entry, this.numGlyphs)
    : version = _kVersion0,
      maxPoints = null,
      maxContours = null,
      maxCompositePoints = null,
      maxCompositeContours = null,
      maxZones = null,
      maxTwilightPoints = null,
      maxStorage = null,
      maxFunctionDefs = null,
      maxInstructionDefs = null,
      maxStackElements = null,
      maxSizeOfInstructions = null,
      maxComponentElements = null,
      maxComponentDepth = null,
      super.fromTableRecordEntry();

  MaximumProfileTable.v1(
    super.entry, {
    required this.numGlyphs,
    required this.maxPoints,
    required this.maxContours,
    required this.maxCompositePoints,
    required this.maxCompositeContours,
    required this.maxZones,
    required this.maxTwilightPoints,
    required this.maxStorage,
    required this.maxFunctionDefs,
    required this.maxInstructionDefs,
    required this.maxStackElements,
    required this.maxSizeOfInstructions,
    required this.maxComponentElements,
    required this.maxComponentDepth,
  }) : version = _kVersion1,
       super.fromTableRecordEntry();

  factory MaximumProfileTable.create(int numGlyphs, GlyphDataTable? glyf) {
    final isOpenType = glyf == null;

    if (isOpenType) {
      return MaximumProfileTable.v0(null, numGlyphs);
    }

    return MaximumProfileTable.v1(
      null,
      numGlyphs: numGlyphs,
      maxPoints: glyf.maxPoints,
      maxContours: glyf.maxContours,
      maxCompositePoints: 0, // Composite glyphs are not supported
      maxCompositeContours: 0, // Composite glyphs are not supported
      maxZones: 2, // The twilight zone is used
      maxTwilightPoints: 0, // 0 max points for the twilight zone
      /// Constants taken from FontForge
      maxStorage: 1,
      maxFunctionDefs: 1,
      maxInstructionDefs: 0,
      maxStackElements: 64,
      maxSizeOfInstructions: glyf.maxSizeOfInstructions,
      maxComponentElements: 0,
      maxComponentDepth: 0,
    );
  }

  static MaximumProfileTable? fromByteData(
    ByteData data,
    TableRecordEntry entry,
  ) {
    final version = data.getInt32(entry.offset);

    if (version == _kVersion0) {
      return MaximumProfileTable.v0(entry, data.getUint16(entry.offset + 4));
    }
    if (version == _kVersion1) {
      return MaximumProfileTable.v1(
        entry,
        numGlyphs: data.getUint16(entry.offset + 4),
        maxPoints: data.getUint16(entry.offset + 6),
        maxContours: data.getUint16(entry.offset + 8),
        maxCompositePoints: data.getUint16(entry.offset + 10),
        maxCompositeContours: data.getUint16(entry.offset + 12),
        maxZones: data.getUint16(entry.offset + 14),
        maxTwilightPoints: data.getUint16(entry.offset + 16),
        maxStorage: data.getUint16(entry.offset + 18),
        maxFunctionDefs: data.getUint16(entry.offset + 20),
        maxInstructionDefs: data.getUint16(entry.offset + 22),
        maxStackElements: data.getUint16(entry.offset + 24),
        maxSizeOfInstructions: data.getUint16(entry.offset + 26),
        maxComponentElements: data.getUint16(entry.offset + 28),
        maxComponentDepth: data.getUint16(entry.offset + 30),
      );
    } else {
      debuggerOTF.debugUnsupportedTableVersion(entry.tag, version);
      return null;
    }
  }

  // Version 0.5
  final int version;
  final int numGlyphs;

  // Version 1.0
  final int? maxPoints;
  final int? maxContours;
  final int? maxCompositePoints;
  final int? maxCompositeContours;
  final int? maxZones;
  final int? maxTwilightPoints;
  final int? maxStorage;
  final int? maxFunctionDefs;
  final int? maxInstructionDefs;
  final int? maxStackElements;
  final int? maxSizeOfInstructions;
  final int? maxComponentElements;
  final int? maxComponentDepth;

  @override
  void encodeToBinary(ByteData byteData) {
    byteData
      ..setInt32(0, version)
      ..setUint16(4, numGlyphs);

    if (version == _kVersion1) {
      byteData
        ..setUint16(6, maxPoints!)
        ..setUint16(8, maxContours!)
        ..setUint16(10, maxCompositePoints!)
        ..setUint16(12, maxCompositeContours!)
        ..setUint16(14, maxZones!)
        ..setUint16(16, maxTwilightPoints!)
        ..setUint16(18, maxStorage!)
        ..setUint16(20, maxFunctionDefs!)
        ..setUint16(22, maxInstructionDefs!)
        ..setUint16(24, maxStackElements!)
        ..setUint16(26, maxSizeOfInstructions!)
        ..setUint16(28, maxComponentElements!)
        ..setUint16(30, maxComponentDepth!);
    } else if (version != _kVersion0) {
      debuggerOTF.debugUnsupportedTableVersion(kMaxpTag, version);
    }
  }

  @override
  int get size => _kTableSizeForVersion[version]!;
}
