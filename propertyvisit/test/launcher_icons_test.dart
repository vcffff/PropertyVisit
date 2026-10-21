import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

({int width, int height, int colorType}) pngHeader(String path) {
  final bytes = File(path).readAsBytesSync();
  expect(bytes.take(8), [
    137,
    80,
    78,
    71,
    13,
    10,
    26,
    10,
  ], reason: '$path must be a PNG');
  final header = ByteData.sublistView(bytes);
  return (
    width: header.getUint32(16),
    height: header.getUint32(20),
    colorType: bytes[25],
  );
}

void main() {
  test(
    'provided launcher sources are square 1024px PNGs with an alpha-capable foreground',
    () {
      for (final name in ['app_icon.png', 'app_icon_foreground.png']) {
        final header = pngHeader('assets/launcher_icons/$name');
        expect(header.width, 1024);
        expect(header.height, 1024);
      }
      expect(
        pngHeader('assets/launcher_icons/app_icon_foreground.png').colorType,
        anyOf(4, 6),
      );
    },
  );

  test('Android legacy densities and padded adaptive resources exist', () {
    for (final entry in {
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    }.entries) {
      final legacy = pngHeader(
        'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
      );
      expect(legacy.width, entry.value);
      expect(legacy.height, entry.value);
      final foreground = pngHeader(
        'android/app/src/main/res/drawable-${entry.key}/ic_launcher_foreground.png',
      );
      expect(foreground.width, foreground.height);
      expect(foreground.colorType, anyOf(4, 6));
    }
    final xml = File(
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
    ).readAsStringSync();
    expect(xml, contains('android:inset="4%"'));
    expect(xml, contains('@drawable/ic_launcher_foreground'));
    expect(xml, contains('@color/ic_launcher_background'));
  });

  test(
    'every iOS AppIcon entry has an opaque PNG at the declared pixel dimensions',
    () {
      const directory = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
      final contents =
          jsonDecode(File('$directory/Contents.json').readAsStringSync())
              as Map<String, dynamic>;
      for (final entry in contents['images'] as List<dynamic>) {
        final data = entry as Map<String, dynamic>;
        final size = (data['size'] as String)
            .split('x')
            .map(double.parse)
            .toList();
        final scale = double.parse(
          (data['scale'] as String).replaceAll('x', ''),
        );
        final header = pngHeader('$directory/${data['filename']}');
        expect(header.width, (size[0] * scale).round());
        expect(header.height, (size[1] * scale).round());
        expect(
          header.colorType,
          isNot(anyOf(4, 6)),
          reason: 'iOS launcher images must have no alpha channel',
        );
      }
    },
  );
}
