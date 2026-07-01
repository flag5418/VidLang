import 'dart:convert';

import 'package:vidlang/models/config.dart';
import 'package:vidlang/models/playback_settings.dart';
import 'package:vidlang/models/video_folder.dart';
import 'package:vidlang/services/database_service.dart';

/// 统一用户设置服务
///
/// 所有设置都存储到 config 表，并按 user_code 隔离，确保多用户环境下设置独立。
/// 提供统一的读写接口，支持多种数据类型（布尔、整数、浮点数、字符串、JSON）。

/// 全局与视频集播放设置读写
class SettingsService {
  SettingsService._();

  static const String categoryPlayback = 'playback';
  static const String categoryPlayer = 'player';
  static const String keySkipOpening = 'skip_opening_enabled';
  static const String keySkipOpeningSeconds = 'skip_opening_seconds';
  static const String keySkipEnding = 'skip_ending_enabled';
  static const String keySkipEndingSeconds = 'skip_ending_seconds';
  static const String keyThumbnailSeconds = 'thumbnail_time_seconds';
  static const String defaultGroupName = '未分组';

  static const String keyPlayerPlaybackSpeed = 'playback_speed';
  static const String keyPlayerSubtitleVisible = 'subtitle_visible';
  static const String keyPlayerTranslateVisible = 'translate_visible';
  static const String keyPlayerSingleSentencePause = 'single_sentence_pause';
  static const String keyPlayerLoopingMode = 'looping_mode';
  static const String keyPlayerShutdownTimerType = 'shutdown_timer_type';
  static const String keyPlayerShutdownTimerSeconds = 'shutdown_timer_seconds';
  static const String keyPlayerShutdownEpisodeCount = 'shutdown_episode_count';
  static const String keyPlayerSubtitleFontSize = 'subtitle_font_size';
  static const String keyAudioOriginalVolumePure = 'audio_original_volume_pure';
  static const String keyAudioOriginalVolumeMusic = 'audio_original_volume_music';
  static const String keyAudioPronunciationVisible = 'audio_pronunciation_visible';

  static const String categoryWifi = 'wifi';
  static const String keyWifiPort = 'port';

  static const PlaybackSettings _defaults = PlaybackSettings(
    skipOpening: false,
    skipOpeningDuration: 0,
    skipEnding: false,
    skipEndingDuration: 0,
    thumbnailTime: 15,
  );

  static Future<PlaybackSettings> getGlobalPlaybackSettings() async {
    final opening = await _getBool(keySkipOpening) ?? _defaults.skipOpening;
    final openingSec =
        await _getInt(keySkipOpeningSeconds) ?? _defaults.skipOpeningDuration;
    final ending = await _getBool(keySkipEnding) ?? _defaults.skipEnding;
    final endingSec =
        await _getInt(keySkipEndingSeconds) ?? _defaults.skipEndingDuration;
    final thumb =
        await _getInt(keyThumbnailSeconds) ?? _defaults.thumbnailTime;
    return PlaybackSettings(
      skipOpening: opening,
      skipOpeningDuration: openingSec,
      skipEnding: ending,
      skipEndingDuration: endingSec,
      thumbnailTime: thumb,
    );
  }

  static Future<void> saveGlobalPlaybackSettings(PlaybackSettings s) async {
    await _setBool(keySkipOpening, s.skipOpening);
    await _setInt(keySkipOpeningSeconds, s.skipOpeningDuration);
    await _setBool(keySkipEnding, s.skipEnding);
    await _setInt(keySkipEndingSeconds, s.skipEndingDuration);
    await _setInt(keyThumbnailSeconds, s.thumbnailTime);
  }

  /// 视频集设置：直接读文件夹字段；新建时从全局拷贝
  static Future<PlaybackSettings> getFolderPlaybackSettings(
    VideoFolder folder,
  ) async {
    return PlaybackSettings.fromFolder(folder);
  }

  static Future<PlaybackSettings> resolveForFolder(VideoFolder folder) async {
    return getFolderPlaybackSettings(folder);
  }

