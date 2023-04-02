import 'dart:math' as math;
import 'dart:typed_data';

import 'channel.dart';
import 'image.dart';
import 'rgba.dart';

/// Encodes an RGBA image to a ThumbHash. RGB should not be premultiplied by A.
///
/// [w] is the width of the input image. Must be ≤100px.
///
/// [h] is the height of the input image. Must be ≤100px.
///
/// [rgba] is the pixels in the input image, row-by-row. Must have w*h*4 elements.
///
/// Returns the ThumbHash as a byte array.
Uint8List rgbaToThumbHash(int w, int h, Uint8List rgba) {
  // Encoding an image larger than 100x100 is slow with no benefit
  if (w > 100 || h > 100) {
    throw ArgumentError("${w}x$h doesn't fit in 100x100");
  }

  // Determine the average color
  double avgR = 0, avgG = 0, avgB = 0, avgA = 0;
  for (int i = 0, j = 0; i < w * h; i++, j += 4) {
    double alpha = (rgba[j + 3] & 255) / 255.0;
    avgR += alpha / 255.0 * (rgba[j] & 255);
    avgG += alpha / 255.0 * (rgba[j + 1] & 255);
    avgB += alpha / 255.0 * (rgba[j + 2] & 255);
    avgA += alpha;
  }
  if (avgA > 0) {
    avgR /= avgA;
    avgG /= avgA;
    avgB /= avgA;
  }

  bool hasAlpha = avgA < w * h;
  int lLimit = hasAlpha ? 5 : 7; // Use fewer luminance bits if there's alpha
  int lx = math.max(1, ((lLimit * w) / math.max(w, h)).round());
  int ly = math.max(1, ((lLimit * h) / math.max(w, h)).round());
  List<double> l = List<double>.filled(w * h, 0); // luminance
  List<double> p = List<double>.filled(w * h, 0); // yellow - blue
  List<double> q = List<double>.filled(w * h, 0); // red - green
  List<double> a = List<double>.filled(w * h, 0); // alpha

  // Convert the image from RGBA to LPQA (composite atop the average color)
  for (int i = 0, j = 0; i < w * h; i++, j += 4) {
    double alpha = (rgba[j + 3] & 255) / 255.0;
    double r = avgR * (1.0 - alpha) + alpha / 255.0 * (rgba[j] & 255);
    double g = avgG * (1.0 - alpha) + alpha / 255.0 * (rgba[j + 1] & 255);
    double b = avgB * (1.0 - alpha) + alpha / 255.0 * (rgba[j + 2] & 255);
    l[i] = (r + g + b) / 3.0;
    p[i] = (r + g) / 2.0 - b;
    q[i] = r - g;
    a[i] = alpha;
  }

  // Encode using the DCT into DC (constant) and normalized AC (varying) terms
  Channel lChannel = Channel(math.max(3, lx), math.max(3, ly)).encode(w, h, l);
  Channel pChannel = Channel(3, 3).encode(w, h, p);
  Channel qChannel = Channel(3, 3).encode(w, h, q);
  Channel? aChannel = hasAlpha ? Channel(5, 5).encode(w, h, a) : null;

  // Write the constants
  bool isLandscape = w > h;
  int header24 = (63.0 * lChannel.dc).round() |
      ((31.5 + 31.5 * pChannel.dc).round() << 6) |
      ((31.5 + 31.5 * qChannel.dc).round() << 12) |
      ((31.0 * lChannel.scale).round() << 18) |
      (hasAlpha ? 1 << 23 : 0);
  int header16 = (isLandscape ? ly : lx) |
      ((63.0 * pChannel.scale).round() << 3) |
      ((63.0 * qChannel.scale).round() << 9) |
      (isLandscape ? 1 << 15 : 0);
  int acStart = hasAlpha ? 6 : 5;
  int acCount = lChannel.ac.length +
      pChannel.ac.length +
      qChannel.ac.length +
      (aChannel?.ac.length ?? 0);
  Uint8List hash = Uint8List(acStart + (acCount + 1) ~/ 2);
  hash[0] = header24;
  hash[1] = (header24 >> 8);
  hash[2] = (header24 >> 16);
  hash[3] = header16;
  hash[4] = (header16 >> 8);
  if (aChannel != null) {
    hash[5] = ((15.0 * aChannel.dc).round() |
        ((15.0 * aChannel.scale).round() << 4));
  }

  // Write the varying factors
  int acIndex = 0;
  acIndex = lChannel.writeTo(hash, acStart, acIndex);
  acIndex = pChannel.writeTo(hash, acStart, acIndex);
  acIndex = qChannel.writeTo(hash, acStart, acIndex);
  aChannel?.writeTo(hash, acStart, acIndex);
  return hash;
}

