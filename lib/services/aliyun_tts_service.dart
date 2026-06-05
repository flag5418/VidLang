import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:vidlang/config.dart';
import 'package:vidlang/utils/pcm_helper.dart';

/// 阿里云流式 TTS 服务（单例）
///
/// 通过阿里云 DashScope API 流式合成语音并播放。
/// 支持本地文件缓存，避免重复请求阿里云 API。
///
/// 使用示例：
/// ```dart
/// final tts = AliyunTtsService();
/// await tts.playTts(
///   'Hello world',
///   filePlayer: audioPlayer,
///   pcmPlayer: flutterPcmPlayer,
/// );
/// ```
class AliyunTtsService {
  static final AliyunTtsService _instance = AliyunTtsService._internal();
  factory AliyunTtsService() => _instance;
  AliyunTtsService._internal();

  StreamSubscription? _currentSubscription;
  HttpClient? _currentClient;
  Completer<String?>? _currentCompleter;
  bool _isCancelled = false;

  String get _apiKey => AppConfig.aliDashScopeApiKey;

  /// 取消当前流式请求
  Future<void> _cancelCurrentStream() async {
    _isCancelled = true;
    await _currentSubscription?.cancel();
    _currentSubscription = null;
    _currentClient?.close(force: true);
    _currentClient = null;
    if (_currentCompleter != null && !_currentCompleter!.isCompleted) {
      _currentCompleter!.complete(null);
    }
    _currentCompleter = null;
  }

  /// 播放 TTS 语音
  ///
  /// [text] 要朗读的文本
  /// [voice] 音色，默认使用 AppConfig 中的配置
  /// [filePlayer] 普通音频播放器（用于播放本地缓存文件）
  /// [pcmPlayer] PCM 流式播放器（用于播放流式数据）
  /// [onStreamingComplete] 流式播放完成回调
  Future<void> playTts(
    String text, {
    String voice = '',
    required ap.AudioPlayer filePlayer,
    required dynamic pcmPlayer,
    FutureOr<void> Function()? onStreamingComplete,
  }) async {
    if (text.isEmpty) return;
    final effectiveVoice = voice.isNotEmpty ? voice : AppConfig.aliTtsDefaultVoice;

    try {
      // 先尝试从本地缓存播放
      final cachedPath = await _findInCache(text, effectiveVoice);
      if (cachedPath != null) {
        final file = File(cachedPath);
        if (await file.exists()) {
          print('AliyunTTS: 命中缓存 - $cachedPath');
          await filePlayer.stop();
          try {
            await pcmPlayer.stop();
          } catch (_) {}
          await filePlayer.play(ap.DeviceFileSource(cachedPath));

          if (onStreamingComplete != null) {
            filePlayer.onPlayerComplete.first.then((_) async {
              await onStreamingComplete();
            });
          }
          return;
        }
      }

      // 无缓存，调用 API 流式播放并保存
      print('AliyunTTS: 未命中缓存，流式请求 - $text');
      await _cancelCurrentStream();

      await filePlayer.stop();
      try {
        await pcmPlayer.stop();
        await pcmPlayer.play();
      } catch (_) {}

      await _streamAndPlayAndSave(
        text,
        effectiveVoice,
        pcmPlayer,
        onPlaybackComplete: onStreamingComplete,
      );
    } catch (e) {
      print('AliyunTTS 错误: $e');
      try {
        await pcmPlayer.stop();
      } catch (_) {}
    }
  }

