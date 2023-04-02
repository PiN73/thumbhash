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
  double avg_r = 0, avg_g = 0, avg_b = 0, avg_a = 0;
  for (int i = 0, j = 0; i < w * h; i++, j += 4) {
    double alpha = (rgba[j + 3] & 255) / 255.0;
    avg_r += alpha / 255.0 * (rgba[j] & 255);
    avg_g += alpha / 255.0 * (rgba[j + 1] & 255);
    avg_b += alpha / 255.0 * (rgba[j + 2] & 255);
    avg_a += alpha;
  }
  if (avg_a > 0) {
    avg_r /= avg_a;
    avg_g /= avg_a;
    avg_b /= avg_a;
  }

  bool hasAlpha = avg_a < w * h;
  int l_limit = hasAlpha ? 5 : 7; // Use fewer luminance bits if there's alpha
  int lx = math.max(1, ((l_limit * w) / math.max(w, h)).round());
  int ly = math.max(1, ((l_limit * h) / math.max(w, h)).round());
  List<double> l = List<double>.filled(w * h, 0); // luminance
  List<double> p = List<double>.filled(w * h, 0); // yellow - blue
  List<double> q = List<double>.filled(w * h, 0); // red - green
  List<double> a = List<double>.filled(w * h, 0); // alpha

  // Convert the image from RGBA to LPQA (composite atop the average color)
  for (int i = 0, j = 0; i < w * h; i++, j += 4) {
    double alpha = (rgba[j + 3] & 255) / 255.0;
    double r = avg_r * (1.0 - alpha) + alpha / 255.0 * (rgba[j] & 255);
    double g = avg_g * (1.0 - alpha) + alpha / 255.0 * (rgba[j + 1] & 255);
    double b = avg_b * (1.0 - alpha) + alpha / 255.0 * (rgba[j + 2] & 255);
    l[i] = (r + g + b) / 3.0;
    p[i] = (r + g) / 2.0 - b;
    q[i] = r - g;
    a[i] = alpha;
  }

  // Encode using the DCT into DC (constant) and normalized AC (varying) terms
  Channel l_channel = Channel(math.max(3, lx), math.max(3, ly)).encode(w, h, l);
  Channel p_channel = Channel(3, 3).encode(w, h, p);
  Channel q_channel = Channel(3, 3).encode(w, h, q);
  Channel? a_channel = hasAlpha ? Channel(5, 5).encode(w, h, a) : null;

  // Write the constants
  bool isLandscape = w > h;
  int header24 = (63.0 * l_channel.dc).round() |
      ((31.5 + 31.5 * p_channel.dc).round() << 6) |
      ((31.5 + 31.5 * q_channel.dc).round() << 12) |
      ((31.0 * l_channel.scale).round() << 18) |
      (hasAlpha ? 1 << 23 : 0);
  int header16 = (isLandscape ? ly : lx) |
      ((63.0 * p_channel.scale).round() << 3) |
      ((63.0 * q_channel.scale).round() << 9) |
      (isLandscape ? 1 << 15 : 0);
  int ac_start = hasAlpha ? 6 : 5;
  int ac_count = l_channel.ac.length +
      p_channel.ac.length +
      q_channel.ac.length +
      (a_channel?.ac.length ?? 0);
  Uint8List hash = Uint8List(ac_start + (ac_count + 1) ~/ 2);
  hash[0] = header24;
  hash[1] = (header24 >> 8);
  hash[2] = (header24 >> 16);
  hash[3] = header16;
  hash[4] = (header16 >> 8);
  if (a_channel != null) {
    hash[5] = ((15.0 * a_channel.dc).round() |
        ((15.0 * a_channel.scale).round() << 4));
  }

  // Write the varying factors
  int ac_index = 0;
  ac_index = l_channel.writeTo(hash, ac_start, ac_index);
  ac_index = p_channel.writeTo(hash, ac_start, ac_index);
  ac_index = q_channel.writeTo(hash, ac_start, ac_index);
  a_channel?.writeTo(hash, ac_start, ac_index);
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
  double l_dc = (header24 & 63) / 63.0;
  double p_dc = ((header24 >> 6) & 63) / 31.5 - 1.0;
  double q_dc = ((header24 >> 12) & 63) / 31.5 - 1.0;
  double l_scale = ((header24 >> 18) & 31) / 31.0;
  bool hasAlpha = (header24 >> 23) != 0;
  double p_scale = ((header16 >> 3) & 63) / 63.0;
  double q_scale = ((header16 >> 9) & 63) / 63.0;
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
  double a_dc = hasAlpha ? (hash[5] & 15) / 15.0 : 1.0;
  double a_scale = ((hash[5] >> 4) & 15) / 15.0;

  // Read the varying factors (boost saturation by 1.25x to compensate for quantization)
  int ac_start = hasAlpha ? 6 : 5;
  int ac_index = 0;
  Channel l_channel = Channel(lx, ly);
  Channel p_channel = Channel(3, 3);
  Channel q_channel = Channel(3, 3);
  Channel? a_channel;
  ac_index = l_channel.decode(hash, ac_start, ac_index, l_scale);
  ac_index = p_channel.decode(hash, ac_start, ac_index, p_scale * 1.25);
  ac_index = q_channel.decode(hash, ac_start, ac_index, q_scale * 1.25);
  if (hasAlpha) {
    a_channel = Channel(5, 5);
    a_channel.decode(hash, ac_start, ac_index, a_scale);
  }
  List<double> l_ac = l_channel.ac;
  List<double> p_ac = p_channel.ac;
  List<double> q_ac = q_channel.ac;
  List<double>? a_ac = a_channel?.ac;

  // Decode using the DCT into RGB
  double ratio = thumbHashToApproximateAspectRatio(hash);
  int w = (ratio > 1.0 ? 32.0 : 32.0 * ratio).round();
  int h = (ratio > 1.0 ? 32.0 / ratio : 32.0).round();
  Uint8List rgba = Uint8List(w * h * 4);
  int cx_stop = math.max(lx, hasAlpha ? 5 : 3);
  int cy_stop = math.max(ly, hasAlpha ? 5 : 3);
  List<double> fx = List<double>.filled(cx_stop, 0);
  List<double> fy = List<double>.filled(cy_stop, 0);
  for (int y = 0, i = 0; y < h; y++) {
    for (int x = 0; x < w; x++, i += 4) {
      double l = l_dc, p = p_dc, q = q_dc, a = a_dc;

      // Precompute the coefficients
      for (int cx = 0; cx < cx_stop; cx++) {
        fx[cx] = math.cos(math.pi / w * (x + 0.5) * cx);
      }
      for (int cy = 0; cy < cy_stop; cy++) {
        fy[cy] = math.cos(math.pi / h * (y + 0.5) * cy);
      }

      // Decode L
      for (int cy = 0, j = 0; cy < ly; cy++) {
        double fy2 = fy[cy] * 2.0;
        for (int cx = cy > 0 ? 0 : 1; cx * ly < lx * (ly - cy); cx++, j++) {
          l += l_ac[j] * fx[cx] * fy2;
        }
      }

      // Decode P and Q
      for (int cy = 0, j = 0; cy < 3; cy++) {
        double fy2 = fy[cy] * 2.0;
        for (int cx = cy > 0 ? 0 : 1; cx < 3 - cy; cx++, j++) {
          double f = fx[cx] * fy2;
          p += p_ac[j] * f;
          q += q_ac[j] * f;
        }
      }

      // Decode A
      if (a_ac != null) {
        for (int cy = 0, j = 0; cy < 5; cy++) {
          double fy2 = fy[cy] * 2.0;
          for (int cx = cy > 0 ? 0 : 1; cx < 5 - cy; cx++, j++) {
            a += a_ac[j] * fx[cx] * fy2;
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
