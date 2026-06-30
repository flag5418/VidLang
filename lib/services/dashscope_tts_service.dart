import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';

import 'package:vidlang/services/app_keys_service.dart';

/// DashScope Realtime TTS 服务
///
/// 通过 WebSocket 直连阿里云 DashScope Realtime API 实现流式语音合成。
///
/// ⚠️ 重要：dashscope realtime 端点默认使用 Omni Realtime 协议（snake_case 消息格式）。
///   服务端返回 session.created / response.audio.delta 等事件。
///   因此本服务使用 snake_case 格式进行通信。
///
/// WebSocket 交互流程：
/// 1. 连接 wss://dashscope.aliyuncs.com/api-ws/v1/realtime
/// 2. 收到 session.created（会话建立确认）
/// 3. 发送 session.update 配置（音色、格式、采样率、modalities 等）
/// 4. 发送 input_text_buffer.append 文本输入
/// 5. 发送 input_audio_buffer.commit 提交文本
/// 6. 接收 response.audio.delta（多个音频分片，base64 编码）
/// 7. 接收 response.done（合成完成）
///
/// API Key 从 Supabase app_settings 表动态查询，不硬编码在客户端。
class DashScopeTtsService {
  static DashScopeTtsService? _instance;
  static DashScopeTtsService get instance => _instance ??= DashScopeTtsService._();
  DashScopeTtsService._();

  // ─── 支持的音色列表 ──────────────────────

  /// 常用英文音色（Omni Realtime / Qwen-TTS 支持的音色名）
  /// 参考：https://help.aliyun.com/zh/model-studio/qwen-tts
  static const Map<String, String> englishVoices = {
    'Aiden': 'Cherry',
    'Cherry': 'Cherry',
    'Chelsie': 'Chelsie',
    'Ethan': 'Ethan',
    'Serena': 'Serena',
  };

  /// 默认音色
  static const String defaultVoice = 'Cherry';

  // ─── 公开 API ─────────────────────────────

