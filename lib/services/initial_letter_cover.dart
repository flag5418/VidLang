import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui show Canvas, Color, FontWeight, Offset, Paint, PictureRecorder, Rect, ImageByteFormat, TextAlign, TextStyle, ParagraphBuilder, ParagraphStyle, ParagraphConstraints;

import 'package:flutter/painting.dart' show LinearGradient, Alignment;
import 'package:vidlang/services/thumbnail_service.dart';

class InitialLetterCover {
  static const _palette = [
    ui.Color(0xFF6C5CE7),
    ui.Color(0xFF0984E3),
    ui.Color(0xFF00B894),
    ui.Color(0xFFE17055),
    ui.Color(0xFFD63031),
    ui.Color(0xFFFD79A8),
    ui.Color(0xFFFDCB6E),
    ui.Color(0xFF74B9FF),
    ui.Color(0xFFA29BFE),
    ui.Color(0xFF55EFC4),
  ];

  static Future<String?> generate(String title, String folderCode) async {
    if (title.isEmpty) return null;

    final letter = _getFirstLetter(title);
    if (letter.isEmpty) return null;

    final colorIndex = title.codeUnits.fold<int>(0, (prev, c) => prev + c) % _palette.length;
    final bgColor = _palette[colorIndex];
    final accentColor = _lighten(bgColor, 0.3);

    const size = 512;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));

    final bgPaint = ui.Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [bgColor, accentColor],
      ).createShader(ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()), bgPaint);

    final textStyle = ui.TextStyle(
      color: const ui.Color(0xFFFFFFFF),
      fontSize: size * 0.45,
      fontWeight: ui.FontWeight.bold,
    );
    final paragraphBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: ui.TextAlign.center,
      fontSize: size * 0.45,
      fontWeight: ui.FontWeight.bold,
    ))
      ..pushStyle(textStyle)
      ..addText(letter);
    final paragraph = paragraphBuilder.build()..layout(ui.ParagraphConstraints(width: size.toDouble()));

    final dy = (size - paragraph.height) / 2;
    canvas.drawParagraph(paragraph, ui.Offset(0, dy));

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;

    final coverCode = '${DateTime.now().millisecondsSinceEpoch}_${letter.hashCode.abs()}';
    final coverFile = 'covers/$folderCode/$coverCode.png';
    final fullPath = await ThumbnailService.getFullPath(coverFile);

    final file = File(fullPath);
    final dir = file.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    await file.writeAsBytes(byteData.buffer.asUint8List());

    return coverFile;
  }

  static String _getFirstLetter(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return '';

    final firstChar = trimmed.substring(0, 1);
    if (RegExp(r'[a-zA-Z0-9]').hasMatch(firstChar)) {
      return firstChar.toUpperCase();
    }

    return firstChar;
  }

  static ui.Color _lighten(ui.Color color, double amount) {
    return ui.Color.fromARGB(
      (color.a * 255.0).round().clamp(0, 255),
      min(255, ((color.r * 255.0).round() + (255 - (color.r * 255.0).round()) * amount)).round().clamp(0, 255),
      min(255, ((color.g * 255.0).round() + (255 - (color.g * 255.0).round()) * amount)).round().clamp(0, 255),
      min(255, ((color.b * 255.0).round() + (255 - (color.b * 255.0).round()) * amount)).round().clamp(0, 255),
    );
  }
}
