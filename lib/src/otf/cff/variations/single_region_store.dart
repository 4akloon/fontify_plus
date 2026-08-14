import 'item_variation_data.dart';
import 'item_variation_store.dart';
import 'region_axis_coordinates.dart';
import 'variation_region_list.dart';
import 'variation_store_data.dart';

/// The variation store a single-axis CFF2 font of two or three masters needs.
///
/// This is not a general-purpose variation store builder — it is specific to
/// this package's `wght`-as-stroke-width axis, which always has exactly one
/// axis, and it encodes only the two region layouts that axis's supported
/// default placements produce.
///
/// With `fvar` putting the default instance at the axis's *maximum* (see
/// `FontVariationsTable`), normalized design space runs from -1 at the
/// minimum stroke width to 0 at the default, and a single region covers all
/// of it: it peaks at -1, where its scalar is 1 and a charstring's delta
/// applies in full, and falls to 0 at the default, where the delta
/// contributes nothing.
///
/// With the default at an interior width, normalized space instead runs from
/// -1 at the minimum through 0 at the default to +1 at the maximum, and one
/// region cannot describe it: a region's scalar is zero outside its
/// start-to-end span, so one region peaking at -1 would leave everything
/// above the default unvaried. That shape takes two regions — one spanning
/// -1 to 0 and peaking at -1, one spanning 0 to +1 and peaking at +1 — and
/// therefore two deltas behind every blended value.
///
/// [regionCount] is how many non-default masters each glyph contributes and
/// picks between those two shapes. Any other count is rejected here rather
/// than in the CFF2 builder alone, because charstrings carrying some other
/// number of deltas per value would still encode fine and only go wrong at
/// read time, against a store advertising a count that disagrees with them.
class SingleRegionVariationStore {
  SingleRegionVariationStore({int regionCount = 1})
    : _regionCount = regionCount {
    if (regionCount != 1 && regionCount != 2) {
      throw ArgumentError(
        'SingleRegionVariationStore encodes one or two regions (two or three '
        'masters per glyph); got $regionCount regions from '
        '${regionCount + 1} masters per glyph',
      );
    }
  }

  final int _regionCount;

  /// F2Dot14 for -1.0, 0.0 and +1.0, the normalized coordinates this axis
  /// uses. The maximum only appears in the two-region shape, where the
  /// default no longer sits at the top of the range.
  static const _normalizedMinimum = 0xC000;
  static const _normalizedDefault = 0x0000;
  static const _normalizedMaximum = 0x4000;

  /// Builds the store.
  ///
  /// The offsets inside are recomputed by `encodeToBinary`, so the zero and the
  /// placeholder offset list passed for them here are not data. The item count
  /// is not one of those: `size` is what sizes the output buffer, is called
  /// before `encodeToBinary` gets a chance to correct anything, and (per
  /// `ItemVariationStore`'s own documented convention) trusts that field as-is
  /// — so it is passed as the real count, matching the one-element data list
  /// below, rather than as a zero encodeToBinary would fix up too late.
  VariationStoreData build() => VariationStoreData(
    0,
    ItemVariationStore(
      format: 1,
      variationRegionListOffset: 0,
      // Real, not a placeholder; see doc above.
      itemVariationDataCount: 1,
      itemVariationDataOffsets: <int>[0],
      variationRegionList: VariationRegionList(
        axisCount: 1,
        regionCount: _regionCount,
        regions: [
          const RegionAxisCoordinates(
            startCoord: _normalizedMinimum,
            peakCoord: _normalizedMinimum,
            endCoord: _normalizedDefault,
          ),
          if (_regionCount == 2)
            const RegionAxisCoordinates(
              startCoord: _normalizedDefault,
              peakCoord: _normalizedMaximum,
              endCoord: _normalizedMaximum,
            ),
        ],
      ),
      // No delta sets: a CFF2 charstring carries its own deltas inline, and
      // this subtable's only job is to tell `blend` at vsindex 0 how many
      // regions — and therefore how many deltas per value — to expect.
      itemVariationDataList: [
        ItemVariationData(
          itemCount: 0,
          shortDeltaCount: 0,
          regionIndexCount: _regionCount,
          regionIndexes: [for (var i = 0; i < _regionCount; i++) i],
        ),
      ],
    ),
  );
}
