import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fontify_plus/src/common/generic_glyph.dart';
import 'package:fontify_plus/src/otf/io.dart';
import 'package:fontify_plus/src/otf/otf.dart';
import 'package:fontify_plus/src/otf/reader.dart';
import 'package:fontify_plus/src/otf/table/all.dart';
import 'package:fontify_plus/src/utils/misc.dart';
import 'package:fontify_plus/src/utils/otf.dart';
import 'package:test/test.dart';

import '../constant.dart';
import 'fixtures/ttf_expected_data.dart';

const _kTestFontAssetPath = '$kTestAssetsDir/test_font.ttf';
const _kTestCFF2fontAssetPath = '$kTestAssetsDir/test_cff2_font.otf';

void main() {
  late OpenTypeFont font;

  group('Reader', () {
    setUpAll(() {
      font = readFromFile(_kTestFontAssetPath);
    });

    test('Offset table', () {
      final table = font.offsetTable;

      expect(table.entrySelector, 3);
      expect(table.numTables, 11);
      expect(table.rangeShift, 48);
      expect(table.searchRange, 128);
      expect(table.sfntVersion, 0x10000);
      expect(table.isOpenType, false);
    });

    test('Maximum Profile table', () {
      final table = font.tableMap[kMaxpTag] as MaximumProfileTable;
      expect(table, isNotNull);

      expect(table.version, 0x00010000);
      expect(table.numGlyphs, 166);
      expect(table.maxPoints, 333);
      expect(table.maxContours, 22);
      expect(table.maxCompositePoints, 0);
      expect(table.maxCompositeContours, 0);
      expect(table.maxZones, 2);
      expect(table.maxTwilightPoints, 0);
      expect(table.maxStorage, 10);
      expect(table.maxFunctionDefs, 10);
      expect(table.maxInstructionDefs, 0);
      expect(table.maxStackElements, 255);
      expect(table.maxSizeOfInstructions, 0);
      expect(table.maxComponentElements, 0);
      expect(table.maxComponentDepth, 0);
    });

    test('Header table', () {
      final table = font.tableMap[kHeadTag] as HeaderTable;
      expect(table, isNotNull);

      expect(table.majorVersion, 1);
      expect(table.minorVersion, 0);
      expect(table.fontRevision.major, 1);
      expect(table.fontRevision.minor, 0);
      expect(table.checkSumAdjustment, 3043242535);
      expect(table.magicNumber, 1594834165);
      expect(table.flags, 11);
      expect(table.unitsPerEm, 1000);
      expect(table.created, DateTime.parse('2020-06-09T08:21:53.000Z'));
      expect(table.modified, DateTime.parse('2020-06-09T08:21:53.000Z'));
      expect(table.xMin, -11);
      expect(table.yMin, -153);
      expect(table.xMax, 1636);
      expect(table.yMax, 853);
      expect(table.macStyle, 0);
      expect(table.lowestRecPPEM, 8);
      expect(table.fontDirectionHint, 2);
      expect(table.indexToLocFormat, 0);
      expect(table.glyphDataFormat, 0);
    });

    test('Glyph Data table', () {
      final table = font.tableMap[kGlyfTag] as GlyphDataTable;
      expect(table, isNotNull);
      expect(table.glyphList.length, 166);

      final glyphCalendRainbow = table.glyphList[1];
      expect(glyphCalendRainbow.header.numberOfContours, 3);
      expect(glyphCalendRainbow.header.xMin, 0);
      expect(glyphCalendRainbow.header.yMin, 0);
      expect(glyphCalendRainbow.header.xMax, 1000);
      expect(glyphCalendRainbow.header.yMax, 623);
      expect(
        glyphCalendRainbow.flags
            .sublist(0, 7)
            .map((f) => f.onCurvePoint)
            .toList(),
        [true, false, true, false, true, false, false],
      );
      expect(glyphCalendRainbow.pointList.first.x, 936);
      expect(glyphCalendRainbow.pointList.last.x, 681);
      expect(glyphCalendRainbow.pointList.first.y, 110);
      expect(glyphCalendRainbow.pointList.last.y, 94);

      final glyphReport = table.glyphList[73];
      expect(glyphReport.header.numberOfContours, 4);
      expect(glyphReport.header.xMin, 0);
      expect(glyphReport.header.yMin, -150);
      expect(glyphReport.header.xMax, 1001);
      expect(glyphReport.header.yMax, 788);
      expect(
        glyphReport.flags.sublist(0, 7).map((f) => f.onCurvePoint).toList(),
        [true, false, false, true, true, false, false],
      );
      expect(glyphReport.pointList.first.x, 63);
      expect(glyphReport.pointList.last.x, 563);
      expect(glyphReport.pointList.first.y, 788);
      expect(glyphReport.pointList.last.y, 350);

      final glyphPdf = table.glyphList[165];
      expect(glyphPdf.header.numberOfContours, 5);
      expect(glyphPdf.header.xMin, 0);
      expect(glyphPdf.header.yMin, -88);
      expect(glyphPdf.header.xMax, 751);
      expect(glyphPdf.header.yMax, 788);
      expect(
        glyphPdf.flags.sublist(0, 7).map((f) => f.onCurvePoint).toList(),
        [true, false, false, true, true, false, false],
      );
      expect(glyphPdf.pointList.first.x, 63);
      expect(glyphPdf.pointList.last.x, 448);
      expect(glyphPdf.pointList.first.y, 788);
      expect(glyphPdf.pointList.last.y, 208);
    });

    test('OS/2 V1 table', () {
      final table = font.tableMap[kOS2Tag] as OS2Table;
      expect(table, isNotNull);

      expect(table.version, 1);
      expect(table.xAvgCharWidth, 862);
      expect(table.usWeightClass, 400);
      expect(table.usWidthClass, 5);
      expect(table.fsType, 0);
      expect(table.ySubscriptXSize, 634);
      expect(table.ySubscriptYSize, 700);
      expect(table.ySubscriptXOffset, 0);
      expect(table.ySubscriptYOffset, 140);
      expect(table.ySuperscriptXSize, 634);
      expect(table.ySuperscriptYSize, 700);
      expect(table.ySuperscriptXOffset, 0);
      expect(table.ySuperscriptYOffset, 480);
      expect(table.yStrikeoutSize, 49);
      expect(table.yStrikeoutPosition, 258);
      expect(table.sFamilyClass, 0);
      expect(table.panose, [2, 0, 5, 3, 0, 0, 0, 0, 0, 0]);
      expect(table.ulUnicodeRange1, 0);
      expect(table.ulUnicodeRange2, 0);
      expect(table.ulUnicodeRange3, 0);
      expect(table.ulUnicodeRange4, 0);
      expect(table.achVendID, 'PfEd');
      expect(table.fsSelection, 64);
      expect(table.usFirstCharIndex, 59414);
      expect(table.usLastCharIndex, 62368);
      expect(table.sTypoAscender, 850);
      expect(table.sTypoDescender, -150);
      expect(table.sTypoLineGap, 90);
      expect(table.usWinAscent, 853);
      expect(table.usWinDescent, 153);
      expect(table.ulCodePageRange1, 1);
      expect(table.ulCodePageRange2, 0);
    });

    test('PostScript table', () {
      final table = font.tableMap[kPostTag] as PostScriptTable;
      expect(table, isNotNull);

      expect(table.header.version, const Revision(2, 0));
      expect(table.header.italicAngle, 0);
      expect(table.header.underlinePosition, 10);
      expect(table.header.underlineThickness, 0);
      expect(table.header.isFixedPitch, 0);
      expect(table.header.minMemType42, 0);
      expect(table.header.maxMemType42, 0);
      expect(table.header.minMemType1, 0);
      expect(table.header.maxMemType1, 0);

      final format20 = table.data as PostScriptVersion20;
      expect(format20.numberOfGlyphs, 166);
      expect(format20.glyphNameIndex, kPOSTformat20indicies);
      expect(
        format20.glyphNames.map((ps) => ps.string).toList(),
        kPOSTformat20names,
      );
    });

    test('Naming table', () {
      final table = font.tableMap[kNameTag] as NamingTableFormat0;
      expect(table, isNotNull);

      expect(table.header.format, 0);
      expect(table.header.count, 18);
      expect(table.stringList.contains('Regular'), isTrue);
      expect(table.stringList.contains('TestFont'), isTrue);
      expect(table.stringList.contains('Version 1.0'), isTrue);
    });

    test('Character To Glyph Index Mapping table', () {
      final table = font.tableMap[kCmapTag] as CharacterToGlyphTable;
      expect(table, isNotNull);

      expect(table.header.version, 0);
      expect(table.header.numTables, 5);

      final format0table = table.data[2] as CmapByteEncodingTable;
      expect(format0table.format, 0);
      expect(format0table.language, 0);
      expect(format0table.length, 262);
      expect(format0table.glyphIdArray, List.generate(256, (_) => 0));

      final format4table =
          table.data[0] as CmapSegmentMappingToDeltaValuesTable;
      expect(format4table.format, 4);
      expect(format4table.length, 410);
      expect(format4table.language, 0);
      expect(format4table.entrySelector, 3);
      expect(format4table.searchRange, 16);
      expect(format4table.rangeShift, 0);
      expect(format4table.segCount, 8);
      expect(format4table.glyphIdArray, List.generate(165, (i) => i + 1));
      expect(format4table.idDelta, [0, 0, 0, 0, 0, 0, 0, 1]);
      expect(format4table.idRangeOffset, [16, 16, 16, 16, 16, 16, 320, 0]);
      expect(
        format4table.startCode,
        [59414, 59430, 59436, 59444, 59446, 62208, 62362, 65535],
      );
      expect(
        format4table.endCode,
        [59414, 59430, 59436, 59444, 59446, 62360, 62368, 65535],
      );

      final format12table = table.data[1] as CmapSegmentedCoverageTable;
      expect(format12table.format, 12);
      expect(format12table.language, 0);
      expect(format12table.numGroups, 165);
      expect(format12table.length, 1996);
      expect(
        format12table.groups.map((g) => g.startCharCode).toList(),
        kCMAPcharCodes,
      );
      expect(
        format12table.groups.map((g) => g.endCharCode).toList(),
        kCMAPcharCodes,
      );
      expect(
        format12table.groups.map((g) => g.startGlyphID).toList(),
        List.generate(165, (i) => i + 1),
      );
    });

    test('Horizontal Header table', () {
      final table = font.tableMap[kHheaTag] as HorizontalHeaderTable;
      expect(table, isNotNull);

      expect(table.majorVersion, 1);
      expect(table.minorVersion, 0);
      expect(table.ascender, 850);
      expect(table.descender, -150);
      expect(table.lineGap, 0);
      expect(table.advanceWidthMax, 1636);
      expect(table.minLeftSideBearing, -11);
      expect(table.minRightSideBearing, -7);
      expect(table.xMaxExtent, 1636);
      expect(table.caretSlopeRise, 1);
      expect(table.caretSlopeRun, 0);
      expect(table.caretOffset, 0);
      expect(table.metricDataFormat, 0);
      expect(table.numberOfHMetrics, 166);
    });

    test('Horizontal Metrics table', () {
      final table = font.tableMap[kHmtxTag] as HorizontalMetricsTable;
      expect(table, isNotNull);

      expect(table.leftSideBearings, isEmpty);
      expect(
        table.hMetrics.map((m) => m.advanceWidth).toList(),
        kHMTXadvWidth,
      );
      expect(table.hMetrics.map((m) => m.lsb).toList(), kHMTXlsb);
    });

    test('Glyph Substitution table', () {
      final table = font.tableMap[kGSUBTag] as GlyphSubstitutionTable;
      expect(table, isNotNull);

      final scriptTable = table.scriptListTable;

      expect(scriptTable.scriptCount, 2);

      expect(scriptTable.scriptRecords[0].scriptTag, 'DFLT');
      expect(scriptTable.scriptTables[0].langSysCount, 0);
      expect(scriptTable.scriptTables[0].defaultLangSys?.featureIndexCount, 1);
      expect(scriptTable.scriptTables[0].defaultLangSys?.featureIndices, [0]);
      expect(scriptTable.scriptTables[0].defaultLangSys?.lookupOrder, 0);
      expect(
        scriptTable.scriptTables[0].defaultLangSys?.requiredFeatureIndex,
        0,
      );

      expect(scriptTable.scriptRecords[1].scriptTag, 'latn');
      expect(scriptTable.scriptTables[1].langSysCount, 0);
      expect(scriptTable.scriptTables[1].defaultLangSys?.featureIndexCount, 1);
      expect(scriptTable.scriptTables[1].defaultLangSys?.featureIndices, [0]);
      expect(scriptTable.scriptTables[1].defaultLangSys?.lookupOrder, 0);
      expect(
        scriptTable.scriptTables[1].defaultLangSys?.requiredFeatureIndex,
        0,
      );

      final featureTable = table.featureListTable;
      expect(featureTable.featureCount, 1);
      expect(featureTable.featureRecords[0].featureTag, 'liga');
      expect(featureTable.featureTables[0].featureParams, 0);
      expect(featureTable.featureTables[0].lookupIndexCount, 1);
      expect(featureTable.featureTables[0].lookupListIndices, [0]);

      final lookupListTable = table.lookupListTable;
      expect(lookupListTable.lookupCount, 1);

      final lookupTable = lookupListTable.lookupTables.first;
      expect(lookupTable.lookupFlag, 0);
      expect(lookupTable.lookupType, 4);

      final lookupSubtable =
          lookupTable.subtables.first as LigatureSubstitutionSubtable;
      expect(lookupSubtable.ligatureSetCount, 0);
      expect(lookupSubtable.ligatureSetOffsets, isEmpty);
      expect(lookupSubtable.substFormat, 1);

      final coverageTable =
          lookupSubtable.coverageTable as CoverageTableFormat1;
      expect(coverageTable.coverageFormat, 1);
      expect(coverageTable.glyphCount, 0);
      expect(coverageTable.glyphArray, isEmpty);
    });
  });

  group('Creation & Writer', () {
    late ByteData originalByteData;
    late ByteData recreatedByteData;
    late OpenTypeFont recreatedFont;

    setUpAll(() {
      MockableDateTime.mockedDate = DateTime.utc(2020, 2, 2, 2, 2);
      originalByteData = ByteData.sublistView(
        File(_kTestFontAssetPath).readAsBytesSync(),
      );
      font = OTFReader.fromByteData(originalByteData).read();

      final glyphNameList = (font.post.data as PostScriptVersion20).glyphNames
          .map((s) => s.string)
          .toList();
      final glyphList = font.glyf.glyphList
          .map((e) => GenericGlyph.fromSimpleTrueTypeGlyph(e))
          .toList();

      for (var i = 0; i < glyphList.length; i++) {
        glyphList[i].metadata.name = glyphNameList[i];
      }

      recreatedFont = OpenTypeFont.createFromGlyphs(
        glyphList: glyphList,
        fontName: 'TestFont',
        useOpenType: false,
        usePostV2: true,
        normalize: true,
      );

      recreatedByteData = ByteData(recreatedFont.size);
      recreatedFont.encodeToBinary(recreatedByteData);
    });

    tearDownAll(() {
      MockableDateTime.mockedDate = null;
    });

    test(
      'Header table',
      () {
        const expected =
            'AAEAAAABAADXpqNjXw889QALBAAAAAAA2lveGAAAAADaW94Y//X/ZwZkBAAAAAAIAAIAAAAA';
        final actual = base64Encode(
          recreatedByteData.buffer.asUint8List(
            recreatedFont.head.entry!.offset,
            recreatedFont.head.entry!.length,
          ),
        );

        expect(actual, expected);
        expect(recreatedFont.head.entry!.checkSum, 439353492);
      },
      skip: "Font's checksum is always changing, unskip later",
    );

    test('Glyph Substitution table', () {
      const expected =
          'AAEAAAAKADAAPgACREZMVAAObGF0bgAaAAQAAAAA//8AAQAAAAQAAAAA//8AAQAAAAFsaWdhAAgAAAABAAAAAQAEAAQAAAABAAgAAQAGAAAAAQAA';
      final actual = base64Encode(
        recreatedByteData.buffer.asUint8List(
          recreatedFont.gsub.entry!.offset,
          recreatedFont.gsub.entry!.length,
        ),
      );

      expect(actual, expected);
      expect(recreatedFont.gsub.entry!.checkSum, 546121080);
    });

    test('OS/2 V5', () {
      final table = recreatedFont.os2;

      expect(table.version, 5);

      // Was 675 while normalization scaled glyphs to ascender + descender
      // (700 units) instead of the 1000-unit span between them.
      expect(table.xAvgCharWidth, 953);
    });
  });

  group('CFF', () {
    late ByteData byteData;

    setUpAll(() {
      byteData = ByteData.sublistView(
        File(_kTestCFF2fontAssetPath).readAsBytesSync(),
      );
      font = OTFReader.fromByteData(byteData).read();
    });

    test('CFF2 Read & Write', () {
      final table = font.cff2;

      final originalCFF2byteList = byteData.buffer
          .asUint8List(table.entry!.offset, table.size)
          .toList();
      final encodedCFF2byteData = ByteData(table.size);

      expect(table.size, table.entry!.length);

      table
        ..recalculateOffsets()
        ..encodeToBinary(encodedCFF2byteData);

      final encodedCFF2byteList = encodedCFF2byteData.buffer
          .asUint8List()
          .toList();
      expect(encodedCFF2byteList, originalCFF2byteList);
    });

    test('CFF2 CharString Read & Write', () {
      // final interpreter = CharStringInterpreter();

      // final commands = [
      //   CharStringCommand.rmoveto(0, 0),
      //   CharStringCommand.rlineto([100, 100]),
      //   CharStringCommand.rmoveto(-50, -50),
      //   CharStringCommand.rlineto([100, 100]),
      // ];

      // final encoded = interpreter.writeCommands(commands);
      // final decoded = interpreter.readCommands(encoded);

      // TODO: !!! do some tests
    });
  });

  group('Generic Glyph', () {
    setUpAll(() {
      font = readFromFile(_kTestFontAssetPath);
    });

    test('Conversion from TrueType and back', () {
      final genericList = font.glyf.glyphList
          .map((e) => GenericGlyph.fromSimpleTrueTypeGlyph(e))
          .toList();
      final simpleList = genericList
          .map((e) => e.toSimpleTrueTypeGlyph())
          .toList();

      for (var i = 0; i < genericList.length; i++) {
        expect(simpleList[i].pointList, font.glyf.glyphList[i].pointList);
      }
    });

    test('Decompact and compact back', () {
      final genericList = font.glyf.glyphList
          .map((e) => GenericGlyph.fromSimpleTrueTypeGlyph(e))
          .toList();

      for (final g in genericList) {
        for (final o in g.outlines) {
          o
            ..decompactImplicitPoints()
            ..compactImplicitPoints();
        }
      }

      final simpleList = genericList
          .map((e) => e.toSimpleTrueTypeGlyph())
          .toList();

      // Those were compacted more than they were originally. Expecting just new size.
      final changedForReason = {
        1: 87,
        34: 66,
        53: 121,
        70: 90,
        115: 60,
        138: 90,
      };

      for (var i = 0; i < genericList.length; i++) {
        final newLength = simpleList[i].pointList.length;
        final expectedLength =
            changedForReason[i] ?? font.glyf.glyphList[i].pointList.length;
        expect(newLength, expectedLength);
      }
    });

    // TODO: !!! quad->cubic outline test
    // TODO: !!! generic->charstring test
    // TODO: !!! generic->simpleglyph test
  });

  group('Utils', () {
    const testString =
        '[INFO] :谷���新道, ひば���ヶ丘２丁���,'
        ' ひばりヶ���, 東久留米市 (Higashikurume)';

    test('Printable ASCII string', () {
      const expectedString = 'INFO :, , ,  Higashikurume';
      expect(testString.getAsciiPrintable(), expectedString);
    });

    test('PostScript ASCII string', () {
      const expectedString = 'INFO:,,,Higashikurume';
      expect(testString.getPostScriptString(), expectedString);
    });
  });
}
