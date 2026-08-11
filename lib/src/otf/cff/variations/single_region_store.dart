import 'item_variation_data.dart';
import 'item_variation_store.dart';
import 'region_axis_coordinates.dart';
import 'variation_region_list.dart';
import 'variation_store_data.dart';

/// The variation store a single-axis, two-master CFF2 font needs.
///
/// This is not a general-purpose variation store builder — it is specific to
/// this package's `wght`-as-stroke-width axis, which always has exactly one
/// axis and exactly one region, and to `fvar` putting the default instance at
/// that axis's *maximum* (see `FontVariationsTable`), so normalized design
/// space runs from -1 at the minimum stroke width to 0 at the default. One
/// region covers all of it: it peaks at -1, where its scalar is 1 and a
/// charstring's delta applies in full, and falls to 0 at the default, where
/// the delta contributes nothing. A default in the middle of the range would
/// need a region on each side, and so twice the deltas — a case this class
/// deliberately does not handle.
///
/// Constructing with [regionCount] other than 1 rejects the request: that
/// limit used to live only in the CFF2 builder, where a third master would
/// otherwise encode fine and decode into a store advertising one region while
/// carrying two deltas per value.
class SingleRegionVariationStore {
  SingleRegionVariationStore({int regionCount = 1}) {
    if (regionCount != 1) {
      throw ArgumentError(
        'SingleRegionVariationStore only encodes a single region (two '
        'masters per glyph); got $regionCount regions from '
        '${regionCount + 1} masters per glyph',
      );
    }
  }

  /// F2Dot14 for -1.0 and 0.0, the two normalized coordinates this axis uses.
  static const _normalizedMinimum = 0xC000;
  static const _normalizedDefault = 0x0000;

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
      variationRegionList: const VariationRegionList(
        axisCount: 1,
        regionCount: 1,
        regions: [
          RegionAxisCoordinates(
            startCoord: _normalizedMinimum,
            peakCoord: _normalizedMinimum,
            endCoord: _normalizedDefault,
          ),
        ],
      ),
      // No delta sets: a CFF2 charstring carries its own deltas inline, and
      // this subtable's only job is to tell `blend` at vsindex 0 how many
      // regions — and therefore how many deltas per value — to expect.
      itemVariationDataList: [
        const ItemVariationData(
          itemCount: 0,
          shortDeltaCount: 0,
          regionIndexCount: 1,
          regionIndexes: [0],
        ),
      ],
    ),
  );
}
