import 'dart:convert';

import 'package:vidlang/models/config.dart';
import 'package:vidlang/models/playback_settings.dart';
import 'package:vidlang/models/video_folder.dart';
import 'package:vidlang/services/database_service.dart';

/// 统一用户设置服务
///
/// ## 架构设计
/// 
/// **存储层**: 所有设置都存储到 `config` 表（SQLite），支持多数据类型：
/// - 布尔值 → 字符串 `'true'` / `'false'`
/// - 整数/浮点数 → 字符串形式的数字
/// - 字符串/JSON → 原始字符串
///
/// **多用户隔离**: 通过 `user_code` 字段实现，确保切换用户时设置独立。
/// - 已登录用户：使用其 `user_code`
/// - 未登录用户：不设 `user_code`（全局默认）
///
/// **分类体系**: 设置按 `category` 分组，便于管理和查询：
/// - `playback`: 全局播放行为（跳过片头/片尾）
/// - `player`: 播放器实时状态（倍速、字幕、循环等）
/// - `subscription`: 订阅模式（免费/付费）
/// - `appearance`: 外观主题（亮色/暗色/跟随系统）
/// - `learning`: 学习难度（初级/中级/高级）
/// - `wifi`: WiFi 传输端口
/// - `ai`: AI 相关（TTS 缓存等）
/// - `word_display`: 单词本显示配置
///
/// ## 使用示例
/// 
/// ```dart
/// // 读取播放速度（带默认值）
/// final speed = await SettingsService.getPlayerPlaybackSpeed(); // 默认 1.0x
///
/// // 修改播放速度
/// await SettingsService.setPlayerPlaybackSpeed(1.5);
///
/// // 读取全局播放设置（批量）
/// final settings = await SettingsService.getGlobalPlaybackSettings();
/// print(settings.skipOpening); // 是否跳过片头
/// ```
class SettingsService {
  SettingsService._();

  // ==================== 分类常量 ====================
  
  /// 播放行为分类：全局播放偏好（跳过片头/片尾、缩略图时间点）
  static const String categoryPlayback = 'playback';
  
  /// 播放器状态分类：实时播放器控制参数（倍速、字幕、循环模式等）
  static const String categoryPlayer = 'player';
  
  /// 订阅分类：用户订阅状态
  static const String categorySubscription = 'subscription';
  
  /// 外观分类：主题模式
  static const String categoryAppearance = 'appearance';
  
  /// 学习分类：学习难度等级
  static const String categoryLearning = 'learning';
  
  /// WiFi 分类：文件传输服务配置
  static const String categoryWifi = 'wifi';
  
  /// AI 服务分类：TTS 缓存、AI 评分等
  static const String categoryAi = 'ai';
  
  /// 单词显示分类：单词本界面布局配置
  static const String categoryWordDisplay = 'word_display';

  // ==================== 播放行为设置 (category: playback) ====================
  
  /// 是否跳过视频/音频开头部分
  /// 
  /// **用途**: 自动跳过片头（如主题曲、制作人员名单），直接进入正片。
  /// **默认值**: `false`（不跳过）
  /// **适用**: 视频、音频、文章三种资源类型
  /// **相关**: [keySkipOpeningSeconds] 控制跳过的时长
  static const String keySkipOpening = 'skip_opening_enabled';
  
  /// 跳过开头的时长（秒）
  /// 
  /// **用途**: 配合 [keySkipOpening]，指定从第几秒开始播放。
  /// **范围**: 0 ~ 300 秒
  /// **默认值**: 0（不跳过或从头开始）
  /// **典型值**: 30（跳过30秒片头）、90（跳过1分半片头）
  static const String keySkipOpeningSeconds = 'skip_opening_seconds';
  
  /// 是否跳过视频/音频结尾部分
  /// 
  /// **用途**: 自动跳过片尾（如演职员表、预告），提前结束播放。
  /// **默认值**: `false`（不跳过）
  /// **适用**: 视频、音频两种资源类型
  /// **相关**: [keySkipEndingSeconds] 控制跳过的时长
  static const String keySkipEnding = 'skip_ending_enabled';
  
  /// 跳过结尾的时长（秒）
  /// 
  /// **用途**: 配合 [keySkipEnding]，指定距离结束前多少秒停止。
  /// **范围**: 0 ~ 300 秒
  /// **默认值**: 0（播放到结尾）
  /// **典型值**: 15（提前15秒结束）、30（提前30秒结束）
  static const String keySkipEndingSeconds = 'skip_ending_seconds';
  
