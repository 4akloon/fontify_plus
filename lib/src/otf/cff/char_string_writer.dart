import 'dart:typed_data';

import '../../common/codable/binary.dart';
import 'char_string_command.dart';
import 'operand.dart';

/// Serializes charstring commands.
class CharStringWriter {
  const CharStringWriter({required this.isCFF1});

  /// Whether the target table is CFF1 rather than CFF2.
  ///
  /// The two formats share the command encoding; they differ in that a CFF1
  /// charstring carries the glyph's advance width as a leading operand.
  final bool isCFF1;

  ByteData writeCommands(
    List<CharStringCommand> commandList, {
    int? glyphWidth,
  }) {
    final bytes = <int>[];

    void encodeAndPush(BinaryEncodable encodable) {
      final byteData = ByteData(encodable.size);
      encodable.encodeToBinary(byteData);
      bytes.addAll(byteData.buffer.asUint8List());
    }

    if (isCFF1 && glyphWidth != null) {
      encodeAndPush(CFFOperand.fromValue(glyphWidth));
    }

    for (final command in commandList) {
      command.operandList.forEach(encodeAndPush);
      encodeAndPush(command.operator);
    }

    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}