  /// 通过 WebSocket 流式合成 TTS 音频
  ///
  /// 返回音频文件的本地路径。如果失败返回 null。
  ///
  /// [text] 要合成的文本
  /// [outputPath] 输出文件路径
  /// [voice] 音色名称（默认 Cherry），可选值见 [englishVoices]
  /// [format] 音频格式：mp3 / pcm / wav（默认 mp3）
  /// [sampleRate] 采样率：8000/16000/22050/24000/44100/48000（默认 24000）
  /// [timeout] 超时时间（默认 30 秒）
  Future<String?> synthesize({
    required String text,
    required String outputPath,
    String voice = 'Cherry',
    String format = 'mp3',
    int sampleRate = 24000,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final sw = Stopwatch()..start();

    try {
      // 1. 获取 API Key（通过 AppKeysService 安全获取，若正在加载中则等待）
      final apiKey = await AppKeysService.getQwenApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        _log('❌ 无法获取 DashScope API Key（AppKeysService 未就绪或未配置 qwen_api_key）');
        return null;
      }

      // 规范化音色名称
      final resolvedVoice = englishVoices[voice] ?? voice;

      _log('⏳ 开始 Realtime TTS 合成 | voice=$resolvedVoice | format=$format | sampleRate=$sampleRate | text="${_truncate(text, 40)}"');

      // 2. 建立 WebSocket 连接
      // DashScope Realtime 端点（默认使用 Omni Realtime 协议，snake_case 格式）
      const wsUrl = 'wss://dashscope.aliyuncs.com/api-ws/v1/realtime';
      final socket = await WebSocket.connect(
        wsUrl,
        headers: {
          'Authorization': 'Bearer $apiKey',
          // 根据 Omni Realtime 文档，必须声明 protocol version
          'Sec-WebSocket-Protocol': 'realtime',
          'X-DashScope-DataInspection': 'enable',
        },
      ).timeout(timeout);

      final channel = IOWebSocketChannel(socket);
      final completer = Completer<String?>();
      final audioChunks = <int>[];
      bool sessionCreated = false;  // session.created 已收到
      bool finished = false;       // response.done 或类似结束信号
      String? errorMsg;

      // 3. 监听消息（Omni Realtime 协议 - snake_case 格式）
      channel.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message as String) as Map<String, dynamic>;
            final type = data['type'] as String?;

            _log('📥 收到消息: type=$type');

            switch (type) {
              // ═══ 会话生命周期事件（snake_case）═══
              case 'session.created':
                // 服务端会话创建成功（Omni Realtime 格式）
                sessionCreated = true;
                _log('📡 会话已创建 (session.created)');
                // 打印会话详情（包含实际模型信息）
                if (kDebugMode && data['session'] != null) {
                  final sess = data['session'] as Map<String, dynamic>;
                  _log('   model=${sess["model"]}, id=${sess["id"]}');
                }
                break;

              // ═══ 音频数据事件（snake_case）═══
              case 'response.audio.delta':
                // 收到音频分片增量（base64 编码）
                final delta = data['delta'];
                if (delta is String && delta.isNotEmpty) {
                  audioChunks.addAll(base64Decode(delta));
                  _log('🎵 音频分片: ${delta.length} chars → 累计 ${audioChunks.length} bytes');
                }
                break;

              case 'response.audio.done':
                // 音频输出完成
                _log('🎵 音频输出完成 (response.audio.done), 共 ${audioChunks.length} bytes');
                break;

              case 'response.text.done':
                // 文本响应完成（TTS 场景下可能不出现）
                _log('📝 文本响应完成 (response.text.done)');
                break;

              case 'response.done':
                // 整个响应周期完成
                finished = true;
                _log('✅ 合成完成 (response.done), 共收到 ${audioChunks.length} bytes (${sw.elapsedMilliseconds}ms)');
                break;

              // ═══ 输入确认事件 ═══
              case 'input_audio_buffer.speech_started':
                _log('🎤 语音输入开始（可忽略，TTS 场景无实际意义）');
                break;

              case 'input_audio_buffer.speech_stopped':
                _log('🔇 语音输入停止（可忽略，TTS 场景无实际意义）');
                break;

              // ═══ 错误事件 ═══
              case 'error':
                errorMsg = data['error']?['message']
                    ?? data['message']
                    ?? data['error']?.toString()
                    ?? 'Unknown error';
                _log('❌ 错误 (error): $errorMsg');
                if (kDebugMode) {
                  _log('📋 错误详情: ${const JsonEncoder.withIndent("  ").convert(data)}');
                }
                break;

              // ═══ rate limit 等其他事件 ═══
              case 'rate_limit.error':
                errorMsg = 'Rate limit exceeded';
                _log('⚠️ 速率限制 (rate_limit.error)');
                break;

              default:
                // 未处理的消息类型，打印用于调试
                if (kDebugMode) {
                  _log('⚠️ 未处理的消息类型: $type | data: ${_truncate(data.toString(), 200)}');
                }
                break;
            }
          } catch (e) {
            _log('⚠️ 解析消息失败: $e');
          }

