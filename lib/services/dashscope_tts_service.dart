import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_pcm_player/flutter_pcm_player.dart';

import 'package:vidlang/services/app_keys_service.dart';

/// DashScope TTS 服务（HTTP SSE 流式方式）
///
/// 使用阿里云 DashScope HTTP SSE API 实现流式语音合成，并通过 flutter_pcm_player
/// 实时播放 PCM 音频数据，实现真正的"边说边播"低延迟体验。
///
/// API 端点：POST https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation
/// 请求头：Authorization: Bearer {api_key}, Content-Type: application/json, X-DashScope-SSE: enable
/// 请求体：{"model": "qwen3-tts-flash", "input": {"text": "...", "voice": "..."}, "parameters": {"sample_rate": 24000, "format": "pcm"}}
///
/// 流式响应：SSE 格式，每行 data: {...}，音频数据在 output.audio.data 中（base64 编码的 PCM）
///
/// API Key 从 Supabase app_settings 表动态查询，不硬编码在客户端。
class DashScopeTtsService {
  static DashScopeTtsService? _instance;
  static DashScopeTtsService get instance =>
      _instance ??= DashScopeTtsService._();
  DashScopeTtsService._();

  // ─── 配置 ──────────────────────────────────

  /// DashScope HTTP SSE API 端点
  static const String _baseUrl =
      'https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation';

  /// 标准 TTS 模型（非定制模型）
  /// 参考：https://help.aliyun.com/zh/model-studio/qwen-tts
  static const String _model = 'qwen3-tts-flash';

  // ─── 支持的音色列表 ──────────────────────

  /// 常用英文音色
  static const Map<String, String> englishVoices = {
    'Aiden': 'Aiden',
    'Cherry': 'Cherry',
    'Chelsie': 'Chelsie',
    'Ethan': 'Ethan',
    'Serena': 'Serena',
  };

  /// 默认音色
  static const String defaultVoice = 'Cherry';

  /// PCM 播放器（用于流式播放）
  FlutterPcmPlayer? _pcmPlayer;

  /// 是否正在播放
  bool _isPlaying = false;

  /// 音频参数（根据 DashScope 文档）
  static const int _pcmSampleRate = 24000; // qwen3-tts-flash 默认 24kHz
  static const int _pcmChannels = 1; // 单声道
  static const PCMType _pcmType = PCMType.pcm16; // 16-bit PCM

  // ─── 流式播放接口（使用 flutter_pcm_player）───────────────────

  /// 流式合成 TTS 音频并实时播放
  ///
  /// [text] 要合成的文本
  /// [voice] 音色名称（默认 Cherry）
  /// [onComplete] 合成完成回调
  /// [onError] 错误回调
  Future<void> streamSynthesizeAndPlay({
    required String text,
    String voice = 'Cherry',
    void Function()? onComplete,
    void Function(String error)? onError,
  }) async {
    final sw = Stopwatch()..start();

    // 1. 获取 API Key
    final apiKey = await AppKeysService.getQwenApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      _log('❌ 无法获取 DashScope API Key');
      onError?.call('API Key 未配置');
      return;
    }

    final resolvedVoice = englishVoices[voice] ?? voice;
    _log(
      '⏳ 开始流式 TTS 合成 | voice=$resolvedVoice | format=wav | text="${_truncate(text, 40)}"',
    );

    // 2. 初始化 PCM 播放器
    await _initPcmPlayer();

    HttpClient? client;
    StreamSubscription? subscription;
    bool isCancelled = false;
    int totalBytes = 0;
    int chunkCount = 0;
    bool isFirstAudioChunk = true;