  static Future<void> applyGlobalDefaultsToFolder(VideoFolder folder) async {
    final g = await getGlobalPlaybackSettings();
    folder.skipOpening = g.skipOpening;
    folder.skipOpeningDuration = g.skipOpeningDuration;
    folder.skipEnding = g.skipEnding;
    folder.skipEndingDuration = g.skipEndingDuration;
    folder.thumbnailTime = g.thumbnailTime;
  }

  /// 二级结构：分组（parent_code 为空）
  static bool isGroupFolder(VideoFolder f) => f.parentCode == null || f.parentCode!.isEmpty;

  /// 叶子视频集（可挂视频，parent_code 非空）
  static bool isLeafVideoSet(VideoFolder f) =>
      f.parentCode != null && f.parentCode!.isNotEmpty;

  /// 确保存在默认分组，返回其 code
  static Future<String> ensureDefaultGroupCode() async {
    final existing = await DatabaseService.findByCondition(
      () => VideoFolder(),
      where: 'name = ? AND (parent_code IS NULL OR parent_code = \'\') AND is_deleted = 0',
      whereArgs: [defaultGroupName],
      limit: 1,
    );
    if (existing.isNotEmpty && existing.first.code != null) {
      return existing.first.code!;
    }
    final group = VideoFolder(
      name: defaultGroupName,
      type: VideoFolderType.virtual,
    );
    await DatabaseService.insert(group);
    return group.code!;
  }

  static Future<bool?> _getBool(String key) async {
    final row = await _findConfig(categoryPlayback, key);
    if (row == null || row.value == null) return null;
    return row.value == 'true' || row.value == '1';
  }

  static Future<int?> _getInt(String key) async {
    final row = await _findConfig(categoryPlayback, key);
    if (row == null || row.value == null) return null;
    return int.tryParse(row.value!);
  }

  /// 查找配置项（按当前用户隔离）
  static Future<Config?> _findConfig(String category, String key) async {
    final userCode = await DatabaseService.getCurrentUserCode();
    final list = await DatabaseService.findByCondition(
      () => Config(),
      where: 'category = ? AND key = ? AND is_deleted = 0${userCode != null ? ' AND user_code = ?' : ''}',
      whereArgs: userCode != null ? [category, key, userCode] : [category, key],
      limit: 1,
    );
    return list.isNotEmpty ? list.first : null;
  }

  static Future<void> _setBool(String key, bool value) async {
    await _upsertConfig(categoryPlayback, key, ValueType.boolean, value ? 'true' : 'false');
  }

  static Future<void> _setInt(String key, int value) async {
    await _upsertConfig(categoryPlayback, key, ValueType.number, value.toString());
  }

  /// 插入或更新配置项（按当前用户隔离）
  static Future<void> _upsertConfig(
    String category,
    String key,
    ValueType type,
    String value,
  ) async {
    final existing = await _findConfig(category, key);
    if (existing != null) {
      existing.value = value;
      existing.valueType = type;
      await DatabaseService.update(existing);
      return;
    }
    final userCode = await DatabaseService.getCurrentUserCode();
    final config = Config(
      category: category,
      key: key,
      valueType: type,
      value: value,
    )..userCode = userCode; // 设置当前用户 code，实现多用户隔离
    await DatabaseService.insert(config);
  }

  // ==================== 订阅/计费模式设置 ====================

  static const String categorySubscription = 'subscription';
  static const String keySubscriptionMode = 'subscription_mode';

  /// 获取订阅模式（免费/付费）
  static Future<String> getSubscriptionMode() async {
    final row = await _findConfig(categorySubscription, keySubscriptionMode);
    return row?.value ?? 'free';
  }

  /// 设置订阅模式（免费/付费）
  static Future<void> setSubscriptionMode(String mode) async {
    await _upsertConfig(categorySubscription, keySubscriptionMode, ValueType.string, mode);
  }

  // ==================== 外观/主题设置 ====================

  static const String categoryAppearance = 'appearance';
  static const String keyThemeMode = 'theme_mode';