  /// 视频缩略图截取时间点（秒）
  /// 
  /// **用途**: 从视频的第几秒截取封面缩略图。
  /// **范围**: 0 ~ 视频时长
  /// **默认值**: 15（第15秒处截图，通常能避开黑屏开头）
  /// **影响**: 文件夹列表中的视频封面显示
  static const String keyThumbnailSeconds = 'thumbnail_time_seconds';

  /// 默认分组名称（未手动分组的资源归入此组）
  static const String defaultGroupName = '未分组';

  // ==================== 播放器状态设置 (category: player) ====================
  
  /// 播放速度（倍速）
  /// 
  /// **用途**: 控制 视频/音频 的播放速率。
  /// **范围**: 0.5x ~ 2.0x（通过 clamp 限制）
  /// **默认值**: 1.0x（正常速度）
  /// **典型值**: 
  ///   - 0.75x: 慢速学习（听力训练）
  ///   - 1.0x: 正常速度
  ///   - 1.25x: 稍快（提高效率）
  ///   - 1.5x: 快速（复习已学内容）
  ///   - 2.0x: 极速（浏览熟悉内容）
  static const String keyPlayerPlaybackSpeed = 'playback_speed';
  
  /// 字幕是否可见
  /// 
  /// **用途**: 全局控制字幕的显示/隐藏（不影响字幕数据加载）。
  /// **默认值**: `true`（显示字幕）
  /// **注意**: 这是全局开关，单部资源的字幕控制可能另有逻辑
  static const String keyPlayerSubtitleVisible = 'subtitle_visible';
  
  /// 翻译/释义是否可见
  /// 
  /// **用途**: 控制单词翻译或句子释义的显示。
  /// **默认值**: `true`（显示翻译）
  /// **适用**: 视频字幕下方的翻译、文章阅读器的词汇提示
  static const String keyPlayerTranslateVisible = 'translate_visible';
  
  /// 单句循环暂停模式
  /// 
  /// **用途**: 每播放完一句字幕后是否自动暂停（用于跟读练习）。
  /// **默认值**: `false`（连续播放）
  /// **适用**: 语言学习的跟读功能
  /// **影响**: 播放器在每句结束时的行为
  static const String keyPlayerSingleSentencePause = 'single_sentence_pause';
  
  /// 循环播放模式
  /// 
  /// **用途**: 控制整个资源播放完后的循环方式。
  /// **可选值**:
  ///   - `'single_loop'`: 单集循环（默认，重复播放当前资源）
  ///   - `'list_loop'`: 列表循环（播完当前自动播放下一个）
  ///   - `'no_loop'`: 不循环（播完停止）
  /// **默认值**: `'single_loop'`
  static const String keyPlayerLoopingMode = 'looping_mode';
  
  /// 定时关闭类型
  /// 
  /// **用途**: 定时自动关闭播放器的触发方式。
  /// **可选值**:
  ///   - `'time'`: 按时间关闭（配合 [keyPlayerShutdownTimerSeconds]）
  ///   - `'episode'`: 按集数关闭（配合 [keyPlayerShutdownEpisodeCount]）
  ///   - `'none'`: 不定时关闭
  /// **默认值**: `'time'`
  /// **使用场景**: 睡前定时关闭播放器（助眠功能）
  static const String keyPlayerShutdownTimerType = 'shutdown_timer_type';
  
  /// 定时关闭时间（秒）
  /// 
  /// **用途**: 当 [keyPlayerShutdownTimerType] == `'time'` 时，多少秒后关闭。
  /// **范围**: 0 ~ 14400 秒（4小时）
  /// **默认值**: 0（不定时关闭）
  /// **典型值**: 900（15分钟）、1800（30分钟）、3600（1小时）
  static const String keyPlayerShutdownTimerSeconds = 'shutdown_timer_seconds';
  
  /// 定时关闭集数
  /// 
  /// **用途**: 当 [keyPlayerShutdownTimerType] == `'episode'` 时，播放几集后关闭。
  /// **范围**: 0 ~ 100 集
  /// **默认值**: 0（不限集数）
  /// **典型值**: 3（播3集后关闭）、5（播5集后关闭）
  static const String keyPlayerShutdownEpisodeCount = 'shutdown_episode_count';
  
