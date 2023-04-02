import 'dart:typed_data';

import 'byte_writer.dart';
import 'image.dart';

// https://github.com/brendan-duncan/image/blob/bf49f625e8a626ed08ccdae5bf736619b9121b3e/lib/src/formats/bmp_encoder.dart
Uint8List rgbaToBmp(Image image) {
  final alpha = true;
  final bytesPerPixel = alpha ? 4 : 3;
  final bpp = bytesPerPixel * 8;
  final rgbSize = image.width * image.height * bytesPerPixel;
  const headerSize = 54;
  const headerInfoSize = 40;
  final fileSize = rgbSize + headerSize;

  final out = ByteWriter(ByteData(fileSize), Endian.little);

  out.writeUint16(_BMP_HEADER_FILETYPE);
  out.writeUint32(fileSize);
  out.writeUint32(0); // reserved

  out.writeUint32(headerSize);
  out.writeUint32(headerInfoSize);
  out.writeUint32(image.width);
  out.writeUint32(-image.height);
  out.writeUint16(1); // planes
  out.writeUint16(bpp);
  out.writeUint32(0); // compress
  out.writeUint32(rgbSize);
  out.writeUint32(0); // hr
  out.writeUint32(0); // vr
  out.writeUint32(0); // colors
  out.writeUint32(0); // importantColors

  for (int i = 0; i < image.rgba.length ~/ bytesPerPixel; i += 1) {
    out.writeUint8(image.rgba[i * bytesPerPixel + 2]); // blue
    out.writeUint8(image.rgba[i * bytesPerPixel + 1]); // green
    out.writeUint8(image.rgba[i * bytesPerPixel + 0]); // red
    if (alpha) out.writeUint8(image.rgba[i * bytesPerPixel + 3]); // alpha
  }

  return out.data.buffer.asUint8List();
}

const _BMP_HEADER_FILETYPE = (0x42) + (0x4D << 8); // BM
