import '../../common/generic_glyph.dart';
import 'char_string_blend.dart';
import 'char_string_command.dart';
import 'char_string_optimizer.dart';
import 'variations/single_region_store.dart';
import 'variations/variation_store_data.dart';

/// Owns the region count that the optimizer, blender and variation store must
/// agree on.
///
/// That count used to reach those three as independent arguments, and each
/// one could silently disagree with the others: the charstrings would still
/// encode, and the store would still advertise one region, while the stack
/// limit and the deltas assumed a different count. Holding the count once
/// here is what keeps them from drifting apart.
class Cff2RegionContext {
  factory Cff2RegionContext(int regionCount) {
    // A glyph with zero masters (`length - 1 == -1`) would otherwise reach
    // CharStringInterpreterLimits and divide by zero.
    if (regionCount < 0) {
      throw ArgumentError('Every glyph must have at least one master');
    }

    return Cff2RegionContext._(regionCount);
  }

  Cff2RegionContext._(this.regionCount)
    : optimizer = CharStringOptimizer(false, regionCount: regionCount),
      // SingleRegionVariationStore rejects any count it has no region layout
      // for; zero is excluded here because a non-variable font has no store
      // at all, not an empty one.
      vstoreData = regionCount == 0
          ? null
          : SingleRegionVariationStore(regionCount: regionCount).build();

  /// How many non-default masters every glyph in the table contributes.
  final int regionCount;

  /// Optimizer sized for [regionCount]'s blend stack budget.
  final CharStringOptimizer optimizer;

  /// Null when there are no regions; otherwise the store whose region layout
  /// matches [regionCount].
  final VariationStoreData? vstoreData;

  /// Encodes [masters] jointly and merges them into one blended charstring.
  ///
  /// [masters] must have exactly [regionCount] + 1 entries — the same count
  /// this context handed the optimizer and the store.
  List<CharStringCommand> encodeAndBlend(List<GenericGlyph> masters) {
    if (masters.length - 1 != regionCount) {
      throw ArgumentError(
        'Every glyph must have the same number of masters: '
        '${regionCount + 1} vs ${masters.length}',
      );
    }

    return CharStringBlender(
      CharStringEncoder(masters, optimizer).encode(),
    ).merge();
  }
}
