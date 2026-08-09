import 'dart:typed_data';

/// Nibble that ends a real number.
const _kTerminator = 0xF;

/// What each nibble stands for in a real number's digit stream.
///
/// CFF writes real numbers as text, one nibble per character, rather than as
/// an IEEE float.
const _kNibbleStrings = [
  '0',
  '1',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  '.',
  'E',
  'E-',
  '',
  '-',
  '',
];

/// Reads the real number whose marker byte has already been consumed.
///
/// [offset] points just past the marker. Returns the value together with the
/// operand's total size, marker included.
(double value, int size) decodeRealNumber(ByteData byteData, int offset) {
  final digits = StringBuffer();
  var cursor = offset;

  // ignore: literal_only_boolean_expressions
  while (true) {
    final byte = byteData.getUint8(cursor++);

    final high = byte >> 4;
    if (high == _kTerminator) {
      break;
    }
    digits.write(_kNibbleStrings[high]);

    final low = byte & 0xF;
    if (low == _kTerminator) {
      break;
    }
    digits.write(_kNibbleStrings[low]);
  }

  return (double.parse(digits.toString()), cursor - offset + 1);
}

/// [value] in the textual form the nibble alphabet can spell.
String normalizedRealNumber(double value) => value
    .toString()
    // Removing integer part if it's 0
    .replaceFirst(RegExp('^0.'), '.')
    // Making exponent char uppercase
    .replaceFirst('e', 'E')
    // Removing plus
    .replaceFirst('+', '');

/// Bytes [value] occupies, its marker included.
int realNumberSize(double value) {
  // 'E-' occupies a single nibble despite being two characters.
  final text = normalizedRealNumber(value).replaceFirst('E-', 'E');

  return 1 + ((text.length + 1) / 2).ceil();
}

/// Writes [value] as a real number, marker included, from the start of
/// [byteData].
void encodeRealNumber(ByteData byteData, double value) {
  final text = normalizedRealNumber(value);

  byteData.setUint8(0, 30);

  var offset = 1;
  var firstHalf = true;
  late int previous;

  for (var i = 0; i < text.length; i++) {
    var char = text[i];

    if (char == 'E' && text[i + 1] == '-') {
      char += '-';
      i++;
    }

    final nibble = _kNibbleStrings.indexOf(char);

    if (firstHalf) {
      previous = nibble;
    } else {
      byteData.setUint8(offset++, (previous << 4) | nibble);
    }

    firstHalf = !firstHalf;
  }

  byteData.setUint8(
    offset,
    firstHalf ? 0xFF : (previous << 4) | _kTerminator,
  );
}
