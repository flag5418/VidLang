import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'package:vidlang/services/app_keys_service.dart';

/// 声通语音评测服务 - 使用 dart:io 原生 WebSocket 手动实现
///
/// 参考 Python websocket-client 的实现方式，手动处理 WebSocket 握手和通信。
class ShengtongEvaluator {
  Socket? _socket;
  bool _isConnected = false;
  bool _isEvaluating = false;
  String? _currentCoreType;

  // 回调
  void Function(Map<String, dynamic>)? onResult;
  void Function(String)? onError;
  void Function(bool)? onConnectionStateChanged;

  final String appKey;
  final String secretKey;
  final String baseUrl;
  final bool useSSL;

  ShengtongEvaluator({
    required this.appKey,
    required this.secretKey,
    String? baseUrl,
    this.useSSL = false,
  }) : baseUrl =
           baseUrl ??
           (useSSL
               ? AppKeysService.shengtongWssUrl
               : AppKeysService.shengtongWsUrl) {
    if (appKey.isEmpty) {
      throw ArgumentError('appKey 不能为空');
    }
    if (secretKey.isEmpty) {
      throw ArgumentError('secretKey 不能为空');
    }
  }

  /// 生成 connect sig
  String _generateConnectSig(String timestamp) {
    final input = '$appKey$timestamp$secretKey';
    return sha1.convert(utf8.encode(input)).toString();
  }

  /// 生成 start sig
  String _generateStartSig(String timestamp, String userId) {
    final input = '$appKey$timestamp$userId$secretKey';
    return sha1.convert(utf8.encode(input)).toString();
  }

  /// 手动执行 WebSocket 握手
  Future<void> _handshake(String coreType) async {
    final uri = Uri.parse(baseUrl);
    final host = uri.host;
    final port = uri.port == 0 ? (useSSL ? 443 : 80) : uri.port;
    final path = '/$coreType';

    debugPrint('🎤 [Shengtong] 🔗 手动握手: $host:$port$path');

    // 建立 TCP 连接
    _socket = await Socket.connect(host, port)
        .timeout(const Duration(seconds: 10));
    debugPrint('🎤 [Shengtong] ✅ TCP 连接已建立');

    // 如果是 WSS，需要 SSL 握手
    if (useSSL) {
      _socket = await SecureSocket.secure(_socket!, host: host);
      debugPrint('🎤 [Shengtong] ✅ SSL 握手完成');
    }

    // 生成 WebSocket key
    final key = base64.encode(List<int>.generate(16, (_) => Random().nextInt(256)));

    // 发送 HTTP Upgrade 请求
    final request = 'GET $path HTTP/1.1\r\n'
        'Host: $host:$port\r\n'
        'Upgrade: websocket\r\n'
        'Connection: Upgrade\r\n'
        'Sec-WebSocket-Key: $key\r\n'
        'Sec-WebSocket-Version: 13\r\n'
        'Origin: https://$host\r\n'
        '\r\n';

    _socket!.write(request);
    await _socket!.flush();
    debugPrint('🎤 [Shengtong] 📤 WebSocket 握手请求已发送');

    // 读取 HTTP 响应
    final response = await _readHttpResponse();
    debugPrint('🎤 [Shengtong] 📥 握手响应: $response');

    if (!response.contains('101')) {
      throw Exception('WebSocket 握手失败: $response');
    }

    debugPrint('🎤 [Shengtong] ✅ WebSocket 握手成功');

    // 启动帧读取循环
    _startFrameReader();
  }

  /// 读取 HTTP 响应头
  Future<String> _readHttpResponse() async {
    final data = <int>[];
    final completer = Completer<String>();

    _socket!.listen(
      (bytes) {
        for (final b in bytes) {
          data.add(b);
          if (data.length >= 4) {
            final last4 = data.sublist(data.length - 4);
            if (last4[0] == 13 && last4[1] == 10 && last4[2] == 13 && last4[3] == 10) {
              if (!completer.isCompleted) {
                completer.complete(utf8.decode(data));
              }
              return;
            }
          }
        }
      },
      onError: (err) {
        if (!completer.isCompleted) {
          completer.completeError(err);
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete(utf8.decode(data));
        }
      },
      cancelOnError: true,
    );

    return completer.future;
  }

  /// 启动帧读取循环
  void _startFrameReader() {
    _socket!.listen(
      (data) {
        _handleFrame(data);
      },
      onError: (err) {
        debugPrint('🎤 [Shengtong] 💥 Socket 错误: $err');
        onError?.call(err.toString());
      },
      onDone: () {
        debugPrint('🎤 [Shengtong] 🔌 Socket 连接关闭');
        _isConnected = false;
        _isEvaluating = false;
        onConnectionStateChanged?.call(false);
      },
    );
  }

  /// 处理 WebSocket 帧
  void _handleFrame(Uint8List data) {
    // 简化的文本帧解析
    if (data.isEmpty) return;

    final masked = (data[1] & 0x80) != 0;
    var payloadLen = data[1] & 0x7F;
    var offset = 2;

    if (payloadLen == 126) {
      payloadLen = (data[2] << 8) | data[3];
      offset = 4;
    } else if (payloadLen == 127) {
      // 不处理超长帧
      return;
    }

    if (masked) {
      offset += 4; // 跳过 mask key
    }

    if (offset + payloadLen <= data.length) {
      final payload = data.sublist(offset, offset + payloadLen);
      final text = utf8.decode(payload);
      debugPrint('🎤 [Shengtong] 📥 收到文本: $text');
      _handleMessage(text);
    }
  }

