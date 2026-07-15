import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:vidlang/providers/subscription_provider.dart';
import 'package:vidlang/services/tts/dashscope_tts_service.dart';
import 'package:vidlang/services/tts/local_tts_service.dart';
import 'package:vidlang/services/settings_service.dart';
import 'package:vidlang/services/utils/service_logger.dart';

/// TTS 统一结果
class TtsResult {
  final String audioPath;
  final bool success;
  final String? error;
  final String? format;
  /// 是否来自缓存
  final bool fromCache;

  const TtsResult({
    required this.audioPath,
    required this.success,
    this.error,
    this.format,
    this.fromCache = false,
  });

  factory TtsResult.error(String error, {String? format}) => TtsResult(audioPath: '', success: false, error: error, format: format);
}

/// 统一 TTS 服务
///
/// 分流策略（符合 docs/modules/billing-redesign.md §TTS 双路径）：
/// - 免费模式 → 原生系统 TTS（iOS AVSpeechSynthesizer / Android TTS），无需 AI 模型
/// - 收费模式 → DashScope HTTP SSE 直连（阿里云 qwen3-tts-flash）
///
/// 性能优化：
/// - 持久化磁盘缓存（Documents/tts_cache/，基于文本 SHA256 hash 文件名）
/// - 缓存使用 LRU 策略，最大条数由 SettingsService.ttsCacheSize 控制（默认 20）
/// - 支持预加载（prefetch）提前合成下一句
class UnifiedTtsService {
  static UnifiedTtsService? _instance;
  static UnifiedTtsService get instance => _instance ??= UnifiedTtsService._();
  UnifiedTtsService._();

  /// 原生 TTS 引擎（免费模式使用）
  final LocalTtsService _nativeTts = LocalTtsService.instance;

  /// 内存索引：cacheKey → (audioPath, format, lastAccessAt)
  static final Map<String, _CachedTtsMeta> _cacheIndex = {};

  /// 缓存目录（延迟初始化）
  Directory? _cacheDir;

  /// 是否已初始化缓存目录
  bool _cacheDirReady = false;

  /// 是否已完成首次索引重建（避免每次都扫描）
  bool _indexRebuilt = false;

  // ─── 公开 API ─────────────────────────────

  /// 合成语音
  Future<TtsResult> synthesize({
    required String text,
    required SubscriptionMode mode,
    void Function(String word, int startOffset, int endOffset)? onWord,
  }) async {
    final modeLabel = mode == SubscriptionMode.premium ? 'premium(云端)' : 'free(原生)';
    _log.i('🔊 [TTS] synthesize 开始 | mode=$modeLabel | text="${ServiceLogger.truncate(text, maxLen:50)}"');

    if (mode == SubscriptionMode.free) {
      return await _synthesizeLocal(text: text, onWord: onWord);
    } else {
      return await _synthesizeCloud(text: text);
    }
  }

  /// 预加载云端 TTS（不阻塞调用方）
  Future<void> prefetch({
    required String text,
    required SubscriptionMode mode,
  }) async {
    if (mode != SubscriptionMode.premium) return;

    final cacheKey = _computeHash(text);
    if (_cacheIndex.containsKey(cacheKey)) return; // 已缓存

    _synthesizeCloud(text: text).then((result) {
      if (result.success) {
        _log.i('🔊 [TTS] 预加载成功: "${ServiceLogger.truncate(text, maxLen:30)}"');
      }
    }).catchError((e) {
      _log.i('🔊 [TTS] 预加载失败: $e');
    });
  }

  /// 批量预加载多个文本的 TTS
  Future<void> prefetchBatch({
    required List<String> texts,
    required SubscriptionMode mode,
  }) async {
    for (final text in texts) {
      await prefetch(text: text, mode: mode);
    }
  }

  /// 清除所有 TTS 缓存（删除磁盘文件 + 清空内存索引）
  Future<void> clearCache() async {
    final dir = _cacheDir;
    if (dir != null && await dir.exists()) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
    _cacheDir = null;
    _cacheDirReady = false;
    _indexRebuilt = false;
    _cacheIndex.clear();
    _log.i('🔊 [TTS] 缓存已清除');
  }

  /// 获取当前缓存统计信息
  Future<TtsCacheStats> getCacheStats() async {
    final dir = await _ensureCacheDir();
    if (!await dir.exists()) return TtsCacheStats(count: 0, totalSizeKB: 0);

    int count = 0;
    int totalSize = 0;
    await for (final entity in dir.list()) {
      if (entity is File && p.extension(entity.path) == '.mp3') {
        count++;
        totalSize += await entity.length();
      }
    }
    return TtsCacheStats(count: count, totalSizeKB: totalSize ~/ 1024);
  }

  // ─── 本地 TTS ─────────────────────────────

