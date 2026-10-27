// Gera os ícones do app para Android, iOS e web a partir de um único desenho.
// Executar na raiz do projeto: flutter test tool/generate_icons_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _light = Color(0xFF3E8A5F), _dark = Color(0xFF1F5238);
const _glyph = Icons.spa;

enum _Shape {
  /// Quadrado arredondado com cantos transparentes (Android antigo, web).
  rounded,

  /// Quadrado cheio, sem transparência (iOS recorta os cantos).
  full,

  /// Quadrado cheio com o desenho dentro da zona segura (PWA maskable).
  maskable,

  /// Só o desenho, sem fundo (camada da frente do ícone adaptativo Android).
  foreground,
}

Future<ui.Image> _draw(int size, _Shape shape) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final s = size.toDouble();
  final rect = Rect.fromLTWH(0, 0, s, s);
  final paint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_light, _dark],
    ).createShader(rect);
  switch (shape) {
    case _Shape.rounded:
      final inset = s * .04;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(inset), Radius.circular(s * .22)),
        paint,
      );
    case _Shape.full || _Shape.maskable:
      canvas.drawRect(rect, paint);
    case _Shape.foreground:
      break;
  }
  final glyphSize =
      s *
      switch (shape) {
        _Shape.rounded => size <= 32 ? .74 : .56,
        _Shape.full => .58,
        _Shape.maskable => .44,
        _Shape.foreground => .42,
      };
  final text = TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(
      text: String.fromCharCode(_glyph.codePoint),
      style: TextStyle(
        fontFamily: _glyph.fontFamily,
        fontSize: glyphSize,
        height: 1,
        color: Colors.white,
      ),
    ),
  )..layout();
  text.paint(
    canvas,
    Offset((s - text.width) / 2, (s - text.height) / 2 - s * .01),
  );
  return recorder.endRecording().toImage(size, size);
}

/// PNG mínimo. Ícones opacos saem em RGB, sem canal alfa (exigência da App
/// Store para o ícone de 1024 px).
Uint8List _png(Uint8List rgba, int size, {required bool alpha}) {
  final channels = alpha ? 4 : 3;
  final raw = BytesBuilder();
  for (var y = 0; y < size; y++) {
    raw.addByte(0);
    for (var x = 0; x < size; x++) {
      final i = (y * size + x) * 4;
      raw.add(rgba.sublist(i, i + channels));
    }
  }
  final out = BytesBuilder()
    ..add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  void chunk(String type, List<int> data) {
    final body = [...ascii.encode(type), ...data];
    out
      ..add(_u32(data.length))
      ..add(body)
      ..add(_u32(_crc(body)));
  }

  chunk('IHDR', [..._u32(size), ..._u32(size), 8, alpha ? 6 : 2, 0, 0, 0]);
  chunk('IDAT', ZLibEncoder(level: 9).convert(raw.takeBytes()));
  chunk('IEND', []);
  return out.takeBytes();
}

List<int> _u32(int v) => [v >> 24 & 255, v >> 16 & 255, v >> 8 & 255, v & 255];

int _crc(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c ^= b;
    for (var k = 0; k < 8; k++) {
      c = c & 1 != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
  }
  return c ^ 0xFFFFFFFF;
}

void main() {
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  testWidgets('gera ícones', (tester) async {
    final targets = <String, (int, _Shape)>{
      'web/favicon.png': (32, _Shape.rounded),
      'web/icons/Icon-192.png': (192, _Shape.rounded),
      'web/icons/Icon-512.png': (512, _Shape.rounded),
      'web/icons/Icon-maskable-192.png': (192, _Shape.maskable),
      'web/icons/Icon-maskable-512.png': (512, _Shape.maskable),
    };
    const densities = {
      'mdpi': 1.0,
      'hdpi': 1.5,
      'xhdpi': 2.0,
      'xxhdpi': 3.0,
      'xxxhdpi': 4.0,
    };
    const res = 'android/app/src/main/res';
    densities.forEach((name, scale) {
      targets['$res/mipmap-$name/ic_launcher.png'] = (
        (48 * scale).round(),
        _Shape.rounded,
      );
      targets['$res/mipmap-$name/ic_launcher_foreground.png'] = (
        (108 * scale).round(),
        _Shape.foreground,
      );
    });
    const ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    final contents = jsonDecode(File('$ios/Contents.json').readAsStringSync());
    for (final image in contents['images'] as List) {
      final points = double.parse((image['size'] as String).split('x').first);
      final scale = int.parse((image['scale'] as String).replaceAll('x', ''));
      targets['$ios/${image['filename']}'] = (
        (points * scale).round(),
        _Shape.full,
      );
    }

    await tester.runAsync(() async {
      for (final MapEntry(key: path, value: (size, shape)) in targets.entries) {
        final image = await _draw(size, shape);
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        image.dispose();
        final opaque = shape == _Shape.full || shape == _Shape.maskable;
        await File(
          path,
        ).writeAsBytes(_png(bytes!.buffer.asUint8List(), size, alpha: !opaque));
      }
    });
  });
}