    try {
      // 3. 创建 HTTP 请求
      client = HttpClient();
      final uri = Uri.parse(_baseUrl);
      final request = await client.postUrl(uri);

      // 设置请求头
      request.headers.set('Authorization', 'Bearer $apiKey');
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('X-DashScope-SSE', 'enable');
      request.headers.set('Accept', 'text/event-stream');

      // 设置请求体（参考 aliyun_tts.dart，使用默认 WAV 格式）
      final body = jsonEncode({
        'model': _model,
        'input': {
          'text': text,
          'voice': resolvedVoice,
          'language_type': 'Auto',
        },
        'parameters': {'sample_rate': _pcmSampleRate},
      });
      request.add(utf8.encode(body));
      _log('📤 发送请求: model=$_model, voice=$resolvedVoice, format=pcm');

      // 4. 获取响应
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      if (response.statusCode != 200) {
        final errorBody = await response.transform(utf8.decoder).join();
        _log('❌ HTTP 错误 ${response.statusCode}: $errorBody');
        onError?.call('HTTP ${response.statusCode}: $errorBody');
        await _releasePcmPlayer();
        return;
      }

      // 5. 解析 SSE 流并实时播放
      String buffer = '';
      final completer = Completer<void>();

      subscription = response.listen(
        (List<int> chunk) {
          if (isCancelled) return;

          buffer += utf8.decode(chunk);
          // 处理粘包：按换行符分割，最后一部分（可能不完整）留回缓冲区
          final lines = buffer.split('\n');
          buffer = lines.removeLast();

          for (final line in lines) {
            final trimmed = line.trim();
            if (!trimmed.startsWith('data:')) continue;

            final jsonStr = trimmed.substring(5).trim();
            if (jsonStr.isEmpty || jsonStr == '[DONE]') continue;

            try {
              final data = jsonDecode(jsonStr);

              // 检查错误
              if (data['code'] != null && data['message'] != null) {
                final errorMsg = '${data['code']} - ${data['message']}';
                _log('❌ API 错误: $errorMsg');
                onError?.call(errorMsg);
                isCancelled = true;
                if (!completer.isCompleted) completer.complete();
                return;
              }

              // 提取音频数据（base64 编码的 PCM）
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

                // 首块数据：检查并跳过 WAV 头（如果存在）
                final pcmBytes = isFirstAudioChunk
                    ? _skipWavHeaderIfPresent(rawBytes)
                    : rawBytes;
                isFirstAudioChunk = false;

                if (pcmBytes.isEmpty) continue;

                // 实时喂入 PCM 播放器
                _feedPcmData(pcmBytes);
                totalBytes += pcmBytes.length;
                chunkCount++;
              }
            } catch (e) {
              _log('⚠️ 解析 SSE 数据失败: $e, jsonStr=${_truncate(jsonStr, 100)}');
            }
          }
        },
        onDone: () {
          if (isCancelled) {
            if (!completer.isCompleted) completer.complete();
            return;
          }

          // 处理缓冲区中剩余的数据
          if (buffer.trim().isNotEmpty) {
            final trimmed = buffer.trim();
            if (trimmed.startsWith('data:')) {
              final jsonStr = trimmed.substring(5).trim();
              if (jsonStr.isNotEmpty && jsonStr != '[DONE]') {
                try {
                  final data = jsonDecode(jsonStr);
                  String? audioBase64;
                  final output = data['output'];
                  if (output is Map) {
                    final audio = output['audio'];
                    if (audio is Map && audio['data'] is String) {
                      audioBase64 = audio['data'] as String;
                    }
                  }
                  if (audioBase64 != null && audioBase64.isNotEmpty) {
                    final rawBytes = base64Decode(audioBase64);
                    final pcmBytes = isFirstAudioChunk
                        ? _skipWavHeaderIfPresent(rawBytes)
                        : rawBytes;
                    if (pcmBytes.isNotEmpty) {
                      _feedPcmData(pcmBytes);
                      totalBytes += pcmBytes.length;
                      chunkCount++;
                    }
                  }
                } catch (_) {}
              }
            }
          }

          sw.stop();
          _log(
            '✅ 流式合成完成 (${sw.elapsedMilliseconds}ms): $chunkCount 个分片, 共 ${(totalBytes / 1024).toStringAsFixed(1)}KB',
          );

          // 计算音频时长，延迟释放和回调，确保播放完成
          // PCM 16-bit, 单声道, 24000Hz
          // 每毫秒数据量 = 24000 * 1 * 2 / 1000 = 48 bytes/ms
          const int bytesPerMs = 48; // 24000 * 1 * 2 / 1000
          final int audioDurationMs = totalBytes ~/ bytesPerMs;
          final int safeDelayMs = audioDurationMs + 200; // 加 200ms 缓冲

          _log('⏳ 等待音频播放完成 (${safeDelayMs}ms)...');

          Future.delayed(Duration(milliseconds: safeDelayMs), () {
            _releasePcmPlayer();
            onComplete?.call();
          });

          if (!completer.isCompleted) completer.complete();
        },
        onError: (e) {
          _log('💥 SSE 流错误: $e');
          onError?.call(e.toString());
          _releasePcmPlayer();
          if (!completer.isCompleted) completer.complete();
        },
        cancelOnError: true,
      );