  /// 流式请求并播放、保存音频
  Future<void> _streamAndPlayAndSave(
    String text,
    String voice,
    dynamic pcmPlayer, {
    FutureOr<void> Function()? onPlaybackComplete,
  }) async {
    if (_apiKey.isEmpty) {
      print('AliyunTTS: API Key 未设置，请在 config.dart 中设置 aliDashScopeApiKey');
      return;
    }

    _isCancelled = false;
    final completer = Completer<String?>();
    _currentCompleter = completer;

    final client = HttpClient();

    try {
      final uri = Uri.parse(AppConfig.aliTtsBaseUrl);
      final request = await client.postUrl(uri);

      request.headers.set('Authorization', 'Bearer $_apiKey');
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('X-DashScope-SSE', 'enable');

      final body = jsonEncode({
        'model': AppConfig.aliTtsModel,
        'input': {
          'text': text,
          'voice': voice,
          'language_type': 'English',
        },
        'parameters': {
          'sample_rate': AppConfig.aliTtsSampleRate,
        },
      });
      request.add(utf8.encode(body));

      final response = await request.close();
      if (response.statusCode != 200) {
        final errorBody = await response.transform(utf8.decoder).join();
        print('AliyunTTS API 错误: ${response.statusCode} $errorBody');
        if (!completer.isCompleted) completer.complete(null);
        return;
      }

      final List<Uint8List> pcmChunks = [];
      bool isFirstAudioChunk = true;

      _currentSubscription = response
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          if (_isCancelled) return;

          final trimmed = line.trim();
          if (!trimmed.startsWith('data:')) return;

          final jsonStr = trimmed.substring(5).trim();
          if (jsonStr.isEmpty || jsonStr == '[DONE]') return;

          try {
            final data = jsonDecode(jsonStr) as Map<String, dynamic>;

            if (data['code'] != null && data['message'] != null) {
              print('AliyunTTS 服务错误: ${data['code']} - ${data['message']}');
              if (!completer.isCompleted) completer.complete(null);
              return;
            }

            String? audioBase64;
            final output = data['output'];
            if (output is Map) {
              final audio = output['audio'];
              if (audio is Map && audio['data'] is String) {
                audioBase64 = audio['data'] as String;
              } else if (output['choices'] is List &&
                  (output['choices'] as List).isNotEmpty) {
                final choice = (output['choices'] as List).first;
                if (choice is Map) {
                  final message = choice['message'];
                  if (message is Map) {
                    final content = message['content'];
                    if (content is Map && content['audio_data'] is String) {
                      audioBase64 = content['audio_data'] as String;
                    }
                  }
                }
              }
            }

            if (audioBase64 != null && audioBase64.isNotEmpty) {
              final rawBytes = base64Decode(audioBase64);
              final bytes = PcmHelper.normalizeIncomingAudioBytes(
                rawBytes,
                isFirstChunk: isFirstAudioChunk,
              );
              isFirstAudioChunk = false;

              if (bytes.isNotEmpty) {
                pcmChunks.add(bytes);
                try {
                  pcmPlayer.write(bytes);
                } catch (_) {}
              }
            }

            if (output is Map && output['is_end'] == true) {
              _saveToCache(text, voice, pcmChunks).then((path) {
                if (!completer.isCompleted) completer.complete(path);
              });
            }
          } catch (e) {
            print('AliyunTTS 解析 SSE 错误: $e');
          }
        },
        onError: (e) {
          print('AliyunTTS 流错误: $e');
          if (!completer.isCompleted) completer.complete(null);
        },
        cancelOnError: true,
      );

      await completer.future;

