// ignore_for_file: avoid_print
import 'dart:io';
import 'package:image/image.dart';

void analyze(String path) {
  final f = File(path);
  if (!f.existsSync()) {
    print('Not found: $path');
    return;
  }
  final img = decodeImage(f.readAsBytesSync());
  if (img == null) {
    print('Cannot decode: $path');
    return;
  }

  int w = img.width, h = img.height;
  int total = w * h;
  int transparent = 0;
  int opaque = 0;
  int nearWhite = 0;

  int minX = w, minY = h, maxX = 0, maxY = 0;

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = img.getPixel(x, y);
      final a = p.a;
      final r = p.r;
      final g = p.g;
      final b = p.b;

      if (a < 10) {
        transparent++;
      } else {
        opaque++;
        minX = x < minX ? x : minX;
        minY = y < minY ? y : minY;
        maxX = x > maxX ? x : maxX;
        maxY = y > maxY ? y : maxY;
        if (r > 240 && g > 240 && b > 240) nearWhite++;
      }
    }
  }

  print('Image: $path');
  print('  size: ${w}x$h, total px: $total');
  print('  transparent px: $transparent (${(transparent/total*100).toStringAsFixed(2)}%)');
  print('  opaque px: $opaque (${(opaque/total*100).toStringAsFixed(2)}%)');
  print('  near-white opaque px: $nearWhite');
  if (opaque > 0) print('  bbox non-transparent: [$minX,$minY] - [$maxX,$maxY]');
}

void main() {
  final files = [
    'assets/icons/panna_signals_foreground.png',
    'assets/icons/panna_signals_foreground_clean.png',
    'android/app/src/main/res/drawable-mdpi/ic_launcher_foreground.png',
    'android/app/src/main/res/drawable-xxhdpi/ic_launcher_foreground.png',
    'android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png',
    'android/app/src/main/res/drawable-xhdpi/splash.png',
    'android/app/src/main/res/drawable-xxhdpi/splash.png',
    'android/app/src/main/res/drawable/background.png',
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png',
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png',
  ];

  for (final f in files) {
    analyze(f);
  }
}
