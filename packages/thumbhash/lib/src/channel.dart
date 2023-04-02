import 'dart:math' as math;
import 'dart:typed_data';

class Channel {
  final int nx;
  final int ny;
  late double dc;
  late List<double> ac;
  late double scale = 0;

  Channel(this.nx, this.ny) {
    int n = 0;
    for (int cy = 0; cy < ny; cy++) {
      for (int cx = cy > 0 ? 0 : 1; cx * ny < nx * (ny - cy); cx++) {
        n++;
      }
    }
    ac = List<double>.filled(n, 0);
  }

  Channel encode(int w, int h, List<double> channel) {
    int n = 0;
    List<double> fx = List<double>.filled(w, 0);
    for (int cy = 0; cy < ny; cy++) {
      for (int cx = 0; cx * ny < nx * (ny - cy); cx++) {
        double f = 0;
        for (int x = 0; x < w; x++) {
          fx[x] = math.cos(math.pi / w * cx * (x + 0.5));
        }
        for (int y = 0; y < h; y++) {
          double fy = math.cos(math.pi / h * cy * (y + 0.5));
          for (int x = 0; x < w; x++) {
            f += channel[x + y * w] * fx[x] * fy;
          }
        }
        f /= w * h;
        if (cx > 0 || cy > 0) {
          ac[n++] = f;
          scale = math.max(scale, f.abs());
        } else {
          dc = f;
        }
      }
    }
    if (scale > 0) {
      for (int i = 0; i < ac.length; i++) {
        ac[i] = 0.5 + 0.5 / scale * ac[i];
      }
    }
    return this;
  }

  int decode(Uint8List hash, int start, int index, double scale) {
    for (int i = 0; i < ac.length; i++) {
      int data = hash[start + (index >> 1)] >> ((index & 1) << 2);
      ac[i] = ((data & 15) / 7.5 - 1.0) * scale;
      index++;
    }
    return index;
  }

  int writeTo(Uint8List hash, int start, int index) {
    for (double v in ac) {
      hash[start + (index >> 1)] |= (15.0 * v).round() << ((index & 1) << 2);
      index++;
    }
    return index;
  }
}