  Future<TtsResult> _synthesizeLocal({
    required String text,
    void Function(String word, int startOffset, int endOffset)? onWord,
  }) async {
    try {
      if (!_nativeTts.isInitialized) {
        await _nativeTts.initialize();
      }

      await _nativeTts.setLanguage('en-US');

      // 优先 synthesizeToFile → 文件播放（可控、可缓存）
      final audioPath = await _nativeTts.synthesizeToFile(text: text, outputPath: '');
      if (audioPath != null && await File(audioPath).exists() && await File(audioPath).length() > 0) {
        _log.i('🔊 [TTS] ✅ 本地合成成功: ${File(audioPath).length()} bytes');
        return TtsResult(audioPath: audioPath, success: true, format: 'm4a');
      }

      // 文件合成失败 → 直接 speak 播放（iOS AVSpeechSynthesizer 不可靠时的兜底）
      _log.i('🔊 [TTS] synthesizeToFile 未生成文件，使用 speak 直接播放');
      await _nativeTts.synthesizeToAudio(
        text: text,
        onWord: onWord,
      );
      return TtsResult(audioPath: '', success: true, format: 'direct');
    } catch (e) {
      _log.i('🔊 [TTS] 原生 TTS 异常: $e');
      return TtsResult.error('原生 TTS 失败: $e');
    }
  }

  // ─── 云端 TTS ─────────────────────────────

  /// 云端 TTS（DashScope HTTP SSE 直连）
  ///
  /// 1. 先查本地持久化缓存 → 命中直接返回（毫秒级）
  /// 2. 未命中则调用 DashScope API → 写入持久化缓存
  Future<TtsResult> _synthesizeCloud({required String text}) async {
    final cacheKey = _computeHash(text);
    final sw = Stopwatch()..start();

    // ══════════════════════════════════════
    // ① 检查内存索引（O(1) 查找）
    // ══════════════════════════════════════
    final cached = _cacheIndex[cacheKey];
    if (cached != null) {
      final file = File(cached.audioPath);
      if (await file.exists()) {
        // 更新访问时间（LRU）
        _cacheIndex[cacheKey] = cached.copyWith(lastAccessAt: DateTime.now());
        sw.stop();
        _log.i('🔊 [TTS] ✅ 缓存命中 [memory] (${sw.elapsedMilliseconds}ms): "${ServiceLogger.truncate(text, maxLen:30)}"');
        return TtsResult(audioPath: cached.audioPath, success: true, format: cached.format, fromCache: true);
      } else {
        // 文件被外部删除，清理索引
        _cacheIndex.remove(cacheKey);
        _log.i('🔊 [TTS] 缓存文件不存在，移除索引: ${p.basename(cached.audioPath)}');
      }
    }

    // ══════════════════════════════════════
    // ② 确保缓存目录就绪（仅首次调用时扫描磁盘）
    // ══════════════════════════════════════
    await _ensureCacheDir();

    // 再次检查（可能在 _rebuildIndex 中从磁盘恢复了索引）
    final cachedAgain = _cacheIndex[cacheKey];
    if (cachedAgain != null) {
      final file = File(cachedAgain.audioPath);
      if (await file.exists()) {
        _cacheIndex[cacheKey] = cachedAgain.copyWith(lastAccessAt: DateTime.now());
        sw.stop();
        _log.i('🔊 [TTS] ✅ 缓存命中 [disk→index] (${sw.elapsedMilliseconds}ms): "${ServiceLogger.truncate(text, maxLen:30)}"');
        return TtsResult(audioPath: cachedAgain.audioPath, success: true, format: cachedAgain.format, fromCache: true);
      }
    }

    // ══════════════════════════════════════
    // ③ 直连 DashScope WebSocket TTS（流式，首包延迟低）
    // ══════════════════════════════════════
    _log.i('🔊 [TTS] ⏳ 缓存未命中，直连 DashScope WebSocket... (${sw.elapsedMilliseconds}ms 准备阶段)');

    try {
      final wsSw = Stopwatch()..start();

      // 构建输出路径（使用缓存目录 + hash 文件名）
      final cacheDir = await _ensureCacheDir();
      final wsOutputPath = p.join(cacheDir.path, '$cacheKey.mp3');

      final wsResult = await DashScopeTtsService.instance.synthesize(
        text: text,
        outputPath: wsOutputPath,
      );

      wsSw.stop();

      if (wsResult != null && await File(wsResult).exists()) {
        // 更新内存索引
        _cacheIndex[cacheKey] = _CachedTtsMeta(
          audioPath: wsResult,
          format: 'mp3',
          lastAccessAt: DateTime.now(),
        );

        sw.stop();
        _log.i('🔊 [TTS] ✅ WebSocket 直连成功 (总${sw.elapsedMilliseconds}ms, WS=${wsSw.elapsedMilliseconds}ms): "${ServiceLogger.truncate(text, maxLen:30)}" → ${p.basename(wsResult)}');
        return TtsResult(audioPath: wsResult, success: true, format: 'mp3', fromCache: false);
      }

      sw.stop();
      _log.i('🔊 [TTS] ❌ WebSocket 返回空结果 (${wsSw.elapsedMilliseconds}ms)');
      return TtsResult.error('DashScope TTS 合成失败：返回空音频');
    } catch (e, stack) {
      sw.stop();
      _log.i('🔊 [TTS] 💥 WebSocket 直连异常 (${sw.elapsedMilliseconds}ms): $e\n$stack');
      return TtsResult.error('DashScope TTS 失败: $e');
    }
  }

