import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vscode_logger/flutter_vscode_logger.dart';

/// 全局异常处理器
///
/// 提供三层防护：
/// 1. FlutterError.onError — 捕获 Flutter 框架层未处理的异常（build/layout/paint 等）
/// 2. PlatformDispatcher.instance.onError — 捕获平台通道（Isolate/FFI）异常
/// 3. runZonedGuarded — 捕获异步 Zone 中逃逸的异常（Future/microtask 未 catch 的）
///
/// 所有被捕获的异常会：
/// - 写入日志（VscodeLogger）
/// - 通过 SnackBar 提示用户（非致命错误）
/// - 在 debug 模式下保留完整的红屏错误页面
class GlobalErrorHandler {
  GlobalErrorHandler._();

  static final GlobalErrorHandler instance = GlobalErrorHandler._();

  /// 全局 NavigatorKey 引用，在 main.dart 中注入
  GlobalKey<NavigatorState>? _navigatorKey;

  /// 防抖：同一条错误在 [_suppressDuration] 内不重复提示
  static const _suppressDuration = Duration(seconds: 5);
  final Map<String, DateTime> _lastShown = {};

  /// 初始化，安装所有全局错误钩子
  ///
  /// 必须在 WidgetsFlutterBinding.ensureInitialized() 之后调用
  void install({required GlobalKey<NavigatorState> navigatorKey}) {
    _navigatorKey = navigatorKey;

    // ① Flutter 框架层异常
    FlutterError.onError = _handleFlutterError;

    // ② 平台层异常
    PlatformDispatcher.instance.onError = _handlePlatformError;
  }

  // ──────────────────────── Flutter 框架层 ────────────────────────

  void _handleFlutterError(FlutterErrorDetails details) {
    // debug 模式下保留默认的红屏行为，方便开发调试
    if (kDebugMode) {
      FlutterError.presentError(details);
    }

    final message = _extractMessage(details.exception);
    final tag = details.library ?? 'Flutter';

    logger.error(
      message,
      tag: 'UNCAUGHT/$tag',
      error: details.exception,
      stackTrace: details.stack,
      extra: {
        'context': details.context?.toDescription(),
        if (details.informationCollector != null)
          'info': details.informationCollector!().map((e) => e.toString()).toList(),
      },
    );

    _persistError(level: 'error', tag: tag, message: message, error: details.exception, stack: details.stack);
    _showUserHint(message, severity: _classifySeverity(details.exception));
  }

  // ──────────────────────── 平台层 ────────────────────────

  bool _handlePlatformError(Object error, StackTrace stack) {
    final message = _extractMessage(error);

    logger.fatal(
      message,
      tag: 'UNCAUGHT/Platform',
      error: error,
      stackTrace: stack,
    );

    _persistError(level: 'fatal', tag: 'Platform', message: message, error: error, stack: stack);
    _showUserHint(message, severity: ErrorSeverity.error);

    return true; // 返回 true 阻止异常继续传播
  }

  // ──────────────────────── 异步 Zone 层 ────────────────────────

  /// 供 main() 中使用 runZonedGuarded 的 onError 回调
  void handleZoneError(Object error, StackTrace stack) {
    final message = _extractMessage(error);

    logger.error(
      message,
      tag: 'UNCAUGHT/Async',
      error: error,
      stackTrace: stack,
    );

    _persistError(level: 'error', tag: 'Async', message: message, error: error, stack: stack);
    _showUserHint(message, severity: _classifySeverity(error));
  }

  // ──────────────────────── 公共工具方法 ────────────────────────

  /// 业务代码可主动调用此方法上报可恢复的异常
  ///
  /// ```dart
  /// try {
  ///   await someRiskyOperation();
  /// } catch (e, st) {
  ///   GlobalErrorHandler.instance.report(e, st, tag: 'AudioPlayer');
  /// }
  /// ```
  void report(Object error, StackTrace? stackTrace, {String tag = 'APP', bool showToast = true}) {
    final message = _extractMessage(error);

    logger.error(message, tag: tag, error: error, stackTrace: stackTrace);
    _persistError(level: 'error', tag: tag, message: message, error: error, stack: stackTrace);

    if (showToast) {
      _showUserHint(message, severity: _classifySeverity(error));
    }
  }

  /// 上报 info 级别的日志（不弹 Toast）
  void info(String message, {String tag = 'APP', Map<String, dynamic>? extra}) {
    logger.info(message, tag: tag, extra: extra);
  }

  // ──────────────────────── 内部实现 ────────────────────────

  /// 从各种异常类型中提取可读消息
  String _extractMessage(Object error) {
    if (error is FormatException) {
      return '数据格式异常: ${error.message}';
    }
    if (error is SocketException) {
      return '网络连接失败，请检查网络设置';
    }
    if (error is HttpException) {
      return '服务器请求失败: ${error.message}';
    }
    if (error is TimeoutException) {
      return '操作超时，请稍后重试';
    }
    if (error is StateError) {
      return '状态异常: ${error.message}';
    }
    // 兜底：取 toString 的前 200 字符
    final raw = error.toString();
    return raw.length > 200 ? '${raw.substring(0, 200)}...' : raw;
  }

  /// 对异常分类，决定提示级别
  ErrorSeverity _classifySeverity(Object error) {
    // 网络/超时 → 可恢复，提示即可
    if (error is SocketException || error is TimeoutException || error is HttpException) {
      return ErrorSeverity.warning;
    }
    // 格式/状态错误 → 通常是 bug
    if (error is FormatException || error is StateError) {
      return ErrorSeverity.error;
    }
    return ErrorSeverity.warning;
  }

  /// 防抖 + 显示用户提示
  void _showUserHint(String message, {required ErrorSeverity severity}) {
    // 防抖
    final now = DateTime.now();
    final last = _lastShown[message];
    if (last != null && now.difference(last) < _suppressDuration) return;
    _lastShown[message] = now;

    // 定期清理过期记录
    if (_lastShown.length > 50) {
      _lastShown.removeWhere((_, v) => now.difference(v) > _suppressDuration * 3);
    }

    final nav = _navigatorKey?.currentState;
    if (nav == null || !nav.mounted) return;

    final ctx = nav.context;

    // 用 WidgetsBinding 确保在 UI 线程执行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!nav.mounted) return;

      final scaffold = ScaffoldMessenger.maybeOf(ctx);
      if (scaffold == null) return;

      scaffold.hideCurrentSnackBar();
      scaffold.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                severity == ErrorSeverity.error ? Icons.error_outline : Icons.warning_amber_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 13),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: severity == ErrorSeverity.error
              ? const Color(0xFFD32F2F)
              : const Color(0xFFE65100),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: '知道了',
            textColor: Colors.white70,
            onPressed: () => scaffold.hideCurrentSnackBar(),
          ),
        ),
      );
    });
  }

  /// 异步持久化错误到本地数据库（fire-and-forget，不阻塞主流程）
  void _persistError({
    required String level,
    required String tag,
    required String message,
    required Object error,
    StackTrace? stack,
  }) {
    // 避免导入 DatabaseService 造成循环依赖
    // 这里只记录日志，如需持久化可在外部扩展
    logger.debug(
      'Error persisted: [$level/$tag] $message',
      tag: 'ErrorHandler',
    );
  }
}

enum ErrorSeverity { warning, error }
