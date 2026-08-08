import '../misc.dart';

/// A major/minor version pair, stored as a 32-bit fixed-point value.
final class Revision {
  const Revision(int? major, int? minor)
    : major = major ?? 0,
      minor = minor ?? 0;

  const Revision.fromInt32(int revision)
    : major = (revision >> 16) & 0xFFFF,
      minor = revision & 0xFFFF;

  final int major;
  final int minor;

  int get int32value => major * 0x10000 + minor;

  @override
  int get hashCode => combineHashCode(major.hashCode, minor.hashCode);

  @override
  bool operator ==(Object other) =>
      other is Revision && major == other.major && minor == other.minor;
}
