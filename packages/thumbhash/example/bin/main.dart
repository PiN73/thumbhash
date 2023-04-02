import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as image;
import 'package:thumbhash/thumbhash.dart' as thumbhash;

void main() {
  final root = Directory.current.path;

  final sourceImageFile = File('$root/assets/flower.jpg');
  final sourceImageBytes = sourceImageFile.readAsBytesSync();
  final sourceImageRaw = image.decodeImage(sourceImageBytes)!;
  final thumbhashBytes = thumbhash.rgbaToThumbHash(
    sourceImageRaw.width,
    sourceImageRaw.height,
    sourceImageRaw.data.buffer.asUint8List(),
  );
  final thumbhashBase64 = base64.encode(thumbhashBytes);
  print('ThumbHash from ${sourceImageFile.path}: $thumbhashBase64');

  final inputBase64 = thumbhashBase64;
  // or try '3OcRJYB4d3h/iIeHeEh3eIhw+j3A'

  final inputBase64Normalized = base64.normalize(inputBase64);
  final inputBytes = base64.decode(inputBase64Normalized);
  final color = thumbhash.thumbHashToAverageRGBA(inputBytes);
  print('Color from ThumbHash: ${color.r} ${color.g} ${color.b} ${color.a}');
  final ratio = thumbhash.thumbHashToApproximateAspectRatio(inputBytes);
  print('Ratio from ThumbHash: $ratio');
  final imageRaw = thumbhash.thumbHashToRGBA(inputBytes);
  final imageWrapped = image.Image.fromBytes(
    imageRaw.width,
    imageRaw.height,
    imageRaw.rgba,
  );
  final resultFile = File('$root/assets/out.bmp');
  final imageBmp = image.encodeNamedImage(imageWrapped, resultFile.path)!;
  resultFile.writeAsBytesSync(imageBmp);
  print('Rendered ThumbHash preview to ${resultFile.path}');
}