  /// 发送文本帧
  void _sendTextFrame(String text) {
    if (_socket == null) return;

    final payload = utf8.encode(text);
    final frame = <int>[];

    // FIN=1, opcode=1 (text)
    frame.add(0x81);

    // 掩码位 + 长度
    if (payload.length < 126) {
      frame.add(0x80 | payload.length);
    } else if (payload.length < 65536) {
      frame.add(0x80 | 126);
      frame.add((payload.length >> 8) & 0xFF);
      frame.add(payload.length & 0xFF);
    } else {
      return; // 不处理超长帧
    }

    // 生成 mask key
    final maskKey = List<int>.generate(4, (_) => Random().nextInt(256));
    frame.addAll(maskKey);

    // 掩码 payload
    for (var i = 0; i < payload.length; i++) {
      frame.add(payload[i] ^ maskKey[i % 4]);
    }

    _socket!.add(Uint8List.fromList(frame));
    _socket!.flush();
  }

  /// 处理收到的消息
  void _handleMessage(String message) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;

      if (data['error'] != null) {
        final errorMsg = data['error'].toString();
        final errId = data['errId'];
        debugPrint('🎤 [Shengtong] ❌ 服务端错误: errId=$errId, error=$errorMsg');
        onError?.call('[$errId] $errorMsg');
        return;
      }

      final cmd = data['cmd'] as String?;
      if (cmd == null) return;

      if (cmd == 'connect') {
        final code = data['code'] as int?;
        if (code == 0) {
          _isConnected = true;
          onConnectionStateChanged?.call(true);
        } else {
          onError?.call(data['error']?.toString() ?? '连接失败');
        }
      } else if (cmd == 'start') {
        if (data['code'] == 0) {
          _isEvaluating = true;
        }
      } else if (cmd == 'eval') {
        if (data['code'] == 0 && data['result'] != null) {
          onResult?.call(data['result'] as Map<String, dynamic>);
        }
      } else if (cmd == 'stop') {
        _isEvaluating = false;
      }
    } catch (e) {
      debugPrint('🎤 [Shengtong] 💥 消息解析错误: $e');
    }
  }

  /// 连接并开始评测
  Future<void> start(String request) async {
    final requestsObj = json.decode(request) as Map<String, dynamic>;
    final paramsObj = requestsObj['params'] as Map<String, dynamic>;
    final coreType = paramsObj['coreType'] as String;
    final refText = paramsObj['refText'] as String;
    final userId = paramsObj['userId'] as String;
    final audioType = (requestsObj['audio'] as Map<String, dynamic>)['audioType'] as String;
    final sampleRate = (requestsObj['audio'] as Map<String, dynamic>)['sampleRate'] as int;

    // 如果未连接或 coreType 变更，重新握手
    if (_socket == null || _currentCoreType != coreType) {
      _socket?.close();
      _socket = null;
      await _handshake(coreType);
      _currentCoreType = coreType;

      // 等待 connect 响应
      var waited = 0;
      while (!_isConnected && waited < 5000) {
        await Future.delayed(const Duration(milliseconds: 100));
        waited += 100;
      }
    }

    if (!_isConnected) {
      throw StateError('WebSocket 未连接');
    }

    // 发送 connect 命令
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final connectSig = _generateConnectSig(timestamp);
    final connectParam = jsonEncode({
      'cmd': 'connect',
      'param': {
        'sdk': {'protocol': 2, 'version': 16777472, 'source': 9},
        'app': {
          'applicationId': appKey,
          'sig': connectSig,
          'timestamp': timestamp,
        },
      },
    });
    _sendTextFrame(connectParam);
    debugPrint('🎤 [Shengtong] ✅ connect 命令已发送');

    // 等待 connect 响应
    await Future.delayed(const Duration(milliseconds: 500));

    // 发送 start 命令
    final startTimestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final startSig = _generateStartSig(startTimestamp, userId);
    final startParam = jsonEncode({
      'cmd': 'start',
      'param': {
        'app': {
          'applicationId': appKey,
          'timestamp': startTimestamp,
          'sig': startSig,
          'userId': userId,
        },
        'audio': {
          'sampleBytes': 2,
          'channel': 1,
          'sampleRate': sampleRate,
          'audioType': audioType,
        },
        'request': {
          'coreType': coreType,
          'refText': refText,
          'tokenId': 'abcd',
        },
      },
    });
    _sendTextFrame(startParam);
    debugPrint('🎤 [Shengtong] ✅ start 命令已发送');
  }

  /// 发送音频数据
  void feed(Uint8List audioData) {
    if (_socket == null || !_isEvaluating) return;
    _sendTextFrame(utf8.decode(audioData));
  }

  /// 停止评测
  void stop() {
    if (_socket == null) return;
    _sendTextFrame('{"cmd":"stop"}');
    _isEvaluating = false;
  }

  /// 释放资源
  void dispose() {
    _socket?.close();
    _socket = null;
    _isConnected = false;
    _isEvaluating = false;
    _currentCoreType = null;
    onConnectionStateChanged?.call(false);
  }
}
