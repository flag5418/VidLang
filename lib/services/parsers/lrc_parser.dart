import 'dart:io';

import 'package:uuid/uuid.dart';
import 'package:vidlang/models/subtitles.dart';

class LrcParser {
  static const _uuid = Uuid();

  static Future<List<Subtitles>> parseFile(String filePath, String videoCode) async {
    final file = File(filePath);
    if (!await file.exists()) return [];

    final content = await file.readAsString();
    return parseContent(content, videoCode);
  }

  static List<Subtitles> parseContent(String content, String videoCode) {
    final lines = content.split(RegExp(r'\r?\n'));
    final rawItems = <_LrcLine>[];
    final metadata = <String, String>{};

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final metaMatch = RegExp(r'^\[(\w+):(.*)\]$').firstMatch(trimmed);
      if (metaMatch != null) {
        final tag = metaMatch.group(1)!.toLowerCase();
        if (tag == 'ti') metadata['title'] = metaMatch.group(2)!;
        if (tag == 'ar') metadata['artist'] = metaMatch.group(2)!;
        if (tag == 'al') metadata['album'] = metaMatch.group(2)!;
        if (tag == 'la') metadata['language'] = metaMatch.group(2)!;
        continue;
      }

      final timeMatch = RegExp(r'^(\[[\d:.]+\]+)(.*)$').firstMatch(trimmed);
      if (timeMatch == null) continue;

      final timeStr = timeMatch.group(1)!;
      final text = timeMatch.group(2)!.trim();
      if (text.isEmpty) continue;

      final timestamps = RegExp(r'\[(\d{1,3}):(\d{2})([.:]\d{1,3})?\]').allMatches(timeStr);
      for (final tm in timestamps) {
        final min = int.tryParse(tm.group(1) ?? '0') ?? 0;
        final sec = int.tryParse(tm.group(2) ?? '0') ?? 0;
        final msStr = tm.group(3);
        int ms = 0;
        if (msStr != null) {
          final cleaned = msStr.substring(1).padRight(3, '0');
          ms = int.tryParse(cleaned.substring(0, 3)) ?? 0;
        }
        final startMs = min * 60000 + sec * 1000 + ms;
        rawItems.add(_LrcLine(startMs: startMs, text: text));
      }
    }

    rawItems.sort((a, b) => a.startMs.compareTo(b.startMs));

    final result = <Subtitles>[];
    for (int i = 0; i < rawItems.length; i++) {
      final item = rawItems[i];
      final endMs = i + 1 < rawItems.length ? rawItems[i + 1].startMs : item.startMs + 5000;

      String? translation;
      final text = item.text;
      if (text.contains(' // ') || text.contains(' / ')) {
        final parts = text.split(RegExp(r'\s+//\s+|\s+/\s+'));
        if (parts.length >= 2) {
          translation = parts.sublist(1).join(' ').trim();
        }
      }

      final sub = Subtitles(
        videoCode: videoCode,
        startPosition: item.startMs,
        endPosition: endMs,
        content: text.split(RegExp(r'\s+//\s+|\s+/\s+')).first.trim(),
        contentTranslate: translation,
        type: 'lyric',
        source: 'user_import',
      );
      sub.code = _uuid.v4().replaceAll('-', '');
      result.add(sub);
    }

    return result;
  }

  static Map<String, String> parseMetadata(String content) {
    final metadata = <String, String>{};
    final lines = content.split(RegExp(r'\r?\n'));
    for (final line in lines) {
      final trimmed = line.trim();
      final metaMatch = RegExp(r'^\[(\w+):(.*)\]$').firstMatch(trimmed);
      if (metaMatch != null) {
        final tag = metaMatch.group(1)!.toLowerCase();
        final val = metaMatch.group(2)!;
        if (['ti', 'ar', 'al', 'la', 'by', 'offset'].contains(tag)) {
          metadata[tag] = val;
        }
      }
    }
    return metadata;
  }
}

class _LrcLine {
  final int startMs;
  final String text;
  const _LrcLine({required this.startMs, required this.text});
}
