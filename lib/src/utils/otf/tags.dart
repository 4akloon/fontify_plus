import 'dart:typed_data';

const String kHeadTag = 'head';
const String kGSUBTag = 'GSUB';
const String kOS2Tag = 'OS/2';
const String kCmapTag = 'cmap';
const String kGlyfTag = 'glyf';
const String kHheaTag = 'hhea';
const String kHmtxTag = 'hmtx';
const String kLocaTag = 'loca';
const String kMaxpTag = 'maxp';
const String kNameTag = 'name';
const String kPostTag = 'post';
const String kCFFTag = 'CFF ';
const String kCFF2Tag = 'CFF2';

const kPlatformUnicode = 0;
const kPlatformMacintosh = 1;
const kPlatformWindows = 3;

String convertTagToString(Uint8List bytes) => String.fromCharCodes(bytes);

Uint8List convertStringToTag(String string) {
  assert(string.length == 4, "Tag's length must be equal 4");

  return Uint8List.fromList(string.codeUnits);
}
