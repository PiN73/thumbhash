import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:thumbhash/thumbhash.dart' as thumbhash;

class ThumbHash {
  final Uint8List _data;

  ThumbHash._(this._data);

  factory ThumbHash.fromBytes(TypedData bytes) {
    return ThumbHash._(bytes.buffer.asUint8List());
  }

  ImageProvider toImage() {
    final image = thumbhash.thumbHashToRGBA(_data);
    return MemoryImage(image.rgba);
  }

  Color toAverageColor() {
    final color = thumbhash.thumbHashToAverageRGBA(_data);
    return Color.fromARGB(
      color.a * 0xff ~/ 1,
      color.r * 0xff ~/ 1,
      color.g * 0xff ~/ 1,
      color.b * 0xff ~/ 1,
    );
  }

  double toApproximateAspectRatio() {
    return thumbhash.thumbHashToApproximateAspectRatio(_data);
  }
}
