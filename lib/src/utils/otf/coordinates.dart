bool checkBitMask(int value, int mask) => (value & mask) == mask;

/// Tells if integer is 1 byte long
bool isShortInteger(int number) => number >= -0xFF && number <= 0xFF;

/// Converts relative coordinates to absolute ones
List<int> relToAbsCoordinates(List<int> relCoordinates) {
  if (relCoordinates.isEmpty) {
    return [];
  }

  final absCoordinates = List.filled(relCoordinates.length, 0);
  var currentValue = 0;

  for (var i = 0; i < relCoordinates.length; i++) {
    currentValue += relCoordinates[i];
    absCoordinates[i] = currentValue;
  }

  return absCoordinates;
}

/// Converts absolute coordinates to relative ones
List<int> absToRelCoordinates(List<int> absCoordinates) {
  if (absCoordinates.isEmpty) {
    return [];
  }

  final relCoordinates = List.filled(absCoordinates.length, 0);
  var prevValue = 0;

  for (var i = 0; i < absCoordinates.length; i++) {
    relCoordinates[i] = absCoordinates[i] - prevValue;
    prevValue = absCoordinates[i];
  }

  return relCoordinates;
}