      await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _log('⏰ 超时 (30s)');
          onError?.call('合成超时');
          subscription?.cancel();
          _releasePcmPlayer();
        },
      );
    } catch (e) {
      sw.stop();
      _log('💥 流式合成异常: $e');
      onError?.call(e.toString());
      _releasePcmPlayer();
    } finally {
      subscription?.cancel();
      client?.close();
    }
  }

  // ─── PCM 播放器管理 ─────────────────────────

  /// 初始化 PCM 播放器
  Future<void> _initPcmPlayer() async {
    // 释放之前的播放器
    await _releasePcmPlayer();

    _pcmPlayer = FlutterPcmPlayer();
    await _pcmPlayer!.initialize(
      nChannels: _pcmChannels,
      sampleRate: _pcmSampleRate,
      pcmType: _pcmType,
    );

    // 设置最大音量
    await _pcmPlayer!.setVolume(1.0);

    // 设置全局音频会话（iOS 需要，避免与录音冲突）
    await FlutterPcmPlayer.setGlobalAudioSession();

    _isPlaying = true;
    _log(
      '🎵 PCM 播放器初始化: ${_pcmSampleRate}Hz, ${_pcmChannels}ch, ${_pcmType.name}, volume=1.0',
    );
  }

  /// 喂入 PCM 数据
  Future<void> _feedPcmData(Uint8List data) async {
    if (_pcmPlayer == null || !_isPlaying) return;
    try {
      // 先 feed 数据到缓冲区
      await _pcmPlayer!.feed(data);

      // 首次喂入数据后开始播放（如果还没开始）
      if (_pcmPlayer!.playState == PlayState.stopped) {
        _log('▶️ 首次收到音频数据，启动播放');
        await _pcmPlayer!.play();
      }
    } catch (e) {
      _log('⚠️ PCM feed 错误: $e');
    }
  }

  /// 释放 PCM 播放器
  Future<void> _releasePcmPlayer() async {
    _isPlaying = false;
    if (_pcmPlayer != null) {
      try {
        await _pcmPlayer!.release();
      } catch (_) {}
      _pcmPlayer = null;
    }
  }

  /// 停止 PCM 播放（公共方法，供 TtsService 调用）
  Future<void> stopPcmPlayback() async {
    await _releasePcmPlayer();
  }

  // ─── 文件合成接口（兼容旧版，用于缓存）─────────────────

  /// 通过 HTTP SSE 流式合成 TTS 音频并保存到文件
  ///
  /// 返回音频文件的本地路径。如果失败返回 null。
  /// 注意：此方法使用 mp3 格式保存到文件，用于缓存。
  Future<String?> synthesize({
    required String text,
    required String outputPath,
    String voice = 'Cherry',
    String format = 'mp3',
    int sampleRate = 24000,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final sw = Stopwatch()..start();
    final audioChunks = <Uint8List>[];
    String? errorMsg;

    await _streamSynthesizeInternal(
      text: text,
      voice: voice,
      format: format,
      sampleRate: sampleRate,
      timeout: timeout,
      onAudioChunk: (chunk) => audioChunks.add(chunk),
      onComplete: () {},
      onError: (error) => errorMsg = error,
    );

    if (errorMsg != null) {
      _log('❌ 合成失败: $errorMsg');
      return null;
    }

    if (audioChunks.isEmpty) {
      _log('❌ 未收到任何音频数据');
      return null;
    }

    // 合并所有音频分片
    final totalLength = audioChunks.fold<int>(
      0,
      (sum, chunk) => sum + chunk.length,
    );
    final combined = Uint8List(totalLength);
    var offset = 0;
    for (final chunk in audioChunks) {
      combined.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }

    // 写入文件
    final file = File(outputPath);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(combined);

    sw.stop();
    _log(
      '☁️ [TTS] ✅ 保存成功 (${sw.elapsedMilliseconds}ms): ${(combined.length / 1024).toStringAsFixed(1)}KB → ${outputPath.split('/').last}',
    );
    return outputPath;
  }

  // ─── 内部流式合成方法 ─────────────────────────

  Future<void> _streamSynthesizeInternal({
    required String text,
    required String voice,
    required String format,
    required int sampleRate,
    required Duration timeout,
    required void Function(Uint8List chunk) onAudioChunk,
    required void Function() onComplete,
    required void Function(String error) onError,
  }) async {
    final apiKey = await AppKeysService.getQwenApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      onError('API Key 未配置');
      return;
    }

    final resolvedVoice = englishVoices[voice] ?? voice;

    HttpClient? client;
    StreamSubscription? subscription;
    bool isCancelled = false;
    String buffer = '';
    bool isFirstAudioChunk = true;

    try {
      client = HttpClient();
      final uri = Uri.parse(_baseUrl);
      final request = await client.postUrl(uri);

      request.headers.set('Authorization', 'Bearer $apiKey');
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('X-DashScope-SSE', 'enable');
      request.headers.set('Accept', 'text/event-stream');

      final body = jsonEncode({
        'model': _model,
        'input': {
          'text': text,
          'voice': resolvedVoice,
          'language_type': 'English',
        },
        'parameters': {'sample_rate': sampleRate, 'format': format},
      });
      request.add(utf8.encode(body));

      final response = await request.close().timeout(timeout);
      if (response.statusCode != 200) {
        final errorBody = await response.transform(utf8.decoder).join();
        onError('HTTP ${response.statusCode}: $errorBody');
        return;
      }

      final completer = Completer<void>();

      subscription = response.listen(
        (List<int> chunk) {
          if (isCancelled) return;

          buffer += utf8.decode(chunk);
          final lines = buffer.split('\n');
          buffer = lines.removeLast();

          for (final line in lines) {
            final trimmed = line.trim();
            if (!trimmed.startsWith('data:')) continue;

            final jsonStr = trimmed.substring(5).trim();
            if (jsonStr.isEmpty || jsonStr == '[DONE]') continue;

            try {
              final data = jsonDecode(jsonStr);

              if (data['code'] != null && data['message'] != null) {
                onError('${data['code']} - ${data['message']}');
                isCancelled = true;
                if (!completer.isCompleted) completer.complete();
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
                final bytes = isFirstAudioChunk
                    ? _skipWavHeaderIfPresent(rawBytes)
                    : rawBytes;
                isFirstAudioChunk = false;
                if (bytes.isNotEmpty) {
                  onAudioChunk(bytes);
                }
              }
            } catch (e) {
              _log('⚠️ 解析 SSE 数据失败: $e');
            }
          }
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
        onError: (e) {
          onError(e.toString());
          if (!completer.isCompleted) completer.complete();
        },
        cancelOnError: true,
      );

      await completer.future.timeout(
        timeout,
        onTimeout: () {
          onError('合成超时');
          subscription?.cancel();
        },
      );

      onComplete();
    } catch (e) {
      onError(e.toString());
    } finally {
      subscription?.cancel();
      client?.close();
    }
  }

  // ─── 内部辅助方法 ─────────────────────────

  /// 阿里音频块有时首块是完整 WAV，需剥离 44 字节头再按 PCM 处理
  Uint8List _skipWavHeaderIfPresent(Uint8List bytes) {
    if (bytes.length < 12) return bytes;

    final isRiff =
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46;
    final isWave =
        bytes[8] == 0x57 &&
        bytes[9] == 0x41 &&
        bytes[10] == 0x56 &&
        bytes[11] == 0x45;

    if (isRiff && isWave) {
      if (bytes.length <= 44) return Uint8List(0);
      return Uint8List.fromList(bytes.sublist(44));
    }

    return bytes;
  }

  /// 统一日志输出
  void _log(String message) {
    if (kReleaseMode) {
      print('🔊 [DashScopeTTS] $message');
    } else {
      debugPrint('🔊 [DashScopeTTS] $message');
    }
  }

  /// 截断长文本用于日志显示
  static String _truncate(String text, int maxLen) {
    if (text.length <= maxLen) return text;
    return '${text.substring(0, maxLen)}...';
  }
}
