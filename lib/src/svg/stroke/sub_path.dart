import 'package:path_parsing/path_parsing.dart';
import 'package:vector_math/vector_math.dart';

import '../geometry/cubic.dart';
import '../geometry/tolerances.dart';

/// One subpath, kept as curves rather than flattened.
///
/// Offsetting proceeds segment by segment either way, but keeping the curves
/// means their offsets can be approximated directly. Flattening first discards
/// the exact end tangents that make that approximation cheap, and no amount of
/// refitting afterwards recovers them.
class SubPath {
  SubPath(this.start);

  final Vector2 start;
  final segments = <Cubic>[];
  bool closed = false;

  Vector2 get end => segments.isEmpty ? start : segments.last.p3;

  /// The same subpath traced the other way, so offsetting to the left walks
  /// the other side of the stroke.
  List<Cubic> get reversedSegments =>
      [for (final segment in segments.reversed) segment.reversed];
}

/// Collects SVG path data as subpaths of cubic segments.
class SubPathBuilder extends PathProxy {
  final _subPaths = <SubPath>[];

  SubPath? _current;
  Vector2 _cursor = Vector2.zero();

  List<SubPath> build(String pathData) {
    writeSvgPathDataToPath(pathData, this);
    _finish();

    return _subPaths;
  }

  @override
  void moveTo(double x, double y) {
    _finish();
    _cursor = Vector2(x, y);
    _current = SubPath(_cursor.clone());
  }

  @override
  void lineTo(double x, double y) {
    final end = Vector2(x, y);
    final current = _currentOrStart();

    if (current.end.distanceToSquared(end) > kPointEpsilon) {
      current.segments.add(Cubic.line(current.end, end));
    }

    _cursor = end;
  }

  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) {
    final current = _currentOrStart();
    final end = Vector2(x3, y3);

    current.segments.add(
      Cubic(current.end, Vector2(x1, y1), Vector2(x2, y2), end),
    );

    _cursor = end;
  }

  @override
  void close() {
    final current = _current;

    if (current != null &&
        current.segments.isNotEmpty &&
        current.end.distanceToSquared(current.start) > kPointEpsilon) {
      current.segments.add(Cubic.line(current.end, current.start));
    }

    current?.closed = true;
    _finish();
  }

  SubPath _currentOrStart() => _current ??= SubPath(_cursor.clone());

  void _finish() {
    final current = _current;

    if (current != null && current.segments.isNotEmpty) {
      _subPaths.add(current);
    }

    _current = null;
  }
}