  /// 字幕字体大小（sp）
  /// 
  /// **用途**: 控制字幕文字的显示大小。
  /// **范围**: 12 ~ 32 sp
  /// **默认值**: 20 sp
  /// **影响**: 视频播放器、音频播放器的字幕渲染
  static const String keyPlayerSubtitleFontSize = 'subtitle_font_size';

  // ==================== 音频音量设置 (category: player) ====================
  
  /// 原声/人声音量（0.0 ~ 1.0）
  /// 
  /// **用途**: 音频播放时原声轨道（人声/主旋律）的音量。
  /// **范围**: 0.0（静音）~ 1.0（最大音量）
  /// **默认值**: 0.6（60%音量，为背景音乐留空间）
  /// **适用**: 仅音频资源（音乐、播客等有原声+伴奏分离的场景）
  /// **注意**: 视频无此选项，视频音量统一用系统音量
  static const String keyAudioOriginalVolumePure = 'audio_original_volume_pure';
  
  /// 伴奏/背景音乐音量（0.0 ~ 1.0）
  /// 
  /// **用途**: 音频播放时伴奏轨道（背景音乐/节拍）的音量。
  /// **范围**: 0.0（静音）~ 1.0（最大音量）
  /// **默认值**: 0.8（80%音量，突出伴奏）
  /// **适用**: 仅音频资源（卡拉OK模式、学习伴奏等）
  /// **关联**: 通常与 [keyAudioOriginalVolumePure] 配合使用
  static const String keyAudioOriginalVolumeMusic = 'audio_original_volume_music';
  
  /// 音频发音/音标显示开关
  /// 
  /// **用途**: 音频播放时是否显示歌词上方/下方的音标（IPA）或发音提示。
  /// **默认值**: `true`（显示发音）
  /// **适用**: 音频播放器的歌词显示区域
  /// **帮助**: 辅助学习者掌握正确发音
  static const String keyAudioPronunciationVisible = 'audio_pronunciation_visible';

  // ==================== WiFi 传输设置 (category: wifi) ====================
  
  /// WiFi 文件传输服务端口号
  /// 
  /// **用途**: 手机作为 WiFi 服务器时监听的端口号。
  /// **范围**: 1024 ~ 65535
  /// **默认值**: 9999
  /// **注意**: 需确保端口未被其他应用占用，且防火墙允许该端口
  static const String keyWifiPort = 'port';

  // ==================== AI 服务设置 (category: ai) ====================
  
  /// TTS（文本转语音）持久化缓存最大条数
  /// 
  /// **用途**: 限制本地缓存的 TTS 音频文件数量，避免占用过多存储空间。
  /// **范围**: 5 ~ 200 条
  /// **默认值**: 20 条
  /// **清理策略**: 超出限制时淘汰最久未使用的缓存
  /// **影响**: AI 评价、跟读评分等功能的响应速度（命中缓存则更快）
  static const String keyTtsCacheSize = 'tts_cache_size';

  // ==================== 单词显示设置 (category: word_display) ====================
  
  /// 单词本详情页的区块显示顺序
  /// 
  /// **用途**: 自定义单词详情页面各信息块的排列顺序。
  /// **数据格式**: JSON 数组，如 `['例句', '词根', '变形', '同义词']`
  /// **默认值**: `[]`（空数组，使用系统默认顺序）
  /// **可选值**:
  ///   - `'例句'`: 例句展示区
  ///   - `'词根'`: 词根词缀分析
  ///   - `'变形'`: 词形变化（时态、复数等）
  ///   - `'同义词'`: 同义词/近义词
  ///   - `'反义词'`: 反义词
  ///   - `'搭配'': 常见搭配/短语
  ///   - `'音标'`: IPA 国际音标
  /// **影响**: 单词本点击单词后的详情面板布局
  static const String keyWordDisplaySections = 'sections_order';

  // ==================== 订阅设置 (category: subscription) ====================
  
  /// 用户订阅模式
  /// 
  /// **用途**: 标识用户的订阅状态，决定功能权限。
  /// **可选值**:
  ///   - `'free'`: 免费用户（功能受限）
  ///   - `'premium'`: 付费用户（解锁全部功能）
  /// **默认值**: `'free'`
  /// **影响**: 高级功能（AI 点评、无限导入等）的访问权限
  static const String keySubscriptionMode = 'subscription_mode';

