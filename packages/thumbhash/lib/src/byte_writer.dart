import 'dart:typed_data';

class ByteWriter {
  final ByteData data;
  final Endian endian;

  ByteWriter(this.data, this.endian);

  int i = 0;

  late final void Function(int) writeByte = writeUint8;

  void writeUint8(int value) {
    data.setUint8(i, value);
    i += 1;
  }

  void writeUint16(int value) {
    data.setUint16(i, value, endian);
    i += 2;
  }

  void writeUint32(int value) {
    data.setUint32(i, value, endian);
    i += 4;
  }
}