  // ─── 缓存管理 ─────────────────────────────

  /// 计算文本的 SHA256 hash 作为缓存 key（同时作为文件名）
  String _computeHash(String text) {
    final bytes = utf8.encode(text.trim().toLowerCase());
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// 确保缓存目录存在
  ///
  /// 仅在首次调用时扫描磁盘重建索引，后续调用直接返回。
  Future<Directory> _ensureCacheDir() async {
    if (_cacheDirReady && _cacheDir != null) return _cacheDir!;

    final initSw = Stopwatch()..start();

    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'tts_cache'));

    if (!await dir.exists()) {
      await dir.create(recursive: true);
      _log.i('🔊 [TTS] 创建缓存目录: ${dir.path}');
    }

    _cacheDir = dir;
    _cacheDirReady = true;

    // 仅首次扫描磁盘
    if (!_indexRebuilt) {
      await _rebuildIndex();
      _indexRebuilt = true;
    }

    initSw.stop();
    if (initSw.elapsedMilliseconds > 50) {
      _log.i('🔊 [TTS] ⚠️ _ensureCacheDir 耗时较长: ${initSw.elapsedMilliseconds}ms');
    }

    return dir;
  }

  /// 扫描缓存目录，重建内存索引
  Future<void> _rebuildIndex() async {
    final dir = _cacheDir;
    if (dir == null || !await dir.exists()) return;

    final sw = Stopwatch()..start();
    int foundCount = 0;

    await for (final entity in dir.list()) {
      if (entity is File) {
        final name = p.basenameWithoutExtension(entity.path);
        // 文件名格式: {sha256_hash}.mp3
        if (name.length == 64) { // SHA256 hex length
          final ext = p.extension(entity.path).replaceFirst('.', '');
          _cacheIndex[name] = _CachedTtsMeta(
            audioPath: entity.path,
            format: ext.isEmpty ? 'mp3' : ext,
            lastAccessAt: await entity.lastModified(),
          );
          foundCount++;
        }
      }
    }

    sw.stop();
    _log.i('🔊 [TTS] 📂 索引重建完成: 找到 $foundCount 条缓存 (${sw.elapsedMilliseconds}ms), 内存索引共 ${_cacheIndex.length} 条');

    // 如果超出了用户设置的最大缓存数，执行淘汰
    await _evictIfNeeded();
  }

  /// LRU 淘汰：当缓存数量超过用户设置的上限时，删除最旧的条目
  Future<void> _evictIfNeeded() async {
    final maxCacheSize = await _getMaxCacheSize();
    int evicted = 0;
    while (_cacheIndex.length >= maxCacheSize) {
      String? oldestKey;
      DateTime? oldestTime;
      _cacheIndex.forEach((key, meta) {
        if (oldestTime == null || meta.lastAccessAt.isBefore(oldestTime!)) {
          oldestKey = key;
          oldestTime = meta.lastAccessAt;
        }
      });

      if (oldestKey == null) break;

      final removed = _cacheIndex.remove(oldestKey);
      if (removed != null) {
        try {
          await File(removed.audioPath).delete();
          evicted++;
        } catch (_) {}
      }
    }
    if (evicted > 0) {
      _log.i('🔊 [TTS] LRU 淘汰了 $evicted 条旧缓存');
    }
  }

  /// 从设置服务读取最大缓存条数
  Future<int> _getMaxCacheSize() async {
    try {
      return await SettingsService.getTtsCacheSize();
    } catch (_) {
      return 20; // 默认值
    }
  }

  /// 统一日志输出
  static final _log = ServiceLogger('TTS');
}

/// 缓存的 TTS 元数据（内存索引）
class _CachedTtsMeta {
  final String audioPath;
  final String format;
  final DateTime lastAccessAt;

  const _CachedTtsMeta({
    required this.audioPath,
    required this.format,
    required this.lastAccessAt,
  });

  _CachedTtsMeta copyWith({String? audioPath, String? format, DateTime? lastAccessAt}) {
    return _CachedTtsMeta(
      audioPath: audioPath ?? this.audioPath,
      format: format ?? this.format,
      lastAccessAt: lastAccessAt ?? this.lastAccessAt,
    );
  }
}

/// TTS 缓存统计信息
class TtsCacheStats {
  final int count;
  final int totalSizeKB;

  const TtsCacheStats({required this.count, required this.totalSizeKB});

  String get sizeLabel {
    if (totalSizeKB < 1024) return '${totalSizeKB}KB';
    return '${(totalSizeKB / 1024).toStringAsFixed(1)}MB';
  }
}
