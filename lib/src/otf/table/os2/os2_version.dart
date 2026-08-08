const kOS2Version0 = 0x0000;
const kOS2Version1 = 0x0001;
const kOS2Version4 = 0x0004;
const kOS2Version5 = 0x0005;

/// Byte size for fields added with specific version
const kOS2VersionDataSize = {
  kOS2Version0: 78,
  kOS2Version1: 8,
  kOS2Version4: 10,
  kOS2Version5: 4,
};