  /// 获取主题模式（light/dark/system）
  static Future<String> getThemeMode() async {
    final row = await _findConfig(categoryAppearance, keyThemeMode);
    return row?.value ?? 'system';
  }

  /// 设置主题模式
  static Future<void> setThemeMode(String mode) async {
    await _upsertConfig(categoryAppearance, keyThemeMode, ValueType.string, mode);
  }

  // ==================== 学习难度设置 ====================

  static const String categoryLearning = 'learning';
  static const String keyDifficultyLevel = 'difficulty_level';

  /// 获取学习难度等级
  static Future<String> getDifficultyLevel() async {
    final row = await _findConfig(categoryLearning, keyDifficultyLevel);
    return row?.value ?? 'intermediate';
  }

  /// 设置学习难度等级
  static Future<void> setDifficultyLevel(String level) async {
    await _upsertConfig(categoryLearning, keyDifficultyLevel, ValueType.string, level);
  }

  static Future<double> getPlayerPlaybackSpeed() async {
    final row = await _findConfig(categoryPlayer, keyPlayerPlaybackSpeed);
    final v = row?.value == null ? null : double.tryParse(row!.value!);
    return (v ?? 1.0).clamp(0.5, 2.0);
  }

  static Future<void> setPlayerPlaybackSpeed(double speed) async {
    final v = speed.clamp(0.5, 2.0);
    await _upsertConfig(categoryPlayer, keyPlayerPlaybackSpeed, ValueType.number, v.toString());
  }

  static Future<bool> getPlayerSubtitleVisible() async {
    final row = await _findConfig(categoryPlayer, keyPlayerSubtitleVisible);
    final v = row?.value;
    if (v == null) return true;
    return v == 'true' || v == '1';
  }

  static Future<void> setPlayerSubtitleVisible(bool value) async {
    await _upsertConfig(categoryPlayer, keyPlayerSubtitleVisible, ValueType.boolean, value ? 'true' : 'false');
  }

  static Future<bool> getPlayerTranslateVisible() async {
    final row = await _findConfig(categoryPlayer, keyPlayerTranslateVisible);
    final v = row?.value;
    if (v == null) return true;
    return v == 'true' || v == '1';
  }

  static Future<void> setPlayerTranslateVisible(bool value) async {
    await _upsertConfig(categoryPlayer, keyPlayerTranslateVisible, ValueType.boolean, value ? 'true' : 'false');
  }

  static Future<bool> getPlayerSingleSentencePause() async {
    final row = await _findConfig(categoryPlayer, keyPlayerSingleSentencePause);
    final v = row?.value;
    if (v == null) return false;
    return v == 'true' || v == '1';
  }

  static Future<void> setPlayerSingleSentencePause(bool value) async {
    await _upsertConfig(categoryPlayer, keyPlayerSingleSentencePause, ValueType.boolean, value ? 'true' : 'false');
  }

  static Future<String> getPlayerLoopingMode() async {
    final row = await _findConfig(categoryPlayer, keyPlayerLoopingMode);
    return row?.value ?? 'single_loop';
  }

  static Future<void> setPlayerLoopingMode(String value) async {
    await _upsertConfig(categoryPlayer, keyPlayerLoopingMode, ValueType.string, value);
  }

  static Future<String> getPlayerShutdownTimerType() async {
    final row = await _findConfig(categoryPlayer, keyPlayerShutdownTimerType);
    return row?.value ?? 'time';
  }

  static Future<void> setPlayerShutdownTimerType(String value) async {
    await _upsertConfig(categoryPlayer, keyPlayerShutdownTimerType, ValueType.string, value);
  }

  static Future<int> getPlayerShutdownTimerSeconds() async {
    final row = await _findConfig(categoryPlayer, keyPlayerShutdownTimerSeconds);
    return int.tryParse(row?.value ?? '0') ?? 0;
  }

  static Future<void> setPlayerShutdownTimerSeconds(int value) async {
    await _upsertConfig(categoryPlayer, keyPlayerShutdownTimerSeconds, ValueType.number, value.toString());
  }

