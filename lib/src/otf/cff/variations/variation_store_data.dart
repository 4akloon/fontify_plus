import 'dart:typed_data';

import '../../../common/codable/binary.dart';
import '../../../utils/otf.dart';
import 'item_variation_store.dart';

/// A variation store preceded by its own length, as CFF2 stores it.
class VariationStoreData extends BinaryCodable {
  VariationStoreData(this.length, this.store);

  factory VariationStoreData.fromByteData(ByteData byteData) =>
      VariationStoreData(
        byteData.getUint16(0),
        ItemVariationStore.fromByteData(byteData.sublistView(2)),
      );

  int length;
  final ItemVariationStore store;

  @override
  int get size => 2 + store.size;

  @override
  void encodeToBinary(ByteData byteData) {
    final storeSize = store.size;
    length = storeSize;

    byteData.setUint16(0, length);
    store.encodeToBinary(byteData.sublistView(2, storeSize));
  }
}
