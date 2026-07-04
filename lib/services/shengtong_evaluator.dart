import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:vidlang/services/app_keys_service.dart';

/// 声通语音评测服务
///
/// 基于官方 skegn.dart 示例实现，使用 web_socket_channel 连接声通服务进行语音评测。
///
/// 使用示例：
/// ```dart
/// final evaluator = ShengtongEvaluator(
///   appKey: AppKeysService.instance.shengtongAppKey!,
///   secretKey: AppKeysService.instance.shengtongSecretKey!,
/// );
///
/// // 设置回调
/// evaluator.onResult = (result) {
///   print('评测结果: $result');
/// };
///
/// // 开始评测（参考官方示例的 request 格式）
/// final request = jsonEncode({
///   'audio': {'audioType': 'wav', 'sampleRate': 16000},
///   'params': {
///     'userId': 'user123',
///     'coreType': 'sent.eval',
///     'refText': 'Hello world',
///   },
/// });
/// evaluator.start(request, controller);
///
/// // 发送音频数据
/// evaluator.feed(audioData);
///
/// // 停止评测
/// evaluator.stop();
///
/// // 释放资源
/// evaluator.cancel();
/// ```
class ShengtongEvaluator {
  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  StreamSubscription? _streamSubscription;
  String? _coreType;
  String? _request;
  String? _audioType;
  int? _sampleRate;
  String? _userId;

  // 回调
  void Function(Map<String, dynamic>)? onResult;
  void Function(String)? onError;
  void Function(bool)? onConnectionStateChanged;

  final String appKey;
  final String secretKey;
  final String baseUrl;
  final bool useSSL;

