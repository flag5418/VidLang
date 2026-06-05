import 'package:vidlang/models/config.dart';
import 'package:vidlang/models/playback_settings.dart';
import 'package:vidlang/models/video_folder.dart';
import 'package:vidlang/services/database_service.dart';

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

  static Future<Config?> _findConfig(String category, String key) async {
    final list = await DatabaseService.findByCondition(
      () => Config(),
      where: 'category = ? AND key = ? AND is_deleted = 0',
      whereArgs: [category, key],
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
    final config = Config(
      category: category,
      key: key,
      valueType: type,
      value: value,
    );
    await DatabaseService.insert(config);
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
}
