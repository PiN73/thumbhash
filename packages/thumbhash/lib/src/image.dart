import 'dart:typed_data';

class Image {
  final int width;
  final int height;
  final Uint8List rgba;

  Image(this.width, this.height, this.rgba);
}