/// Decodes a ThumbHash to an RGBA image. RGB is not be premultiplied by A.
///
/// [hash] is the bytes of the ThumbHash.
///
/// Returns the width, height, and pixels of the rendered placeholder image.
Image thumbHashToRGBA(Uint8List hash) {
  // Read the constants
  int header24 =
      (hash[0] & 255) | ((hash[1] & 255) << 8) | ((hash[2] & 255) << 16);
  int header16 = (hash[3] & 255) | ((hash[4] & 255) << 8);
  double lDc = (header24 & 63) / 63.0;
  double pDc = ((header24 >> 6) & 63) / 31.5 - 1.0;
  double qDc = ((header24 >> 12) & 63) / 31.5 - 1.0;
  double lScale = ((header24 >> 18) & 31) / 31.0;
  bool hasAlpha = (header24 >> 23) != 0;
  double pScale = ((header16 >> 3) & 63) / 63.0;
  double qScale = ((header16 >> 9) & 63) / 63.0;
  bool isLandscape = (header16 >> 15) != 0;
  int lx = math.max(
      3,
      isLandscape
          ? hasAlpha
              ? 5
              : 7
          : header16 & 7);
  int ly = math.max(
      3,
      isLandscape
          ? header16 & 7
          : hasAlpha
              ? 5
              : 7);
  double aDc = hasAlpha ? (hash[5] & 15) / 15.0 : 1.0;
  double aScale = ((hash[5] >> 4) & 15) / 15.0;

  // Read the varying factors (boost saturation by 1.25x to compensate for quantization)
  int acStart = hasAlpha ? 6 : 5;
  int acIndex = 0;
  Channel lChannel = Channel(lx, ly);
  Channel pChannel = Channel(3, 3);
  Channel qChannel = Channel(3, 3);
  Channel? aChannel;
  acIndex = lChannel.decode(hash, acStart, acIndex, lScale);
  acIndex = pChannel.decode(hash, acStart, acIndex, pScale * 1.25);
  acIndex = qChannel.decode(hash, acStart, acIndex, qScale * 1.25);
  if (hasAlpha) {
    aChannel = Channel(5, 5);
    aChannel.decode(hash, acStart, acIndex, aScale);
  }
  List<double> lAc = lChannel.ac;
  List<double> pAc = pChannel.ac;
  List<double> qAc = qChannel.ac;
  List<double>? aAc = aChannel?.ac;

  // Decode using the DCT into RGB
  double ratio = thumbHashToApproximateAspectRatio(hash);
  int w = (ratio > 1.0 ? 32.0 : 32.0 * ratio).round();
  int h = (ratio > 1.0 ? 32.0 / ratio : 32.0).round();
  Uint8List rgba = Uint8List(w * h * 4);
  int cxStop = math.max(lx, hasAlpha ? 5 : 3);
  int cyStop = math.max(ly, hasAlpha ? 5 : 3);
  List<double> fx = List<double>.filled(cxStop, 0);
  List<double> fy = List<double>.filled(cyStop, 0);
  for (int y = 0, i = 0; y < h; y++) {
    for (int x = 0; x < w; x++, i += 4) {
      double l = lDc, p = pDc, q = qDc, a = aDc;

      // Precompute the coefficients
      for (int cx = 0; cx < cxStop; cx++) {
        fx[cx] = math.cos(math.pi / w * (x + 0.5) * cx);
      }
      for (int cy = 0; cy < cyStop; cy++) {
        fy[cy] = math.cos(math.pi / h * (y + 0.5) * cy);
      }

      // Decode L
      for (int cy = 0, j = 0; cy < ly; cy++) {
        double fy2 = fy[cy] * 2.0;
        for (int cx = cy > 0 ? 0 : 1; cx * ly < lx * (ly - cy); cx++, j++) {
          l += lAc[j] * fx[cx] * fy2;
        }
      }

      // Decode P and Q
      for (int cy = 0, j = 0; cy < 3; cy++) {
        double fy2 = fy[cy] * 2.0;
        for (int cx = cy > 0 ? 0 : 1; cx < 3 - cy; cx++, j++) {
          double f = fx[cx] * fy2;
          p += pAc[j] * f;
          q += qAc[j] * f;
        }
      }

      // Decode A
      if (aAc != null) {
        for (int cy = 0, j = 0; cy < 5; cy++) {
          double fy2 = fy[cy] * 2.0;
          for (int cx = cy > 0 ? 0 : 1; cx < 5 - cy; cx++, j++) {
            a += aAc[j] * fx[cx] * fy2;
          }
        }
      }

      // Convert to RGB
      double b = l - 2.0 / 3.0 * p;
      double r = (3.0 * l - b + q) / 2.0;
      double g = r - q;
      rgba[i] = math.max(0, 255.0 * math.min(1, r)).round();
      rgba[i + 1] = math.max(0, 255.0 * math.min(1, g)).round();
      rgba[i + 2] = math.max(0, 255.0 * math.min(1, b)).round();
      rgba[i + 3] = math.max(0, 255.0 * math.min(1, a)).round();
    }
  }
  return Image(w, h, rgba);
}

/// Extracts the average color from a ThumbHash. RGB is not be premultiplied by A.
///
/// [hash] is the bytes of the ThumbHash.
///
/// Returns The RGBA values for the average color. Each value ranges from 0 to 1.
RGBA thumbHashToAverageRGBA(Uint8List hash) {
  int header =
      (hash[0] & 255) | ((hash[1] & 255) << 8) | ((hash[2] & 255) << 16);
  double l = (header & 63) / 63.0;
  double p = ((header >> 6) & 63) / 31.5 - 1.0;
  double q = ((header >> 12) & 63) / 31.5 - 1.0;
  bool hasAlpha = (header >> 23) != 0;
  double a = hasAlpha ? (hash[5] & 15) / 15.0 : 1.0;
  double b = l - 2.0 / 3.0 * p;
  double r = (3.0 * l - b + q) / 2.0;
  double g = r - q;
  return RGBA(math.max(0, math.min(1, r)), math.max(0, math.min(1, g)),
      math.max(0, math.min(1, b)), a);
}

/// Extracts the approximate aspect ratio of the original image.
///
/// [hash] is the bytes of the ThumbHash.
///
/// Returns the approximate aspect ratio (i.e. width / height).
double thumbHashToApproximateAspectRatio(Uint8List hash) {
  int header = hash[3];
  bool hasAlpha = (hash[2] & 0x80) != 0;
  bool isLandscape = (hash[4] & 0x80) != 0;
  int lx = isLandscape
      ? hasAlpha
          ? 5
          : 7
      : header & 7;
  int ly = isLandscape
      ? header & 7
      : hasAlpha
          ? 5
          : 7;
  return lx / ly;
}