      if (onPlaybackComplete != null) {
        await onPlaybackComplete();
      }
    } catch (e) {
      print('AliyunTTS 请求错误: $e');
      if (!completer.isCompleted) completer.complete(null);
    } finally {
      client.close();
      _currentClient = null;
      _currentSubscription = null;
      _isCancelled = false;
    }
  }

  /// 获取音频文件路径（不播放，仅下载保存）
  Future<String?> getAudioPath(String text, {String voice = ''}) async {
    if (text.isEmpty) return null;
    final effectiveVoice = voice.isNotEmpty ? voice : AppConfig.aliTtsDefaultVoice;

    try {
      final cachedPath = await _findInCache(text, effectiveVoice);
      if (cachedPath != null && await File(cachedPath).exists()) {
        return cachedPath;
      }
      return await _downloadAndSave(text, effectiveVoice);
    } catch (e) {
      print('AliyunTTS getAudioPath 错误: $e');
      return null;
    }
  }

  /// 下载并保存为文件
  Future<String?> _downloadAndSave(String text, String voice) async {
    if (_apiKey.isEmpty) return null;

    final client = HttpClient();
    try {
      final uri = Uri.parse(AppConfig.aliTtsBaseUrl);
      final request = await client.postUrl(uri);

      request.headers.set('Authorization', 'Bearer $_apiKey');
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('X-DashScope-SSE', 'enable');

      final body = jsonEncode({
        'model': AppConfig.aliTtsModel,
        'input': {
          'text': text,
          'voice': voice,
          'language_type': 'English',
        },
        'parameters': {
          'sample_rate': AppConfig.aliTtsSampleRate,
        },
      });
      request.add(utf8.encode(body));

      final response = await request.close();
      if (response.statusCode != 200) {
        final errorBody = await response.transform(utf8.decoder).join();
        print('AliyunTTS 下载错误: ${response.statusCode} $errorBody');
        return null;
      }

      final List<Uint8List> pcmChunks = [];
      bool isFirstAudioChunk = true;

      await for (final chunk in response.transform(utf8.decoder)) {
        final lines = chunk.split('\n');
        for (final line in lines) {
          final trimmed = line.trim();
          if (!trimmed.startsWith('data:')) continue;

          final jsonStr = trimmed.substring(5).trim();
          if (jsonStr.isEmpty || jsonStr == '[DONE]') continue;

          try {
            final data = jsonDecode(jsonStr) as Map<String, dynamic>;
            if (data['code'] != null && data['message'] != null) {
              print('AliyunTTS 服务错误: ${data['code']} - ${data['message']}');
              return null;
            }

            String? audioBase64;
            final output = data['output'];
            if (output is Map) {
              final audio = output['audio'];
              if (audio is Map && audio['data'] is String) {
                audioBase64 = audio['data'] as String;
              } else if (output['choices'] is List &&
                  (output['choices'] as List).isNotEmpty) {
                final choice = (output['choices'] as List).first;
                if (choice is Map) {
                  final message = choice['message'];
                  if (message is Map) {
                    final content = message['content'];
                    if (content is Map && content['audio_data'] is String) {
                      audioBase64 = content['audio_data'] as String;
                    }
                  }
                }
              }
            }

            if (audioBase64 != null && audioBase64.isNotEmpty) {
              final rawBytes = base64Decode(audioBase64);
              final bytes = PcmHelper.normalizeIncomingAudioBytes(
                rawBytes,
                isFirstChunk: isFirstAudioChunk,
              );
              isFirstAudioChunk = false;
              if (bytes.isNotEmpty) {
                pcmChunks.add(bytes);
              }
            }
          } catch (e) {
            print('AliyunTTS 解析错误: $e');
          }
        }
      }

      if (pcmChunks.isEmpty) return null;
      return await _saveToCache(text, voice, pcmChunks);
    } catch (e) {
      print('AliyunTTS 下载错误: $e');
      return null;
    } finally {
      client.close();
    }
  }

  // ==================== 缓存管理 ====================

  Future<Directory> _getCacheDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/tts_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 查找本地缓存
  Future<String?> _findInCache(String text, String voice) async {
    try {
      final dir = await _getCacheDir();
      final cacheFile = File('${dir.path}/_cache_index.json');
      if (!await cacheFile.exists()) return null;

      final content = await cacheFile.readAsString();
      final index = jsonDecode(content) as Map<String, dynamic>;
      final key = '${text.hashCode}_${voice.hashCode}';
      final entry = index[key] as Map<String, dynamic>?;
      if (entry == null) return null;

      final filePath = entry['path'] as String;
      if (await File(filePath).exists()) return filePath;

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 保存到本地缓存
  Future<String?> _saveToCache(String text, String voice, List<Uint8List> pcmChunks) async {
    try {
      final fileName = const Uuid().v4();
      final dir = await _getCacheDir();
      final filePath = await PcmHelper.convertPcmListAndSave(
        pcmChunks,
        fileName: fileName,
        sampleRate: AppConfig.aliTtsSampleRate,
        fileDirectory: 'tts_cache',
      );

      if (filePath == null) return null;

      // 更新缓存索引
      final cacheFile = File('${dir.path}/_cache_index.json');
      Map<String, dynamic> index = {};
      if (await cacheFile.exists()) {
        final content = await cacheFile.readAsString();
        index = jsonDecode(content) as Map<String, dynamic>;
      }

      final key = '${text.hashCode}_${voice.hashCode}';
      index[key] = {
        'text': text,
        'voice': voice,
        'path': filePath,
        'created_at': DateTime.now().toIso8601String(),
      };

      await cacheFile.writeAsString(jsonEncode(index));
      return filePath;
    } catch (e) {
      print('AliyunTTS 缓存保存失败: $e');
      return null;
    }
  }

  /// 取消当前正在进行的请求
  Future<void> cancel() async {
    await _cancelCurrentStream();
  }
}
