import 'package:flutter/foundation.dart';

/// 服务层统一日志工具
///
/// 所有 Service 共用同一个 Logger，支持 tag 前缀和级别控制。
/// 
/// 使用示例：
/// ```dart
/// final _log = ServiceLogger('TTS');
/// _log.d('调试信息');     // [TTS] 调试信息
/// _log.i('普通日志');     // [TTS] 普通日志  
/// _log.w('警告信息');     // ⚠️ [TTS] 警告信息
/// _log.e('错误信息');     // ❌ [TTS] 错误信息
/// ```
class ServiceLogger {
  /// 日志标签（用于标识来源服务）
  final String tag;
  
  /// 是否启用日志（Release 模式下可关闭）
  static bool _enabled = true;
  
  /// 最小日志级别（默认显示所有）
  static LogLevel _minLevel = LogLevel.debug;

  ServiceLogger(this.tag);

  /// 启用/禁用所有日志输出
  static set enabled(bool value) => _enabled = value;
  
  /// 设置最小日志级别
  static void setMinLevel(LogLevel level) => _minLevel = level;

  /// 调试级别日志（仅 Debug 模式）
  void d(String message) {
    if (_enabled && _minLevel.index <= LogLevel.debug.index && kDebugMode) {
      debugPrint('[$tag] $message');
    }
  }

  /// 信息级别日志
  void i(String message) {
    if (_enabled && _minLevel.index <= LogLevel.info.index) {
      _print(message);
    }
  }

  /// 警告级别日志
  void w(String message) {
    if (_enabled && _minLevel.index <= LogLevel.warning.index) {
      if (kDebugMode) {
        debugPrint('⚠️ [$tag] $message');
      } else {
        print('⚠️ [$tag] $message');
      }
    }
  }

  /// 错误级别日志
  void e(String message, [Object? error, StackTrace? stackTrace]) {
    if (_enabled && _minLevel.index <= LogLevel.error.index) {
      if (kDebugMode) {
        debugPrint('❌ [$tag] $message');
        if (error != null) debugPrint('  Error: $error');
        if (stackTrace != null) debugPrint('  Stack: $stackTrace');
      } else {
        print('❌ [$tag] $message');
        if (error != null) print('  Error: $error');
      }
    }
  }

  /// 截断长文本用于日志显示
  static String truncate(String text, {int maxLen = 50}) {
    if (text.length <= maxLen) return text;
    return '${text.substring(0, maxLen)}...(${text.length})';
  }

  void _print(String message) {
    if (kDebugMode) {
      debugPrint('[$tag] $message');
    } else {
      print('[$tag] $message');
    }
  }
}

/// 日志级别枚举
enum LogLevel {
  /// 调试信息（最详细，仅开发时使用）
  debug,
  /// 一般信息（正常运行日志）
  info,
  /// 警告（可恢复的异常情况）
  warning,
  /// 错误（需要关注的异常）
  error,
}
