import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

import 'package:vidlang/config.dart';

/// 声通语音评测服务
///
/// 通过 WebSocket 连接声通服务进行语音评测，支持单词/句子/段落等多种评测类型。
///
/// 使用示例：
/// ```dart
/// final evaluator = ShengtongEvaluator(
///   appKey: AppConfig.shengtongAppKey,
///   secretKey: AppConfig.shengtongSecretKey,
/// );
///
/// // 连接并开始评测
/// evaluator.connect('en.word.eval');
/// evaluator.onResult = (result) {
///   print('评测结果: $result');
/// };
///
/// // 开始评测
/// evaluator.start(coreType: 'en.word.eval', refText: 'hello', userId: 'user123');
///
/// // 发送音频数据
/// evaluator.feed(audioData);
///
/// // 停止评测
/// evaluator.stop();
///
/// // 释放资源
/// evaluator.dispose();
/// ```
class ShengtongEvaluator {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isEvaluating = false;
  String? _currentCoreType;
  String? _timestamp;

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
  }) : baseUrl = baseUrl ??
            (useSSL
                ? AppConfig.shengtongWssUrl
                : AppConfig.shengtongWsUrl) {
    if (appKey.isEmpty) {
      throw ArgumentError('appKey 不能为空，请在 config.dart 中设置 shengtongAppKey');
    }
    if (secretKey.isEmpty) {
      throw ArgumentError('secretKey 不能为空，请在 config.dart 中设置 shengtongSecretKey');
    }
  }

  /// 生成 connect sig
  /// 算法：appKey + timestamp + secretKey，SHA1 加密后 HEX 编码
  String _generateConnectSig(String timestamp) {
    final input = '$appKey$timestamp$secretKey';
    return sha1.convert(utf8.encode(input)).toString();
  }

  /// 生成 start sig
  /// 算法：appKey + timestamp + userId + secretKey，SHA1 加密后 HEX 编码
  String _generateStartSig(String timestamp, String userId) {
    final input = '$appKey$timestamp$userId$secretKey';
    return sha1.convert(utf8.encode(input)).toString();
  }

  /// 获取当前时间戳（毫秒，13 位）
  String _getTimestamp() {
    if (_timestamp != null && _timestamp!.isNotEmpty) {
      return _timestamp!;
    }
    _timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    return _timestamp!;
  }

  /// 构建 connect 参数
  String _buildConnectParam() {
    final timestamp = _getTimestamp();
    final sig = _generateConnectSig(timestamp);

    return jsonEncode({
      'cmd': 'connect',
      'param': {
        'sdk': {'protocol': 2, 'version': 16777472, 'source': 9},
        'app': {
          'applicationId': appKey,
          'sig': sig,
          'timestamp': timestamp,
        },
      },
    });
  }

  /// 构建 start 参数
  String _buildStartParam({
    required String coreType,
    required String refText,
    required String userId,
    String audioType = 'wav',
    int sampleRate = 16000,
    String? tokenId,
    Map<String, dynamic>? extraParams,
  }) {
    final timestamp = _getTimestamp();
    final sig = _generateStartSig(timestamp, userId);

    final requestParams = <String, dynamic>{
      'coreType': coreType,
      'refText': refText,
      if (tokenId != null) 'tokenId': tokenId,
      if (extraParams != null) ...extraParams,
    };

    return jsonEncode({
      'cmd': 'start',
      'param': {
        'app': {
          'applicationId': appKey,
          'timestamp': timestamp,
          'sig': sig,
          'userId': userId,
        },
        'audio': {
          'sampleBytes': 2,
          'channel': 1,
          'sampleRate': sampleRate,
          'audioType': audioType,
        },
        'request': requestParams,
      },
    });
  }

  /// 处理收到的消息
  void _handleMessage(dynamic message) {
    try {
      final msgStr = message is String ? message : utf8.decode(message as List<int>);
      final data = jsonDecode(msgStr) as Map<String, dynamic>;

      final cmd = data['cmd'] as String?;

      if (cmd == 'connect') {
        final code = data['code'] as int?;
        if (code == 0) {
          _isConnected = true;
          onConnectionStateChanged?.call(true);
        } else {
          final errorMsg = data['error'] ?? '连接失败';
          onError?.call(errorMsg.toString());
        }
      } else if (cmd == 'start') {
        final code = data['code'] as int?;
        if (code == 0) {
          _isEvaluating = true;
        } else {
          final errorMsg = data['error'] ?? '开始评测失败';
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
      }
    } catch (e) {
      print('ShengtongEvaluator 消息解析错误: $e');
    }
  }

  /// 连接声通 WebSocket 服务
  Future<void> connect(String coreType) async {
    if (_isConnected && _currentCoreType == coreType) return;

    dispose();

    _currentCoreType = coreType;
    _timestamp = null;

    try {
      final wsUrl = Uri.parse(baseUrl);
      _channel = IOWebSocketChannel.connect(wsUrl);

      await _channel!.ready;

      _channel!.stream.listen(
        (message) => _handleMessage(message),
        onError: (error) {
          print('ShengtongEvaluator WebSocket 错误: $error');
          onError?.call(error.toString());
          _isConnected = false;
          _isEvaluating = false;
          onConnectionStateChanged?.call(false);
        },
        onDone: () {
          _isConnected = false;
          _isEvaluating = false;
          onConnectionStateChanged?.call(false);
        },
        cancelOnError: false,
      );

      // 发送 connect 命令
      final connectParam = _buildConnectParam();
      _channel!.sink.add(connectParam);

      // 等待连接确认
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      print('ShengtongEvaluator 连接失败: $e');
      onError?.call(e.toString());
      _isConnected = false;
      onConnectionStateChanged?.call(false);
    }
  }

  /// 开始评测
  void start({
    required String coreType,
    required String refText,
    required String userId,
    String audioType = 'wav',
    int sampleRate = 16000,
    String? tokenId,
  }) {
    if (!_isConnected || _currentCoreType != coreType) {
      // 未连接或 coreType 变更，先连接
      connect(coreType).then((_) {
        if (_isConnected) {
          _sendStart(coreType, refText, userId, audioType, sampleRate, tokenId);
        }
      });
      return;
    }

    _sendStart(coreType, refText, userId, audioType, sampleRate, tokenId);
  }

  void _sendStart(
    String coreType,
    String refText,
    String userId,
    String audioType,
    int sampleRate,
    String? tokenId,
  ) {
    final startParam = _buildStartParam(
      coreType: coreType,
      refText: refText,
      userId: userId,
      audioType: audioType,
      sampleRate: sampleRate,
      tokenId: tokenId,
    );
    _channel?.sink.add(startParam);
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
      print('ShengtongEvaluator 发送音频失败: $e');
      onError?.call(e.toString());
    }
  }

  /// 停止评测
  void stop() {
    if (!_isEvaluating) return;

    try {
      _channel?.sink.add('{"cmd":"stop"}');
      _isEvaluating = false;
    } catch (e) {
      print('ShengtongEvaluator 停止评测失败: $e');
    }
  }

  /// 关闭连接并释放资源
  void dispose() {
    try {
      if (_isEvaluating) stop();
      _channel?.sink.close();
      _channel = null;
      _isConnected = false;
      _isEvaluating = false;
      _currentCoreType = null;
      _timestamp = null;
      onConnectionStateChanged?.call(false);
    } catch (e) {
      print('ShengtongEvaluator 释放失败: $e');
    }
  }
}