  static Future<int> getPlayerShutdownEpisodeCount() async {
    final row = await _findConfig(categoryPlayer, keyPlayerShutdownEpisodeCount);
    return int.tryParse(row?.value ?? '0') ?? 0;
  }

  static Future<void> setPlayerShutdownEpisodeCount(int value) async {
    await _upsertConfig(categoryPlayer, keyPlayerShutdownEpisodeCount, ValueType.number, value.toString());
  }

  static Future<double> getPlayerSubtitleFontSize() async {
    final row = await _findConfig(categoryPlayer, keyPlayerSubtitleFontSize);
    return double.tryParse(row?.value ?? '20') ?? 20;
  }

  static Future<void> setPlayerSubtitleFontSize(double value) async {
    await _upsertConfig(categoryPlayer, keyPlayerSubtitleFontSize, ValueType.number, value.toString());
  }

  static Future<int> getWifiPort() async {
    final row = await _findConfig(categoryWifi, keyWifiPort);
    return int.tryParse(row?.value ?? '9999') ?? 9999;
  }

  static Future<void> setWifiPort(int value) async {
    await _upsertConfig(categoryWifi, keyWifiPort, ValueType.number, value.toString());
  }

  static Future<double> getAudioOriginalVolumePure() async {
    final row = await _findConfig(categoryPlayer, keyAudioOriginalVolumePure);
    return double.tryParse(row?.value ?? '0.6') ?? 0.6;
  }

  static Future<void> setAudioOriginalVolumePure(double value) async {
    await _upsertConfig(categoryPlayer, keyAudioOriginalVolumePure, ValueType.number, value.clamp(0.0, 1.0).toString());
  }

  static Future<double> getAudioOriginalVolumeMusic() async {
    final row = await _findConfig(categoryPlayer, keyAudioOriginalVolumeMusic);
    return double.tryParse(row?.value ?? '0.8') ?? 0.8;
  }

  static Future<void> setAudioOriginalVolumeMusic(double value) async {
    await _upsertConfig(categoryPlayer, keyAudioOriginalVolumeMusic, ValueType.number, value.clamp(0.0, 1.0).toString());
  }

  static const String categoryAi = 'ai';
  static const String keyTtsCacheSize = 'tts_cache_size';

  static const String categoryWordDisplay = 'word_display';
  static const String keyWordDisplaySections = 'sections_order';

  static Future<bool> getAudioPronunciationVisible() async {
    final row = await _findConfig(categoryPlayer, keyAudioPronunciationVisible);
    final v = row?.value;
    if (v == null) return true;
    return v == 'true' || v == '1';
  }

  static Future<void> setAudioPronunciationVisible(bool value) async {
    await _upsertConfig(categoryPlayer, keyAudioPronunciationVisible, ValueType.boolean, value ? 'true' : 'false');
  }

  static Future<List<String?>> getWordDisplaySections() async {
    final row = await _findConfig(categoryWordDisplay, keyWordDisplaySections);
    if (row?.value == null) return [];
    try {
      final list = jsonDecode(row!.value!) as List;
      return list.whereType<String>().toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> setWordDisplaySections(List<String> sections) async {
    await _upsertConfig(
      categoryWordDisplay,
      keyWordDisplaySections,
      ValueType.json,
      jsonEncode(sections),
    );
  }

  // ─── TTS 缓存设置 ─────────────────────────────

  /// 获取 TTS 持久化缓存最大条数（默认 20）
  static Future<int> getTtsCacheSize() async {
    final row = await _findConfig(categoryAi, keyTtsCacheSize);
    final v = int.tryParse(row?.value ?? '20') ?? 20;
    // 限制范围：5 ~ 200
    return v.clamp(5, 200);
  }

  /// 设置 TTS 持久化缓存最大条数
  static Future<void> setTtsCacheSize(int value) async {
    final v = value.clamp(5, 200);
    await _upsertConfig(categoryAi, keyTtsCacheSize, ValueType.number, v.toString());
  }
}
