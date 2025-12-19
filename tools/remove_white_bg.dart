// ignore_for_file: avoid_print
import 'dart:io';
import 'package:image/image.dart';

/// Simple utility: converts near-white pixels to transparent in a PNG.
/// Usage: dart run tools/remove_white_bg.dart

void main(List<String> args) {
  final inputPath = 'assets/icons/panna_signals_foreground.png';
  final outputPath = 'assets/icons/panna_signals_foreground_clean.png';

  final file = File(inputPath);
  if (!file.existsSync()) {
    print('Input file not found: $inputPath');
    exit(2);
  }

  final bytes = file.readAsBytesSync();
  final img = decodeImage(bytes);
  if (img == null) {
    print('Could not decode image: $inputPath');
    exit(3);
  }

  int changed = 0;
  for (var y = 0; y < img.height; y++) {
    for (var x = 0; x < img.width; x++) {
      final pixel = img.getPixel(x, y);
      final r = pixel.r;
      final g = pixel.g;
      final b = pixel.b;
      final a = pixel.a;

      // if pixel is very close to white and opaque, make it transparent
      if (a > 200 && r > 240 && g > 240 && b > 240) {
        img.setPixelRgba(x, y, 0, 0, 0, 0);
        changed++;
      }
    }
  }

  if (changed == 0) {
    print('No near-white pixels found (no changes).');
  } else {
    final outBytes = encodePng(img);
    File(outputPath).writeAsBytesSync(outBytes);
    print('Wrote cleaned image to $outputPath (changed pixels: $changed)');
  }
}
