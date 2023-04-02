import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:thumbhash/thumbhash.dart' as thumbhash;

/// Represents ThumbHash instance, contains byte data for image placeholder
class ThumbHash {
  final Uint8List _data;

  ThumbHash._(this._data);

  /// Constructs ThumbHash instance from byte data
  /// ```
  /// final bytes = Uint8List.fromList([0xDC, 0xE7, 0x11, 0x25, 0x80, 0x78, 0x77, 0x78, 0x7F, 0x88, 0x87, 0x87, 0x78, 0x48, 0x77, 0x78, 0x88, 0x70, 0xFA, 0x3D, 0xC0]);
  /// final hash = ThumbHash.fromBytes(bytes);
  /// ```
  factory ThumbHash.fromBytes(TypedData bytes) {
    return ThumbHash._(bytes.buffer.asUint8List());
  }

  /// Constructs ThumbHash instance from byte data stored in `List<int>`
  /// ```
  /// final list = [0xDC, 0xE7, 0x11, 0x25, 0x80, 0x78, 0x77, 0x78, 0x7F, 0x88, 0x87, 0x87, 0x78, 0x48, 0x77, 0x78, 0x88, 0x70, 0xFA, 0x3D, 0xC0];
  /// final hash = ThumbHash.fromIntList(list);
  /// ```
  factory ThumbHash.fromIntList(List<int> list) {
    return ThumbHash._(Uint8List.fromList(list));
  }

  /// Constructs ThumbHash instance from byte data stored in base64-decoded `String`
  /// ```
  /// final str = '3OcRJYB4d3h/iIeHeEh3eIhw+j3A';
  /// final hash = ThumbHash.fromBase64(str);
  /// ```
  factory ThumbHash.fromBase64(String encoded) {
    return ThumbHash._(base64.decode(base64.normalize(encoded)));
  }

  /// Creates [ImageProvider] to show placeholder from the ThumbHash instance
  /// ```
  /// Image(
  ///   image: hash.toImage(),
  /// )
  /// ```
  ImageProvider toImage() {
    final rgbaImage = thumbhash.thumbHashToRGBA(_data);
    final bmpImage = thumbhash.rgbaToBmp(rgbaImage);
    return MemoryImage(bmpImage);
  }

  /// Returns average color of the image represented by the ThumbHash instance
  Color toAverageColor() {
    final color = thumbhash.thumbHashToAverageRGBA(_data);
    return Color.fromARGB(
      color.a * 0xff ~/ 1,
      color.r * 0xff ~/ 1,
      color.g * 0xff ~/ 1,
      color.b * 0xff ~/ 1,
    );
  }

  /// Returns approximate aspect ratio of the image represented by the ThumbHash instance
  double toApproximateAspectRatio() {
    return thumbhash.thumbHashToApproximateAspectRatio(_data);
  }
}