          // 检查是否完成
          if (finished || errorMsg != null) {
            if (!completer.isCompleted) {
              if (finished && audioChunks.isNotEmpty) {
                completer.complete(_writeAudioFile(audioChunks, outputPath, format));
              } else {
                completer.completeError(Exception(errorMsg ?? 'TTS 合成未完成'));
              }
            }
            try { channel.sink.close(); } catch (_) {}
          }
        },
        onError: (error) {
          _log('💥 WebSocket 错误: $error');
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
        onDone: () {
          _log('🔌 WebSocket 连接关闭 (onDone)');
          if (!completer.isCompleted) {
            if (finished && audioChunks.isNotEmpty) {
              completer.complete(_writeAudioFile(audioChunks, outputPath, format));
            } else if (errorMsg != null) {
              completer.completeError(Exception(errorMsg));
            } else {
              // 连接意外关闭但未收到完成信号
              if (audioChunks.isNotEmpty) {
                _log('⚠️ 连接意外关闭但有部分数据 (${audioChunks.length} bytes)，尝试保存');
                completer.complete(_writeAudioFile(audioChunks, outputPath, format));
              } else {
                completer.completeError(Exception('WebSocket 意外关闭，未收到任何音频数据'));
              }
            }
          }
        },
      );

      // 4. 等待 session.created 事件（服务端先发此事件确认连接）
      await Future.delayed(const Duration(milliseconds: 500));

      if (!sessionCreated) {
        _log('⚠️ 未收到 session.created，继续尝试发送配置...');
      }

      // ═══ 步骤 1：发送会话配置（session.update）═══
      // 使用 Omni Realtime 协议的 snake_case 格式
      // 配置 TTS 参数：只启用音频模态、指定音色和格式
      final sessionUpdate = {
        'type': 'session.update',
        'session': {
          // 只接收音频输出（禁用文本输出，纯 TTS 模式）
          'modalities': ['audio'],
          // 音频输出配置
          'audio': {
            'format': format.toUpperCase(), // MP3 / PCM / WAV
            'sample_rate': sampleRate,
          },
          // TTS 音色
          'voice': resolvedVoice,
          // 关闭输入音频检测（我们是纯文本 TTS，不需要麦克风输入）
          'turn_detection': 'disable',
          // 使用服务端提交模式
          'mode': 'server_commit',
          // 指示服务端这是 TTS-only 会话（减少不必要的处理）
          'input_audio_format': null,
        },
      };

      _log('📤 发送 session.update: voice=$resolvedVoice, format=${format.toUpperCase()}, sampleRate=$sampleRate');
      channel.sink.add(jsonEncode(sessionUpdate));

      // 等待一小段时间让服务端处理配置
      await Future.delayed(const Duration(milliseconds: 300));

      // ═══ 步骤 2：发送文本输入（input_text_buffer.append + commit）═══
      // 先追加文本
      final textAppend = {
        'type': 'input_text_buffer.append',
        'text': text,
      };
      _log('📤 发送 input_text_buffer.append: "${_truncate(text, 40)}"');
      channel.sink.add(jsonEncode(textAppend));

      // 再提交文本（触发服务端开始合成）
      await Future.delayed(const Duration(milliseconds: 100));
      final textCommit = {
        'type': 'input_text_buffer.commit',
      };
      _log('📤 发送 input_text_buffer.commit');
      channel.sink.add(jsonEncode(textCommit));

      // 5. 等待结果（带超时）
      final result = await completer.future.timeout(
        timeout,
        onTimeout: () {
          _log('⏰ 超时 (${timeout.inSeconds}s), 已接收 ${audioChunks.length} bytes');
          try { channel.sink.close(); } catch (_) {}
          // 超时但有部分数据时返回部分结果
          if (audioChunks.isNotEmpty) {
            return _writeAudioFile(audioChunks, outputPath, format);
          }
          return null;
        },
      );

      sw.stop();
      if (result != null) {
        _log('☁️ [Realtime-TTS] ✅ 合成成功 (${sw.elapsedMilliseconds}ms): ${(audioChunks.length / 1024).toStringAsFixed(1)}KB → ${outputPath.split('/').last}');
      } else {
        _log('☁️ [Realtime-TTS] ❌ 合成失败 (${sw.elapsedMilliseconds}ms)');
      }
      return result;
    } catch (e) {
      _log('💥 [Realtime-TTS] 异常: $e');
      return null;
    }
  }

  // ─── API Key 说明 ──────────────────────
  ///
  /// API Key 不再由本服务单独管理。
  /// 改为统一由 AppKeysService 在登录时从 app_settings 表加载并内存缓存。
  /// 本服务直接通过 AppKeysService.instance.qwenApiKey 读取。
  ///

  // ─── 内部辅助方法 ─────────────────────────

  /// 将收集到的音频字节写入文件
  String _writeAudioFile(List<int> audioBytes, String outputPath, String format) {
    final file = File(outputPath);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(Uint8List.fromList(audioBytes));
    return outputPath;
  }

  /// 统一日志输出
  void _log(String message) {
    if (kReleaseMode) {
      // ignore: avoid_print
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
