import 'item_variation_data.dart';
import 'item_variation_store.dart';
import 'region_axis_coordinates.dart';
import 'variation_region_list.dart';
import 'variation_store_data.dart';

/// F2Dot14 for -1.0 and 0.0, the two normalized coordinates this axis uses.
const _kNormalizedMinimum = 0xC000;
const _kNormalizedDefault = 0x0000;

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
/// need a region on each side, and so twice the deltas — a case this function
/// deliberately does not handle.
///
/// The offsets inside are recomputed by `encodeToBinary`, so the zero and the
/// placeholder offset list passed for them here are not data. The item count
/// is not one of those: `size` is what sizes the output buffer, is called
/// before `encodeToBinary` gets a chance to correct anything, and (per
/// `ItemVariationStore`'s own documented convention) trusts that field as-is
/// — so it is passed as the real count, matching the one-element data list
/// below, rather than as a zero encodeToBinary would fix up too late.
VariationStoreData singleRegionVariationStore() => VariationStoreData(
  0,
  ItemVariationStore(
    1, // format
    0,
    1, // itemVariationDataCount — real, not a placeholder; see doc above
    <int>[0],
    VariationRegionList(1, 1, [
      RegionAxisCoordinates(
        _kNormalizedMinimum,
        _kNormalizedMinimum,
        _kNormalizedDefault,
      ),
    ]),
    // No delta sets: a CFF2 charstring carries its own deltas inline, and
    // this subtable's only job is to tell `blend` at vsindex 0 how many
    // regions — and therefore how many deltas per value — to expect.
    [
      ItemVariationData(0, 0, 1, const [0]),
    ],
  ),
);
