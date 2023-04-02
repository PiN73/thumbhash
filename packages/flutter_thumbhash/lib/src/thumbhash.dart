import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:thumbhash/thumbhash.dart' as thumbhash;

class ThumbHash {
  final Uint8List _data;

  ThumbHash._(this._data);

  factory ThumbHash.fromBytes(TypedData bytes) {
    return ThumbHash._(bytes.buffer.asUint8List());
  }

  factory ThumbHash.fromIntList(List<int> list) {
    return ThumbHash._(Uint8List.fromList(list));
  }

  factory ThumbHash.fromBase64(String encoded) {
    return ThumbHash._(base64.decode(base64.normalize(encoded)));
  }

  ImageProvider toImage() {
    final rgbaImage = thumbhash.thumbHashToRGBA(_data);
    final bmpImage = thumbhash.rgbaToBmp(rgbaImage);
    return MemoryImage(bmpImage);
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