  bool _isEvaluating = false;
  bool _isConnected = false;
  final StreamController<String> _messageController = StreamController<String>.broadcast();

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
      throw ArgumentError('appKey 不能为空，请通过 AppKeysService 加载声通配置');
    }
    if (secretKey.isEmpty) {
      throw ArgumentError('secretKey 不能为空，请通过 AppKeysService 加载声通配置');
    }
  }

  /// 构建参数
  /// type: 0 = connect, 1 = start
  /// 参考官方 Python demo
  String _buildParam(int type) {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();

    // connect
    if (type == 0) {
      final connectStr = utf8.encode('$appKey$ts$secretKey');
      final connectSig = sha1.convert(connectStr).toString();

      final connect = json.encode({
        'cmd': 'connect',
        'param': {
          'sdk': {
            'version': 16777472,
            'source': 4,
            'protocol': 1,
          },
          'app': {
            'applicationId': appKey,
            'sig': connectSig,
            'timestamp': ts,
          },
        },
      });

      debugPrint('🎤 [Shengtong] 📤 connect 参数: $connect');
      return connect;
    } else {
      // start
      final startStr = utf8.encode('$appKey$ts$_userId$secretKey');
      final startSig = sha1.convert(startStr).toString();

      final requestsObj = json.decode(_request!) as Map<String, dynamic>;
      final paramsObj = requestsObj['params'] as Map<String, dynamic>;

      final start = json.encode({
        'cmd': 'start',
        'param': {
          'app': {
            'userId': _userId,
            'applicationId': appKey,
            'timestamp': ts,
            'sig': startSig,
          },
          'audio': {
            'audioType': _audioType,
            'channel': 1,
            'sampleBytes': 2,
            'sampleRate': _sampleRate,
          },
          'request': {
            'coreType': paramsObj['coreType'],
            'refText': paramsObj['refText'],
            'tokenId': 'abcd',
          },
        },
      });

      debugPrint('🎤 [Shengtong] 📤 start 参数: $start');
      return start;
    }
  }

  /// 连接 WebSocket
  /// 参考官方 skegn.dart 的 connectWebsocket 方法
  void _connectWebSocket(String coreType, StreamController? controller) {
    final wsUrl = baseUrl.endsWith('/')
        ? '$baseUrl$coreType'
        : '$baseUrl/$coreType';

    debugPrint('🎤 [Shengtong] 🔗 连接 WebSocket: $wsUrl');

    _channel = IOWebSocketChannel.connect(wsUrl);

    _streamSubscription = _channel!.stream.listen(
      (msg) {
        debugPrint('🎤 [Shengtong] 📥 收到消息: $msg');
        _messageController.add(msg is String ? msg : utf8.decode(msg as List<int>));
      },
      onError: (err) {
        debugPrint('🎤 [Shengtong] 💥 WebSocket 错误: $err');
        _messageController.addError(err);
      },
      onDone: () {
        debugPrint('🎤 [Shengtong] 🔌 WebSocket 连接关闭');
      },
      cancelOnError: false,
    );
  }

  /// 处理收到的消息
  void _handleMessage(String message, StreamController? controller) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;

      // 如果有 StreamController，将消息转发出去
      if (controller != null && !controller.isClosed) {
        controller.sink.add(message);
      }

      // 检查是否有错误字段
      if (data['error'] != null) {
        final errorMsg = data['error'].toString();
        final errId = data['errId'];
        debugPrint('🎤 [Shengtong] ❌ 服务端返回错误: errId=$errId, error=$errorMsg');
        onError?.call('[$errId] $errorMsg');
        return;
      }

      final cmd = data['cmd'] as String?;

      if (cmd == null) {
        debugPrint('🎤 [Shengtong] ⚠️ 消息没有 cmd 字段: ${data.keys.toList()}');
        return;
      }

      if (cmd == 'connect') {
        final code = data['code'] as int?;
        debugPrint('🎤 [Shengtong] 📡 connect 响应: code=$code');
        if (code == 0) {
          _isConnected = true;
          onConnectionStateChanged?.call(true);
        } else {
          final errorMsg = data['error'] ?? '连接失败';
          debugPrint('🎤 [Shengtong] ❌ connect 失败: $errorMsg');
          onError?.call(errorMsg.toString());
        }
      } else if (cmd == 'start') {
        final code = data['code'] as int?;
        if (code == 0) {
          _isEvaluating = true;
          debugPrint('🎤 [Shengtong] ✅ start 成功');
        } else {
          final errorMsg = data['error'] ?? '开始评测失败';
          debugPrint('🎤 [Shengtong] ❌ start 失败: $errorMsg');
          onError?.call(errorMsg.toString());
        }
      } else if (cmd == 'eval') {
        final code = data['code'] as int?;
        if (code == 0) {
          final result = data['result'] as Map<String, dynamic>?;
          if (result != null) {
            onResult?.call(result);
          }
        }
      } else if (cmd == 'stop') {
        _isEvaluating = false;
        debugPrint('🎤 [Shengtong] 🏁 评测已停止');
      } else {
        debugPrint('🎤 [Shengtong] ⚠️ 未知 cmd: $cmd');
      }
    } catch (e) {
      debugPrint('🎤 [Shengtong] 💥 消息解析错误: $e');
    }
  }

  /// 公开的消息处理方法（用于测试）
  @visibleForTesting
  void handleMessage(dynamic message) {
    String msgStr;
    try {
      msgStr = message is String
          ? message
          : utf8.decode(message as List<int>);
    } catch (e) {
      debugPrint('🎤 [Shengtong] 💥 消息解码错误: $e');
      return;
    }
    _handleMessage(msgStr, null);
  }

  /// 启动消息消费者
  void _startMessageConsumer(StreamController? controller) {
    _messageController.stream.listen(
      (msg) {
        _handleMessage(msg, controller);
      },
      onError: (err) {
        debugPrint('🎤 [Shengtong] 💥 消息消费者错误: $err');
      },
    );
  }

  /// 启动心跳
  Future<void> _startHeartbeat() async {
    await Future.delayed(const Duration(seconds: 30));
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_channel != null && _isConnected) {
        _channel!.sink.add('{"cmd":"ping"}');
        debugPrint('🎤 [Shengtong] 💓 发送心跳');
      }
    });
  }

  /// 停止心跳
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// 关闭 WebSocket
  /// 参考官方 skegn.dart 的 closeWebSocket 方法
  void closeWebSocket() {
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
      _isEvaluating = false;
    }
  }

  /// 开始评测
  /// 参考官方 skegn.dart 的 start 方法
  ///
  /// [request] 格式：
  /// ```json
  /// {
  ///   "audio": {"audioType": "wav", "sampleRate": 16000},
  ///   "params": {"userId": "xxx", "coreType": "sent.eval", "refText": "Hello world"}
  /// }
  /// ```
  Future<bool> start(String request, {StreamController? controller}) async {
    _request = request;

    final requestsObj = json.decode(request) as Map<String, dynamic>;
    final audioObj = requestsObj['audio'] as Map<String, dynamic>?;
    final paramsObj = requestsObj['params'] as Map<String, dynamic>?;

    if (audioObj == null || paramsObj == null) {
      throw ArgumentError('request 格式错误，必须包含 audio 和 params 字段');
    }

    _audioType = audioObj['audioType'] as String?;
    _sampleRate = audioObj['sampleRate'] as int?;
    _userId = paramsObj['userId'] as String?;

    final coreType = paramsObj['coreType'] as String?;

    if (coreType == null) {
      throw ArgumentError('params 中必须包含 coreType');
    }

    // 如果需要切换 coreType 或首次连接，建立新连接
    if (_coreType == null || _coreType != coreType) {
      if (_channel != null) {
        closeWebSocket();
      }
      _connectWebSocket(coreType, controller);
      _startMessageConsumer(controller);

      // 等待 connect 响应成功（最多 10 秒）
      final connected = await _waitForConnectResponse().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('🎤 [Shengtong] ⏰ 等待 connect 响应超时');
          return false;
        },
      );

      if (connected) {
        _startHeartbeat();
      }

      if (!connected) {
        debugPrint('🎤 [Shengtong] ❌ connect 响应失败');
        return false;
      }
    }

    if (_channel == null) {
      debugPrint('🎤 [Shengtong] ❌ WebSocket 通道未建立');
      return false;
    }

    // 发送 start 命令
    final startParam = _buildParam(1);
    _channel!.sink.add(startParam);
    debugPrint('🎤 [Shengtong] ✅ start 命令已发送');
    return true;
  }

  /// 等待 connect 响应
  Future<bool> _waitForConnectResponse() async {
    final completer = Completer<bool>();

    final subscription = _messageController.stream.listen(
      (msg) {
        try {
          final data = jsonDecode(msg) as Map<String, dynamic>;
          if (data['cmd'] == 'connect') {
            if (data['code'] == 0) {
              if (!completer.isCompleted) {
                completer.complete(true);
              }
            } else {
              if (!completer.isCompleted) {
                completer.complete(false);
              }
            }
          }
        } catch (_) {}
      },
      onError: (_) {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
      cancelOnError: true,
    );

    // 发送 connect 命令
    final connectParam = _buildParam(0);
    _channel!.sink.add(connectParam);
    debugPrint('🎤 [Shengtong] 📤 connect 命令已发送');

    return completer.future.whenComplete(() {
      subscription.cancel();
    });
  }

  /// 发送音频数据
  void feed(dynamic audioData) {
    if (_channel == null || !_isEvaluating) return;

    try {
      if (audioData is Uint8List) {
        _channel!.sink.add(audioData);
      } else if (audioData is List<int>) {
        _channel!.sink.add(Uint8List.fromList(audioData));
      }
    } catch (e) {
      debugPrint('🎤 [Shengtong] 发送音频失败: $e');
      onError?.call(e.toString());
    }
  }

  /// 停止评测
  void stop() {
    if (_channel != null) {
      _channel!.sink.add('{"cmd":"stop"}');
      _isEvaluating = false;
      debugPrint('🎤 [Shengtong] 📤 stop 命令已发送');
    }
  }

  /// 取消并关闭连接
  void cancel() {
    _stopHeartbeat();
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _messageController.close();
    closeWebSocket();
    onConnectionStateChanged?.call(false);
  }

  /// 释放资源（兼容旧接口）
  void dispose() {
    cancel();
  }
}
