import 'dart:typed_data';

import '../../../common/codable/binary.dart';
import '../../../utils/otf.dart';
import 'item_variation_data.dart';
import 'variation_region_list.dart';

/// The variation store: a region list plus the subtables that index into it.
class ItemVariationStore extends BinaryCodable {
  ItemVariationStore({
    required this.format,
    required this.variationRegionListOffset,
    required this.itemVariationDataCount,
    required this.itemVariationDataOffsets,
    required this.variationRegionList,
    required this.itemVariationDataList,
  });

  factory ItemVariationStore.fromByteData(ByteData byteData) {
    final variationRegionListOffset = byteData.getUint32(2);
    final itemVariationDataCount = byteData.getUint16(6);
    final itemVariationDataOffsets = List.generate(
      itemVariationDataCount,
      (i) => byteData.getUint32(8 + 4 * i),
    );

    return ItemVariationStore(
      format: byteData.getUint16(0),
      variationRegionListOffset: variationRegionListOffset,
      itemVariationDataCount: itemVariationDataCount,
      itemVariationDataOffsets: itemVariationDataOffsets,
      variationRegionList: VariationRegionList.fromByteData(
        byteData.sublistView(variationRegionListOffset),
      ),
      itemVariationDataList: [
        for (final offset in itemVariationDataOffsets)
          ItemVariationData.fromByteData(byteData.sublistView(offset)),
      ],
    );
  }

  final int format;
  int variationRegionListOffset;
  int itemVariationDataCount;
  List<int> itemVariationDataOffsets;

  final VariationRegionList variationRegionList;
  final List<ItemVariationData> itemVariationDataList;

  @override
  int get size =>
      8 +
      4 * itemVariationDataCount +
      variationRegionList.size +
      _itemVariationSubtableListSize;

  int get _itemVariationSubtableListSize =>
      itemVariationDataList.fold<int>(0, (p, i) => p + i.size);

  @override
  void encodeToBinary(ByteData byteData) {
    final variationRegionListSize = variationRegionList.size;
    itemVariationDataCount = itemVariationDataList.length;
    variationRegionListOffset = 8 + 4 * itemVariationDataCount;
    itemVariationDataOffsets = [];

    var offset = variationRegionListOffset + variationRegionListSize;

    for (var i = 0; i < itemVariationDataCount; i++) {
      final itemVariationData = itemVariationDataList[i];
      final itemSize = itemVariationData.size;
      itemVariationDataOffsets.add(offset);

      byteData.setUint32(8 + 4 * i, offset);
      itemVariationData.encodeToBinary(byteData.sublistView(offset, itemSize));

      offset += itemSize;
    }

    byteData
      ..setUint16(0, format)
      ..setUint32(2, variationRegionListOffset)
      ..setUint16(6, itemVariationDataCount);

    variationRegionList.encodeToBinary(
      byteData.sublistView(variationRegionListOffset, variationRegionListSize),
    );
  }
}
