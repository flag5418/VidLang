import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';
import 'package:vidlang/models/participle.dart';
import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/services/auth_service.dart';
import 'package:vidlang/services/conversation_service.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/id3_parser.dart';

class PronunciationMapEntry {
  final String word;
  final String zh;

  const PronunciationMapEntry({required this.word, required this.zh});

  Map<String, dynamic> toJson() => {'word': word, 'zh': zh};

  factory PronunciationMapEntry.fromJson(Map<String, dynamic> json) {
    return PronunciationMapEntry(
      word: json['word'] as String? ?? '',
      zh: json['zh'] as String? ?? '',
    );
  }
}

class SubtitleItem {
  final String content;
  final String? contentTranslate;
  final int? startMs;
  final int? endMs;
  final String? pronunciation;
  final List<PronunciationMapEntry>? pronunciationMap;

  const SubtitleItem({
    required this.content,
    this.contentTranslate,
    this.startMs,
    this.endMs,
    this.pronunciation,
    this.pronunciationMap,
  });

  factory SubtitleItem.fromJson(Map<String, dynamic> json) {
    return SubtitleItem(
      content: json['content'] as String? ?? '',
      contentTranslate: json['content_translate'] as String?,
      startMs: json['start_ms'] as int?,
      endMs: json['end_ms'] as int?,
      pronunciation: json['pronunciation'] as String?,
      pronunciationMap: (json['pronunciation_map'] as List?)
          ?.map((e) => PronunciationMapEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AudioRecognitionResult {
  final bool ok;
  final String? language;
  final List<SubtitleItem> items;
  final String source;

  const AudioRecognitionResult({
    required this.ok,
    this.language,
    this.items = const [],
    this.source = 'ai_recognize',
  });
}

class LyricsSearchResult {
  final bool ok;
  final String? language;
  final String? title;
  final String? artist;
  final String? coverUrl;
  final List<SubtitleItem> items;
  final String source;

  const LyricsSearchResult({
    required this.ok,
    this.language,
    this.title,
    this.artist,
    this.coverUrl,
    this.items = const [],
    this.source = 'ai_lyrics_search',
  });
}

class AudioRecognitionService {
  static const _uuid = Uuid();
  static const _functionName = 'ai-audio-recognize';

  static Future<AudioRecognitionResult> recognizeSpeech({
    required String videoCode,
    required String filePath,
    bool includePronunciation = true,
  }) async {
    try {
      AuthService.instance.ensureActiveSession();

      final file = File(filePath);
      if (!await file.exists()) {
        return const AudioRecognitionResult(ok: false);
      }

      final bytes = await file.readAsBytes();
      final audioBase64 = base64Encode(bytes);

      final client = sb.Supabase.instance.client;
      final response = await client.functions.invoke(
        _functionName,
        body: {
          'type': 'speech_recognize',
          'video_code': videoCode,
          'audio_base64': audioBase64,
          'include_pronunciation': includePronunciation,
        },
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return const AudioRecognitionResult(ok: false);
      }

      final ok = data['ok'] as bool? ?? false;
      if (!ok) return const AudioRecognitionResult(ok: false);

      final items = (data['items'] as List?)
              ?.map((e) => SubtitleItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];

      return AudioRecognitionResult(
        ok: true,
        language: data['language'] as String?,
        items: items,
        source: data['source'] as String? ?? 'ai_recognize',
      );
    } catch (_) {
      return const AudioRecognitionResult(ok: false);
    }
  }

  static Future<LyricsSearchResult> searchLyrics({
    required String videoCode,
    required String title,
    String? artist,
    bool includePronunciation = true,
  }) async {
    try {
      AuthService.instance.ensureActiveSession();

      final client = sb.Supabase.instance.client;
      final response = await client.functions.invoke(
        _functionName,
        body: {
          'type': 'lyrics_search',
          'video_code': videoCode,
          'title': title,
          'artist': artist,
          'include_pronunciation': includePronunciation,
        },
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return const LyricsSearchResult(ok: false);
      }

      final ok = data['ok'] as bool? ?? false;
      if (!ok) return const LyricsSearchResult(ok: false);

      final items = (data['items'] as List?)
              ?.map((e) => SubtitleItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];

      return LyricsSearchResult(
        ok: true,
        language: data['language'] as String?,
        title: data['title'] as String?,
        artist: data['artist'] as String?,
        coverUrl: data['cover_url'] as String?,
        items: items,
        source: data['source'] as String? ?? 'ai_lyrics_search',
      );
    } catch (_) {
      return const LyricsSearchResult(ok: false);
    }
  }

  static Future<Id3Tags?> extractId3Tags(String filePath) async {
    return Id3Parser.parse(filePath);
  }

  static Future<void> saveRecognitionResultToDb({
    required String videoCode,
    required List<SubtitleItem> items,
    String? language,
    String source = 'ai_recognize',
  }) async {
    final subtitles = <Subtitles>[];
    final participles = <Participle>[];

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final subCode = _uuid.v4().replaceAll('-', '');

      String? pronunciationMapJson;
      if (item.pronunciationMap != null && item.pronunciationMap!.isNotEmpty) {
        pronunciationMapJson = jsonEncode(
          item.pronunciationMap!.map((e) => e.toJson()).toList(),
        );
      }

      final sub = Subtitles(
        videoCode: videoCode,
        startPosition: item.startMs ?? i * 5000,
        endPosition: item.endMs ?? (i + 1) * 5000,
        content: item.content,
        contentTranslate: item.contentTranslate,
        type: 'lyric',
        source: source,
        pronunciation: item.pronunciation,
        pronunciationMapJson: pronunciationMapJson,
      );
      sub.code = subCode;
      subtitles.add(sub);

      final words = item.content.split(RegExp(r'\s+'));
      for (final word in words) {
        final cleaned = word.replaceAll(RegExp(r'[^\w]'), '');
        if (cleaned.isEmpty || cleaned.length < 2) continue;
        final p = Participle(
          videoCode: videoCode,
          subtitlesCode: subCode,
          content: cleaned.toLowerCase(),
        );
        p.code = _uuid.v4().replaceAll('-', '');
        participles.add(p);
      }
    }

    for (final sub in subtitles) {
      await DatabaseService.insert(sub);
    }
    for (final p in participles) {
      await DatabaseService.insert(p);
    }

    final videos = await DatabaseService.findByCondition(
      () => VideoInfo(),
      where: 'code = ? AND is_deleted = 0',
      whereArgs: [videoCode],
      limit: 1,
    );
    if (videos.isNotEmpty) {
      final video = videos.first;
      video.hasSubtitles = true;
      if (language != null) video.language = language;
      await DatabaseService.update(video);
    }

    // v2.0: 从 VideoInfo 查询 folderCode 用于云端按文件夹组织存储
    String? fc;
    try {
      final vids = await DatabaseService.findByCondition(() => VideoInfo(), where: 'code = ? AND is_deleted = 0', whereArgs: [videoCode], limit: 1);
      if (vids.isNotEmpty) fc = vids.first.folderCode;
    } catch (_) {}
    unawaited(ConversationService.uploadSubtitlesToCloud(videoCode, folderCode: fc));
  }

  static Future<void> saveLyricsResultToDb({
    required String videoCode,
    required LyricsSearchResult result,
  }) async {
    await saveRecognitionResultToDb(
      videoCode: videoCode,
      items: result.items,
      language: result.language,
      source: result.source,
    );

    if (result.artist != null || result.title != null) {
      final videos = await DatabaseService.findByCondition(
        () => VideoInfo(),
        where: 'code = ? AND is_deleted = 0',
        whereArgs: [videoCode],
        limit: 1,
      );
      if (videos.isNotEmpty) {
        final video = videos.first;
        if (result.artist != null) video.artist = result.artist;
        if (result.title != null && video.name.isEmpty) {
          video.name = result.title!;
        }
        await DatabaseService.update(video);
      }
    }
  }
}

void unawaited(Future<void>? future) {
  future?.then((_) {}, onError: (_) {});
}
