import '../path.dart';

/// An element whose geometry can be expressed as a path.
///
/// Everything downstream of parsing works on paths, so each shape states its
/// own equivalent rather than the converter carrying a case per shape.
abstract class PathConvertible {
  PathElement getPath();
}
