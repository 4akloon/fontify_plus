import 'dart:typed_data';

import '../../../utils/otf.dart';
import '../../../utils/pascal_string.dart';
import '../../defaults.dart';
import 'mac_standard_glyph_names.dart';
import 'post_script_data.dart';

/// Version 2.0: a name per glyph.
///
/// Names already in the Macintosh standard list are referenced by index; the
/// rest follow as Pascal strings, in glyph order.
class PostScriptVersion20 extends PostScriptData {
  const PostScriptVersion20(
    this.numberOfGlyphs,
    this.glyphNameIndex,
    this.glyphNames,
  );

  factory PostScriptVersion20.fromByteData(ByteData byteData, int offset) {
    final numberOfGlyphs = byteData.getUint16(offset);
    offset += 2;

    final glyphNameIndex = List.generate(
      numberOfGlyphs,
      (i) => byteData.getUint16(offset + i * 2),
    );
    offset += numberOfGlyphs * 2;

    final glyphNames = <PascalString>[];

    for (final glyphIndex in glyphNameIndex) {
      if (isGlyphNameStandard(glyphIndex)) {
        continue;
      }

      final string = PascalString.fromByteData(byteData, offset);
      offset += string.size;

      glyphNames.add(string);
    }

    return PostScriptVersion20(numberOfGlyphs, glyphNameIndex, glyphNames);
  }

  factory PostScriptVersion20.create(List<String> glyphNameList) {
    final glyphNameIndex = [
      ...kDefaultGlyphIndex,
      for (var i = 0; i < glyphNameList.length; i++)
        kMacStandardGlyphNames.length + i,
    ];

    return PostScriptVersion20(
      glyphNameIndex.length,
      glyphNameIndex,
      [for (final name in glyphNameList) PascalString.fromString(name)],
    );
  }

  final int numberOfGlyphs;
  final List<int> glyphNameIndex;
  final List<PascalString> glyphNames;

  @override
  Revision get version => const Revision.fromInt32(kPostVersion20);

  @override
  int get size {
    var glyphNamesSize = 0;
    var currentNameIndex = 0;

    for (var i = 0; i < numberOfGlyphs; i++) {
      if (isGlyphNameStandard(glyphNameIndex[i])) {
        continue;
      }

      glyphNamesSize += glyphNames[currentNameIndex++].size;
    }

    return 2 + numberOfGlyphs * 2 + glyphNamesSize;
  }

  @override
  void encodeToBinary(ByteData byteData) {
    byteData.setUint16(0, numberOfGlyphs);

    var offset = 2;

    for (final glyphIndex in glyphNameIndex) {
      byteData.setUint16(offset, glyphIndex);
      offset += 2;
    }

    var currentNameIndex = 0;

    for (var i = 0; i < numberOfGlyphs; i++) {
      if (isGlyphNameStandard(glyphNameIndex[i])) {
        continue;
      }

      final glyphName = glyphNames[currentNameIndex++];
      glyphName.encodeToBinary(byteData.sublistView(offset, glyphName.size));
      offset += glyphName.size;
    }
  }
}
