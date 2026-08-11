import 'dart:collection';

import '../utils/exception.dart';
import 'table/abstract.dart';

/// The tables of one font, looked up by tag with the type checked.
///
/// A bare `tableMap[kHeadTag] as HeaderTable` collapses three unrelated
/// situations into one `TypeError` that names neither the tag nor the type:
/// the tag is absent, the tag holds a different kind of table (real
/// corruption), or the caller asked for a table this font format does not
/// have at all — `glyf` on a CFF font, `cff` on a TrueType one. The third is
/// not a failure; it is a question with the answer "no". [lookup] answers it,
/// and [require] is for the callers that cannot proceed without the table and
/// want the failure to say which one is missing.
class FontTables {
  /// Wraps the given map, which stays live rather than being copied:
  /// `OTFReader` hands its map to `OpenTypeFont` before it has finished
  /// filling it, and then keeps adding tables to it.
  FontTables(this._byTag);

  final Map<String, FontTable> _byTag;

  /// Every table keyed by its tag, for callers that iterate or count them.
  ///
  /// Read-only: [FontTables] owns the map, and a table stored under a tag
  /// that disagrees with its type is exactly the corruption [lookup] and
  /// [require] exist to report.
  late final Map<String, FontTable> asMap = UnmodifiableMapView(_byTag);

  /// The table at [tag], or null when this font does not carry one.
  ///
  /// Returns null both for an absent tag and for a tag holding a different
  /// kind of table. The two are not distinguished here because no caller can
  /// act differently on them — [require] is for callers that cannot proceed
  /// without it, and it names the tag in the failure.
  T? lookup<T extends FontTable>(String tag) {
    final table = _byTag[tag];

    return table is T ? table : null;
  }

  /// The table at [tag], or a [TableDataFormatException] naming what was
  /// missing.
  ///
  /// Absence and a type mismatch produce different messages: the first is an
  /// incomplete font, the second is a font whose directory disagrees with its
  /// contents, and telling them apart is the whole reason this is not a cast.
  T require<T extends FontTable>(String tag) {
    final table = lookup<T>(tag);

    if (table == null) {
      throw TableDataFormatException(
        _byTag.containsKey(tag)
            ? 'Table "$tag" is not a $T'
            : 'Font has no "$tag" table',
      );
    }

    return table;
  }
}