  // ==================== 外观设置 (category: appearance) ====================
  
  /// 主题模式
  /// 
  /// **用途**: 应用整体的主题风格。
  /// **可选值**:
  ///   - `'light'`: 亮色主题（白色背景）
  ///   - `'dark'`: 暗色主题（深色背景 #2E302A）
  ///   - `'system'`: 跟随系统设置（默认）
  /// **默认值**: `'system'`
  /// **影响**: 全局配色方案、组件颜色
  static const String keyThemeMode = 'theme_mode';

  // ==================== 学习设置 (category: learning) ====================
  
  /// 学习难度等级
  /// 
  /// **用途**: 根据用户语言水平调整内容推荐和测试难度。
  /// **可选值**:
  ///   - `'beginner'`: 初学者（基础词汇、简单句型）
  ///   - `'intermediate'`: 中级者（进阶词汇、复杂语法）⬅️ 默认
  ///   - `'advanced'`: 高级者（专业词汇、地道表达）
  /// **默认值**: `'intermediate'`
  /// **影响**: 测试题目难度、推荐内容筛选、AI 对话复杂度
  static const String keyDifficultyLevel = 'difficulty_level';

  // ==================== 默认值定义 ====================
  
  /// 全局播放设置的默认值
  /// 
  /// 新安装应用或首次使用时的初始配置。
  /// 可通过 [saveGlobalPlaybackSettings] 修改并持久化。
  static const PlaybackSettings _defaults = PlaybackSettings(
    skipOpening: false,        // 不跳过片头
    skipOpeningDuration: 0,     // 跳过时长 0 秒
    skipEnding: false,         // 不跳过片尾
    skipEndingDuration: 0,      // 跳过时长 0 秒
    thumbnailTime: 15,         // 第 15 秒截取缩略图
  );

  // ==================== 全局播放设置读写 ====================

  /// 获取全局播放设置（从数据库读取）
  /// 
  /// 返回包含以下字段的 [PlaybackSettings]:
  /// - [PlaybackSettings.skipOpening]: 是否跳过片头
  /// - [PlaybackSettings.skipOpeningDuration]: 跳过片头时长
  /// - [PlaybackSettings.skipEnding]: 是否跳过片尾
  /// - [PlaybackSettings.skipEndingDuration]: 跳过片尾时长
  /// - [PlaybackSettings.thumbnailTime]: 缩略图截取时间点
  /// 
  /// 如果某项未设置过，返回 [_defaults] 中的默认值。
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

  /// 保存全局播放设置（写入数据库）
  /// 
  /// 将 [PlaybackSettings] 中的所有字段持久化到 config 表。
  /// 会覆盖之前的同名配置项。
  static Future<void> saveGlobalPlaybackSettings(PlaybackSettings s) async {
    await _setBool(keySkipOpening, s.skipOpening);
    await _setInt(keySkipOpeningSeconds, s.skipOpeningDuration);
    await _setBool(keySkipEnding, s.skipEnding);
    await _setInt(keySkipEndingSeconds, s.skipEndingDuration);
    await _setInt(keyThumbnailSeconds, s.thumbnailTime);
  }

  // ==================== 视频集级别播放设置 ====================

  /// 获取指定文件夹的播放设置
  /// 
  /// 与全局设置不同，文件夹级别的设置存储在 [VideoFolder] 表的字段中，
  /// 支持每个文件夹有不同的跳过/缩略图配置。
  /// 
  /// **优先级**: 文件夹设置 > 全局设置（如果文件夹字段为空则回退到全局）
  static Future<PlaybackSettings> getFolderPlaybackSettings(
    VideoFolder folder,
  ) async {
    return PlaybackSettings.fromFolder(folder);
  }

  /// 解析文件夹的播放设置（别名方法，语义更清晰）
  static Future<PlaybackSettings> resolveForFolder(VideoFolder folder) async {
    return getFolderPlaybackSettings(folder);
  }

  /// 将全局默认设置应用到指定文件夹
  /// 
  /// **使用场景**: 新建文件夹时调用，继承用户的全局播放偏好。
  /// 会修改 [VideoFolder] 对象的以下字段但不保存到数据库：
  /// - [VideoFolder.skipOpening]
  /// - [VideoFolder.skipOpeningDuration]
  /// - [VideoFolder.skipEnding]
  /// - [VideoFolder.skipEndingDuration]
  /// - [VideoFolder.thumbnailTime]
  static Future<void> applyGlobalDefaultsToFolder(VideoFolder folder) async {
    final g = await getGlobalPlaybackSettings();
    folder.skipOpening = g.skipOpening;
    folder.skipOpeningDuration = g.skipOpeningDuration;
    folder.skipEnding = g.skipEnding;
    folder.skipEndingDuration = g.skipEndingDuration;
    folder.thumbnailTime = g.thumbnailTime;
  }

  // ==================== 文件夹层级判断工具方法 ====================

  /// 判断是否为分组文件夹（父级容器）
  /// 
  /// **判断条件**: `parent_code` 为空或未设置。
  /// **特点**: 不能直接挂载视频/音频/文章，只能包含叶子文件夹。
  /// **UI 表现**: 在文件列表中显示为"分组"样式（可能有特殊图标或颜色）
  static bool isGroupFolder(VideoFolder f) => f.parentCode == null || f.parentCode!.isEmpty;

  /// 判断是否为叶子视频集（可挂载资源的实际文件夹）
  /// 
  /// **判断条件**: `parent_code` 非空且有值。
  /// **特点**: 可以直接包含视频/音频/文章资源。
  /// **UI 表现**: 显示为普通文件夹卡片，可进入查看资源列表
  static bool isLeafVideoSet(VideoFolder f) =>
      f.parentCode != null && f.parentCode!.isNotEmpty;

  /// 确保存在"未分组"默认分组
  /// 
  /// **用途**: 新应用首次启动或数据迁移时调用，保证有一个兜底分组。
  /// **返回值**: 默认分组的 `code`（用于将未分类的资源归入此组）
  /// **逻辑**: 
  /// 1. 查询名为 [defaultGroupName] 且无父级的未删除文件夹
  /// 2. 如果存在则返回其 code
  /// 3. 如果不存在则创建一个虚拟类型（[VideoFolderType.virtual]）的文件夹
  static Future<String> ensureDefaultGroupCode() async {
    final existing = await DatabaseService.findByCondition(
      () => VideoFolder(),
      where: "name = ? AND (parent_code IS NULL OR parent_code = '') AND is_deleted = 0",
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

  // ==================== 底层存取方法 ====================

  /// 读取布尔值配置项
  /// 
  /// 从 config 表读取，自动将字符串 `'true'/'1'` 转为 `true`，其他转为 `false`。
  /// 如果配置项不存在，返回 `null`（调用方应提供默认值）。
  static Future<bool?> _getBool(String key) async {
    final row = await _findConfig(categoryPlayback, key);
    if (row == null || row.value == null) return null;
    return row.value == 'true' || row.value == '1';
  }

  /// 读取整数值配置项
  /// 
  /// 从 config 表读取，尝试将字符串解析为整数。
  /// 如果解析失败或配置项不存在，返回 `null`。
  static Future<int?> _getInt(String key) async {
    final row = await _findConfig(categoryPlayback, key);
    if (row == null || row.value == null) return null;
    return int.tryParse(row.value!);
  }

  /// 查找配置项（按当前用户隔离）
  /// 
  /// **查询条件**: category + key + user_code（如果有登录用户）
  /// **返回**: 匹配到的第一条 [Config] 记录，或 `null`
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

  /// 写入布尔值配置项
  static Future<void> _setBool(String key, bool value) async {
    await _upsertConfig(categoryPlayback, key, ValueType.boolean, value ? 'true' : 'false');
  }

  /// 写入整数值配置项
  static Future<void> _setInt(String key, int value) async {
    await _upsertConfig(categoryPlayback, key, ValueType.number, value.toString());
  }

  /// 插入或更新配置项（按当前用户隔离）
  /// 
  /// **Upsert 逻辑**:
  /// 1. 先查询是否存在相同 category + key + user_code 的记录
  /// 2. 如果存在 → 更新 value 和 valueType
  /// 3. 如果不存在 → 插入新记录（自动带上 userCode）
  /// 
  /// **多用户隔离**: 通过 [DatabaseService.getCurrentUserCode()] 获取当前用户标识。
  /// 未登录时不设置 userCode（视为全局默认配置）。
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

  // ==================== 订阅/计费模式设置 API ====================

  /// 获取订阅模式（免费/付费）
  /// 
  /// **返回值**: `'free'` 或 `'premium'`
  /// **默认值**: `'free'`（新用户默认为免费版）
  static Future<String> getSubscriptionMode() async {
    final row = await _findConfig(categorySubscription, keySubscriptionMode);
    return row?.value ?? 'free';
  }

  /// 设置订阅模式（免费/付费）
  /// 
  /// **触发时机**: 
  /// - 用户完成支付后
  /// - 管理员手动调整
  /// - 开发调试时切换
  static Future<void> setSubscriptionMode(String mode) async {
    await _upsertConfig(categorySubscription, keySubscriptionMode, ValueType.string, mode);
  }

  // ==================== 外观/主题设置 API ====================

  /// 获取主题模式（light/dark/system）
  /// 
  /// **返回值**: `'light'`、`'dark'` 或 `'system'`
  /// **默认值**: `'system'`（跟随系统设置）
  static Future<String> getThemeMode() async {
    final row = await _findConfig(categoryAppearance, keyThemeMode);
    return row?.value ?? 'system';
  }

  /// 设置主题模式
  /// 
  /// **参数说明**:
  /// - `'light'`: 强制亮色主题
  /// - `'dark'`: 强制暗色主题
  /// - `'system'`: 跟随操作系统（推荐）
  static Future<void> setThemeMode(String mode) async {
    await _upsertConfig(categoryAppearance, keyThemeMode, ValueType.string, mode);
  }

  // ==================== 学习难度设置 API ====================

  /// 获取学习难度等级
  /// 
  /// **返回值**: `'beginner'`、`'intermediate'` 或 `'advanced'`
  /// **默认值**: `'intermediate'`（中级，适合大多数学习者）
  static Future<String> getDifficultyLevel() async {
    final row = await _findConfig(categoryLearning, keyDifficultyLevel);
    return row?.value ?? 'intermediate';
  }

  /// 设置学习难度等级
  /// 
  /// **影响范围**:
  /// - 测试题目的难度选择
  /// - AI 对话的语言复杂度
  /// - 推荐内容的筛选标准
  static Future<void> setDifficultyLevel(String level) async {
    await _upsertConfig(categoryLearning, keyDifficultyLevel, ValueType.string, level);
  }

  // ==================== 播放器状态设置 API ====================

  /// 获取播放速度（倍速）
  /// 
  /// **返回值**: 0.5 ~ 2.0 之间的浮点数
  /// **默认值**: 1.0（正常速度）
  /// **安全措施**: 通过 `.clamp(0.5, 2.0)` 限制范围，防止异常值
  static Future<double> getPlayerPlaybackSpeed() async {
    final row = await _findConfig(categoryPlayer, keyPlayerPlaybackSpeed);
    final v = row?.value == null ? null : double.tryParse(row!.value!);
    return (v ?? 1.0).clamp(0.5, 2.0);
  }

  /// 设置播放速度（倍速）
  /// 
  /// **参数**: 0.5 ~ 2.0 的浮点数（超出范围会自动 clamp）
  static Future<void> setPlayerPlaybackSpeed(double speed) async {
    final v = speed.clamp(0.5, 2.0);
    await _upsertConfig(categoryPlayer, keyPlayerPlaybackSpeed, ValueType.number, v.toString());
  }

  /// 获取字幕是否可见
  /// 
  /// **返回值**: `true`（显示）/ `false`（隐藏）
  /// **默认值**: `true`
  static Future<bool> getPlayerSubtitleVisible() async {
    final row = await _findConfig(categoryPlayer, keyPlayerSubtitleVisible);
    final v = row?.value;
    if (v == null) return true;
    return v == 'true' || v == '1';
  }

  /// 设置字幕是否可见
  static Future<void> setPlayerSubtitleVisible(bool value) async {
    await _upsertConfig(categoryPlayer, keyPlayerSubtitleVisible, ValueType.boolean, value ? 'true' : 'false');
  }

  /// 获取翻译/释义是否可见
  /// 
  /// **返回值**: `true`（显示）/ `false`（隐藏）
  /// **默认值**: `true`
  static Future<bool> getPlayerTranslateVisible() async {
    final row = await _findConfig(categoryPlayer, keyPlayerTranslateVisible);
    final v = row?.value;
    if (v == null) return true;
    return v == 'true' || v == '1';
  }

  /// 设置翻译/释义是否可见
  static Future<void> setPlayerTranslateVisible(bool value) async {
    await _upsertConfig(categoryPlayer, keyPlayerTranslateVisible, ValueType.boolean, value ? 'true' : 'false');
  }

  /// 获取单句循环暂停模式
  /// 
  /// **返回值**: `true`（每句暂停）/ `false`（连续播放）
  /// **默认值**: `false`
  /// **使用场景**: 跟读练习时开启，逐句模仿
  static Future<bool> getPlayerSingleSentencePause() async {
    final row = await _findConfig(categoryPlayer, keyPlayerSingleSentencePause);
    final v = row?.value;
    if (v == null) return false;
    return v == 'true' || v == '1';
  }

  /// 设置单句循环暂停模式
  static Future<void> setPlayerSingleSentencePause(bool value) async {
    await _upsertConfig(categoryPlayer, keyPlayerSingleSentencePause, ValueType.boolean, value ? 'true' : 'false');
  }

  /// 获取循环播放模式
  /// 
  /// **返回值**: `'single_loop'` / `'list_loop'` / `'no_loop'`
  /// **默认值**: `'single_loop'`
  static Future<String> getPlayerLoopingMode() async {
    final row = await _findConfig(categoryPlayer, keyPlayerLoopingMode);
    return row?.value ?? 'single_loop';
  }

  /// 设置循环播放模式
  static Future<void> setPlayerLoopingMode(String value) async {
    await _upsertConfig(categoryPlayer, keyPlayerLoopingMode, ValueType.string, value);
  }

  /// 获取定时关闭类型
  /// 
  /// **返回值**: `'time'` / `'episode'` / `'none'`
  /// **默认值**: `'time'`
  static Future<String> getPlayerShutdownTimerType() async {
    final row = await _findConfig(categoryPlayer, keyPlayerShutdownTimerType);
    return row?.value ?? 'time';
  }

  /// 设置定时关闭类型
  static Future<void> setPlayerShutdownTimerType(String value) async {
    await _upsertConfig(categoryPlayer, keyPlayerShutdownTimerType, ValueType.string, value);
  }

  /// 获取定时关闭时间（秒）
  /// 
  /// **返回值**: 0 ~ 14400 之间的整数（0 表示不定时）
  /// **默认值**: 0
  static Future<int> getPlayerShutdownTimerSeconds() async {
    final row = await _findConfig(categoryPlayer, keyPlayerShutdownTimerSeconds);
    return int.tryParse(row?.value ?? '0') ?? 0;
  }

  /// 设置定时关闭时间（秒）
  static Future<void> setPlayerShutdownTimerSeconds(int value) async {
    await _upsertConfig(categoryPlayer, keyPlayerShutdownTimerSeconds, ValueType.number, value.toString());
  }

  /// 获取定时关闭集数
  /// 
  /// **返回值**: 0 ~ 100 之间的整数（0 表示不限集数）
  /// **默认值**: 0
  static Future<int> getPlayerShutdownEpisodeCount() async {
    final row = await _findConfig(categoryPlayer, keyPlayerShutdownEpisodeCount);
    return int.tryParse(row?.value ?? '0') ?? 0;
  }

  /// 设置定时关闭集数
  static Future<void> setPlayerShutdownEpisodeCount(int value) async {
    await _upsertConfig(categoryPlayer, keyPlayerShutdownEpisodeCount, ValueType.number, value.toString());
  }

  /// 获取字幕字体大小（sp）
  /// 
  /// **返回值**: 浮点数，表示字体大小
  /// **默认值**: 20.0 sp
  static Future<double> getPlayerSubtitleFontSize() async {
    final row = await _findConfig(categoryPlayer, keyPlayerSubtitleFontSize);
    return double.tryParse(row?.value ?? '20') ?? 20;
  }

  /// 设置字幕字体大小（sp）
  static Future<void> setPlayerSubtitleFontSize(double value) async {
    await _upsertConfig(categoryPlayer, keyPlayerSubtitleFontSize, ValueType.number, value.toString());
  }

  // ==================== WiFi 传输设置 API ====================

  /// 获取 WiFi 传输端口号
  /// 
  /// **返回值**: 1024 ~ 65535 之间的整数
  /// **默认值**: 9999
  static Future<int> getWifiPort() async {
    final row = await _findConfig(categoryWifi, keyWifiPort);
    return int.tryParse(row?.value ?? '9999') ?? 9999;
  }

  /// 设置 WiFi 传输端口号
  static Future<void> setWifiPort(int value) async {
    await _upsertConfig(categoryWifi, keyWifiPort, ValueType.number, value.toString());
  }

  // ==================== 音频音量设置 API ====================

  /// 获取原声/人声音量（0.0 ~ 1.0）
  /// 
  /// **返回值**: 0.0 ~ 1.0 之间的浮点数
  /// **默认值**: 0.6（60%音量）
  /// **安全措施**: 通过 `.clamp(0.0, 1.0)` 限制范围
  static Future<double> getAudioOriginalVolumePure() async {
    final row = await _findConfig(categoryPlayer, keyAudioOriginalVolumePure);
    return double.tryParse(row?.value ?? '0.6') ?? 0.6;
  }

  /// 设置原声/人声音量（0.0 ~ 1.0）
  static Future<void> setAudioOriginalVolumePure(double value) async {
    await _upsertConfig(categoryPlayer, keyAudioOriginalVolumePure, ValueType.number, value.clamp(0.0, 1.0).toString());
  }

  /// 获取伴奏/背景音乐音量（0.0 ~ 1.0）
  /// 
  /// **返回值**: 0.0 ~ 1.0 之间的浮点数
  /// **默认值**: 0.8（80%音量）
  /// **安全措施**: 通过 `.clamp(0.0, 1.0)` 限制范围
  static Future<double> getAudioOriginalVolumeMusic() async {
    final row = await _findConfig(categoryPlayer, keyAudioOriginalVolumeMusic);
    return double.tryParse(row?.value ?? '0.8') ?? 0.8;
  }

  /// 设置伴奏/背景音乐音量（0.0 ~ 1.0）
  static Future<void> setAudioOriginalVolumeMusic(double value) async {
    await _upsertConfig(categoryPlayer, keyAudioOriginalVolumeMusic, ValueType.number, value.clamp(0.0, 1.0).toString());
  }

  /// 获取音频发音/音标显示开关
  /// 
  /// **返回值**: `true`（显示）/ `false`（隐藏）
  /// **默认值**: `true`
  static Future<bool> getAudioPronunciationVisible() async {
    final row = await _findConfig(categoryPlayer, keyAudioPronunciationVisible);
    final v = row?.value;
    if (v == null) return true;
    return v == 'true' || v == '1';
  }

  /// 设置音频发音/音标显示开关
  static Future<void> setAudioPronunciationVisible(bool value) async {
    await _upsertConfig(categoryPlayer, keyAudioPronunciationVisible, ValueType.boolean, value ? 'true' : 'false');
  }

  // ==================== 单词显示设置 API ====================

  /// 获取单词本详情页的区块显示顺序
  /// 
  /// **返回值**: 字符串列表，如 `['例句', '词根', '变形']`
  /// **默认值**: 空列表（使用系统默认顺序）
  /// **数据格式**: JSON 数组
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

  /// 设置单词本详情页的区块显示顺序
  /// 
  /// **参数**: 字符串列表，如 `['例句', '词根', '变形', '同义词']`
  /// **存储**: JSON 编码后的字符串
  static Future<void> setWordDisplaySections(List<String> sections) async {
    await _upsertConfig(
      categoryWordDisplay,
      keyWordDisplaySections,
      ValueType.json,
      jsonEncode(sections),
    );
  }

  // ==================== TTS 缓存设置 API ====================

  /// 获取 TTS 持久化缓存最大条数
  /// 
  /// **返回值**: 5 ~ 200 之间的整数
  /// **默认值**: 20 条
  /// **安全措施**: 通过 `.clamp(5, 200)` 限制范围
  /// **性能影响**: 
  /// - 过小（<10）: 缓存命中率低，频繁请求 TTS API
  /// - 过大（>100）: 占用过多存储空间
  static Future<int> getTtsCacheSize() async {
    final row = await _findConfig(categoryAi, keyTtsCacheSize);
    final v = int.tryParse(row?.value ?? '20') ?? 20;
    // 限制范围：5 ~ 200
    return v.clamp(5, 200);
  }

  /// 设置 TTS 持久化缓存最大条数
  /// 
  /// **参数**: 5 ~ 200 之间的整数
  /// **注意事项**: 修改后会清理超出限制的旧缓存
  static Future<void> setTtsCacheSize(int value) async {
    final v = value.clamp(5, 200);
    await _upsertConfig(categoryAi, keyTtsCacheSize, ValueType.number, v.toString());
  }
}
