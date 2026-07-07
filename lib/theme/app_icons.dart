/// 图标系统
///
/// 统一管理应用中使用的所有图标，包括：
/// - Flutter内置 Material Icons
/// - Hugeicons（第三方图标库，4700+ 免费 SVG 图标）
///   - 官方浏览: https://hugeicons.com/icons
///   - 用法: HugeIcon(icon: HugeIcons.strokeRoundedXxx, size: 24, color: ...)
/// - 自定义PNG图标（特殊情况下使用）
///
/// 图标分类：
/// - Navigation icons（导航图标）
/// - Action icons（操作图标）
/// - Media icons（媒体图标）
/// - File icons（文件图标）
/// - Status icons（状态图标）
/// - User icons（用户图标）
/// - Tab bar icons（标签栏图标）
/// - Network icons（网络/连接图标）
/// - Time/Date icons（时间/日期图标）
/// - File operation icons（文件操作图标）
/// - Conversation icons（对话图标）
/// - Evaluation icons（评测图标）
/// - Word Book icons（单词本图标）
/// - Settings icons（设置图标）
///
/// 使用方式：
/// ```dart
/// // 使用Flutter内置图标
/// AppIcons.getIcon(AppIcons.videoLibrary)
///
/// // 或直接使用Icon类
/// Icon(AppIcons.videoLibrary)
///
/// // Hugeicons 图标
/// import 'package:hugeicons/hugeicons.dart';
/// HugeIcon(icon: HugeIcons.strokeRoundedHome01, size: 24)
///
/// // 自定义PNG图标
/// AppIcons.getPngIcon(AppIcons.logo)
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

/// 应用图标类
///
/// 包含所有图标定义，提供统一的访问接口
class AppIcons {
  AppIcons._();

  // ============================================================
  // 导航图标
  // ============================================================

  /// 返回/后退
  static const IconData arrowBack = Icons.arrow_back_rounded;

  /// 前进
  static const IconData arrowForward = Icons.arrow_forward_rounded;

  /// 展开更多
  static const IconData expandMore = Icons.expand_more_rounded;

  /// 收起
  static const IconData expandLess = Icons.expand_less_rounded;

  /// 菜单
  static const IconData menu = Icons.menu_rounded;

  /// 关闭
  static const IconData close = Icons.close_rounded;

  /// 检查
  static const IconData check = Icons.check_rounded;

  /// 右箭头
  static const IconData chevronRight = Icons.chevron_right_rounded;

  /// 左箭头（iOS风格）
  static const IconData arrowBackIos = Icons.arrow_back_ios_rounded;

  /// 左箭头（iOS新风格）
  static const IconData arrowBackIosNew = Icons.arrow_back_ios_new_rounded;

  /// 取消
  static const IconData cancel = Icons.cancel;

  /// 上箭头
  static const IconData arrowUpward = Icons.arrow_upward;

  /// 下箭头
  static const IconData arrowDownward = Icons.arrow_downward;

  /// 键盘上箭头
  static const IconData keyboardArrowUp = Icons.keyboard_arrow_up_rounded;

  /// 键盘下箭头
  static const IconData keyboardArrowDown = Icons.keyboard_arrow_down_rounded;

  // ============================================================
  // 操作图标
  // ============================================================

  /// 添加
  static const IconData add = Icons.add_rounded;

  /// 添加圆形轮廓
  static const IconData addCircleOutline = Icons.add_circle_outline;

  /// 删除
  static const IconData delete = Icons.delete_outline_rounded;

  /// 永久删除
  static const IconData deleteForever = Icons.delete_forever_rounded;

  /// 批量删除
  static const IconData deleteSweep = Icons.delete_sweep;

  /// 编辑/修改
  static const IconData edit = Icons.edit_outlined;

  /// 分享
  static const IconData share = Icons.share_outlined;

  /// 更多（纵向）
  static const IconData moreVert = Icons.more_vert_rounded;

  /// 更多（横向）
  static const IconData moreHoriz = Icons.more_horiz_rounded;

  /// 设置
  static const IconData settings = Icons.settings_outlined;

  /// 搜索
  static const IconData search = Icons.search_rounded;

  /// 刷新
  static const IconData refresh = Icons.refresh_rounded;

  /// 排序
  static const IconData sort = Icons.sort_rounded;

  /// 筛选
  static const IconData filter = Icons.filter_list_rounded;

  /// 复制
  static const IconData copy = Icons.copy_outlined;

  /// 下载
  static const IconData download = Icons.download_outlined;

  /// 上传
  static const IconData upload = Icons.upload_file_outlined;

  /// 保存
  static const IconData save = Icons.save;

  /// 清除
  static const IconData clear = Icons.clear;

  /// 移除
  static const IconData remove = Icons.remove_rounded;

  /// 列表
  static const IconData list = Icons.list;

  /// 反馈
  static const IconData feedback = Icons.feedback;

  /// 分类
  static const IconData category = Icons.category_outlined;

  /// 图层
  static const IconData layers = Icons.layers;

  /// 拖拽手柄
  static const IconData dragHandle = Icons.drag_handle;

  /// 返回退格
  static const IconData backspace = Icons.backspace_outlined;

  /// 自动修复
  static const IconData autoFixHigh = Icons.auto_fix_high;

  /// 退格
  static const IconData formatListBulleted = Icons.format_list_bulleted_rounded;

  /// 有序列表
  static const IconData formatListNumbered = Icons.format_list_numbered_rounded;

  /// 标签轮廓
  static const IconData labelOutline = Icons.label_outline_rounded;

  /// 应用
  static const IconData apps = Icons.apps_rounded;

  /// 自动填充
  static const IconData autoAwesome = Icons.auto_awesome;

  /// 钉钉
  static const IconData pushPin = Icons.push_pin;

  /// 仪表盘
  static const IconData dashboard = Icons.dashboard;

  /// 档案
  static const IconData assignment = Icons.assignment;

  /// 类别
  static const IconData appsRound = Icons.apps_rounded;

  // ============================================================
  // 媒体图标
  // ============================================================

  /// 播放
  static const IconData play = Icons.play_arrow_rounded;

  /// 暂停
  static const IconData pause = Icons.pause_rounded;

  /// 停止
  static const IconData stop = Icons.stop_rounded;

  /// 上一首
  static const IconData skipPrevious = Icons.skip_previous_rounded;

  /// 下一首
  static const IconData skipNext = Icons.skip_next_rounded;

  /// 快退
  static const IconData rewind = Icons.fast_rewind_rounded;

  /// 快进
  static const IconData fastForward = Icons.fast_forward_rounded;

  /// 音量
  static const IconData volumeUp = Icons.volume_up_rounded;

  /// 音量降低
  static const IconData volumeDown = Icons.volume_down_rounded;

  /// 静音
  static const IconData volumeOff = Icons.volume_off_rounded;

  /// 全屏
  static const IconData fullscreen = Icons.fullscreen_rounded;

  /// 退出全屏
  static const IconData fullscreenExit = Icons.fullscreen_exit_rounded;

  /// 字幕
  static const IconData subtitles = Icons.subtitles_rounded;

  /// 字幕关闭
  static const IconData subtitlesOff = Icons.subtitles_off_rounded;

  /// 音频
  static const IconData audioTrack = Icons.audiotrack_rounded;

  /// 视频
  static const IconData video = Icons.videocam_outlined;

  /// 摄像机
  static const IconData videocam = Icons.videocam;

  /// 视频库
  static const IconData videoLibrary = Icons.video_library_outlined;

  /// 播放列表
  static const IconData playlistPlay = Icons.playlist_play_rounded;

  /// 循环播放
  static const IconData repeat = Icons.repeat_rounded;

  /// 单曲循环
  static const IconData repeatOne = Icons.repeat_one_rounded;

  /// 随机播放
  static const IconData shuffle = Icons.shuffle_rounded;

  /// 麦克风
  static const IconData mic = Icons.mic;

  /// 麦克风（圆角）
  static const IconData micRounded = Icons.mic_rounded;

  /// 麦克风（无）
  static const IconData micNone = Icons.mic_none_rounded;

  /// 音乐笔记
  static const IconData musicNote = Icons.music_note_outlined;

  /// 音乐关闭
  static const IconData musicOff = Icons.music_off_outlined;

  /// 电影
  static const IconData movie = Icons.movie_outlined;

  /// 电影创作
  static const IconData movieCreation = Icons.movie_creation_rounded;

  /// 播放圆形轮廓
  static const IconData playCircleOutline = Icons.play_circle_outline_rounded;

  /// 播放圆形填充
  static const IconData playCircleFill = Icons.play_circle_fill_rounded;

  /// 停止圆形
  static const IconData stopCircle = Icons.stop_circle_rounded;

  /// 重放
  static const IconData replay = Icons.replay_rounded;

  /// 录音
  static const IconData recordVoiceOver = Icons.record_voice_over;

  /// 录音轮廓
  static const IconData recordVoiceOverOutline = Icons.record_voice_over_outlined;

  /// 速度
  static const IconData speed = Icons.speed;

  /// 歌词
  static const IconData lyrics = Icons.lyrics_outlined;

  /// 封闭字幕
  static const IconData closedCaption = Icons.closed_caption;

  /// 耳机
  static const IconData headphones = Icons.headphones;

  /// 相机
  static const IconData cameraAlt = Icons.camera_alt_outlined;

  /// 照片库
  static const IconData photoLibrary = Icons.photo_library_rounded;

  /// 照片相机
  static const IconData photoCamera = Icons.photo_camera_rounded;

  /// 音频文件
  static const IconData audioFile = Icons.audio_file;

  /// 键盘语音
  static const IconData keyboardVoice = Icons.keyboard_voice;

  /// 文本字段
  static const IconData textFields = Icons.text_fields_rounded;

  /// 短文本
  static const IconData shortText = Icons.short_text;

  /// 均衡器
  static const IconData equalizer = Icons.equalizer_rounded;

  /// 字幕轮廓
  static const IconData subtitlesOutline = Icons.subtitles_outlined;

  // ============================================================
  // 文件图标
  // ============================================================

  /// 文件夹
  static const IconData folder = Icons.folder_outlined;

  /// 文件夹打开
  static const IconData folderOpen = Icons.folder_open_outlined;

  /// 文件
  static const IconData insertDriveFile = Icons.insert_drive_file_outlined;

  /// 文档
  static const IconData description = Icons.description_outlined;

  /// 图片
  static const IconData image = Icons.image_outlined;

  /// 压缩包
  static const IconData zipFile = Icons.folder_zip_outlined;

  /// 文章
  static const IconData article = Icons.article_outlined;

  /// 菜单书
  static const IconData menuBook = Icons.menu_book_outlined;

  /// 图书
  static const IconData book = Icons.book_outlined;

  /// 图书馆
  static const IconData libraryBooks = Icons.library_books_outlined;

  /// 收据
  static const IconData receiptLong = Icons.receipt_long_outlined;

  /// 自动故事
  static const IconData autoStories = Icons.auto_stories;

  /// 文章（圆角）
  static const IconData articleRound = Icons.article_rounded;

  // ============================================================
  // 状态图标
  // ============================================================

  /// 收藏/喜欢
  static const IconData favorite = Icons.favorite_rounded;

  /// 未收藏/不喜欢
  static const IconData favoriteBorder = Icons.favorite_border_rounded;

  /// 星标
  static const IconData star = Icons.star_rounded;

  /// 空星标
  static const IconData starBorder = Icons.star_border_rounded;

  /// 半星标
  static const IconData starHalf = Icons.star_half_rounded;

  /// 星标轮廓
  static const IconData starOutline = Icons.star_outline_rounded;

  /// 可见
  static const IconData visibility = Icons.visibility_outlined;

  /// 不可见
  static const IconData visibilityOff = Icons.visibility_off_rounded;

  /// 锁定
  static const IconData lock = Icons.lock_outlined;

  /// 解锁
  static const IconData lockOpen = Icons.lock_open_outlined;

  /// 警告
  static const IconData warning = Icons.warning_amber_rounded;

  /// 错误
  static const IconData error = Icons.error_outline_rounded;

  /// 信息
  static const IconData info = Icons.info_outline_rounded;

  /// 帮助
  static const IconData help = Icons.help_outline_rounded;

  /// 检查圆圈
  static const IconData checkCircle = Icons.check_circle;

  /// 检查圆圈轮廓
  static const IconData checkCircleOutline = Icons.check_circle_outline;

  /// 复选框
  static const IconData checkBox = Icons.check_box_rounded;

  /// 复选框空白
  static const IconData checkBoxOutlineBlank = Icons.check_box_outline_blank_rounded;

  /// 单选按钮未选中
  static const IconData radioButtonUnchecked = Icons.radio_button_unchecked;

  /// 趋势上升
  static const IconData trendingUp = Icons.trending_up;

  /// 书签边框
  static const IconData bookmarkBorder = Icons.bookmark_border;

  /// 书签填充
  static const IconData bookmarkFill = Icons.bookmark_rounded;

  /// 旗帜
  static const IconData flag = Icons.flag;

  /// 破损图片
  static const IconData brokenImage = Icons.broken_image_outlined;

  /// 提示更新
  static const IconData tipsAndUpdates = Icons.tips_and_updates;

  /// 灯泡
  static const IconData lightbulb = Icons.lightbulb;

  /// 灯泡轮廓
  static const IconData lightbulbOutline = Icons.lightbulb_outline_rounded;

  /// 安全
  static const IconData security = Icons.security;

  /// 盾牌
  static const IconData shield = Icons.shield;

  /// 本地火灾
  static const IconData localFireDepartment = Icons.local_fire_department_rounded;

  // ============================================================
  // 用户相关图标
  // ============================================================

  /// 用户
  static const IconData person = Icons.person_outline_rounded;

  /// 用户（填充）
  static const IconData personFill = Icons.person_rounded;

  /// 用户组
  static const IconData group = Icons.group_outlined;

  /// 退出登录
  static const IconData logout = Icons.logout_rounded;

  /// 登录
  static const IconData login = Icons.login_rounded;

  /// 人群
  static const IconData people = Icons.people;

  /// 人群轮廓
  static const IconData peopleOutline = Icons.people_outline;

  /// 管理账户
  static const IconData manageAccounts = Icons.manage_accounts_outlined;

  /// 添加用户
  static const IconData personAddAlt = Icons.person_add_alt;

  // ============================================================
  // 主页/标签栏图标
  // ============================================================

  /// 首页/主页
  static const IconData home = Icons.home_outlined;

  /// 首页（选中）
  static const IconData homeFill = Icons.home_rounded;

  /// 发现/探索
  static const IconData explore = Icons.explore_outlined;

  /// 发现（选中）
  static const IconData exploreFill = Icons.explore_rounded;

  /// 学习
  static const IconData school = Icons.school_outlined;

  /// 学习（选中）
  static const IconData schoolFill = Icons.school_rounded;

  /// 个人中心
  static const IconData accountCircle = Icons.account_circle_outlined;

  /// 个人中心（选中）
  static const IconData accountCircleFill = Icons.account_circle_rounded;

  // ============================================================
  // 网络/连接图标
  // ============================================================

  /// WiFi
  static const IconData wifi = Icons.wifi_rounded;

  /// 断开连接
  static const IconData wifiOff = Icons.wifi_off_rounded;

  /// 云上传
  static const IconData cloudUpload = Icons.cloud_upload_outlined;

  /// 云下载
  static const IconData cloudDownload = Icons.cloud_download_outlined;

  /// 同步
  static const IconData sync = Icons.sync_rounded;

  /// WiFi热点
  static const IconData wifiTethering = Icons.wifi_tethering_outlined;

  /// WiFi热点关闭
  static const IconData wifiTetheringOff = Icons.wifi_tethering_off_rounded;

  /// 云关闭
  static const IconData cloudOff = Icons.cloud_off_outlined;

  /// HTTP
  static const IconData http = Icons.http;

  /// 链接
  static const IconData link = Icons.link_rounded;

  /// GPS定位
  static const IconData gpsFixed = Icons.gps_fixed;

  /// 网线
  static const IconData cable = Icons.cable;

  /// DNS
  static const IconData dns = Icons.dns;

  /// 邮箱
  static const IconData email = Icons.email_outlined;

  /// 替代邮件
  static const IconData alternateEmail = Icons.alternate_email_rounded;

  // ============================================================
  // 时间/日期图标
  // ============================================================

  /// 时钟/时间
  static const IconData schedule = Icons.schedule_rounded;

  /// 日历
  static const IconData calendarToday = Icons.calendar_today_rounded;

  /// 日期范围
  static const IconData dateRange = Icons.date_range_rounded;

  /// 历史
  static const IconData history = Icons.history_rounded;

  /// 计时器
  static const IconData timer = Icons.timer_outlined;

  /// 访问时间
  static const IconData accessTime = Icons.access_time_rounded;

  /// 历史切换关闭
  static const IconData historyToggleOff = Icons.history_toggle_off_rounded;

  // ============================================================
  // 文件操作图标
  // ============================================================

  /// 导入
  static const IconData fileDownload = Icons.file_download_outlined;

  /// 导出
  static const IconData fileUpload = Icons.file_upload_outlined;

  /// 创建新文件夹
  static const IconData createNewFolder = Icons.create_new_folder_outlined;

  /// 重命名
  static const IconData driveFileRename = Icons.drive_file_rename_outline_rounded;

  // ============================================================
  // 对话图标
  // ============================================================

  /// 问答
  static const IconData quiz = Icons.quiz_outlined;

  /// 论坛
  static const IconData forum = Icons.forum_outlined;

  /// 聊天气泡
  static const IconData chatBubbleOutline = Icons.chat_bubble_outline;

  /// 聊天
  static const IconData chat = Icons.chat_outlined;

  /// 评论
  static const IconData comment = Icons.comment;

  /// 智能机器人
  static const IconData smartToy = Icons.smart_toy;

  /// 发送
  static const IconData send = Icons.send_rounded;

  // ============================================================
  // 评测图标
  // ============================================================

  /// 奖杯
  static const IconData emojiEvents = Icons.emoji_events;

  /// 规则
  static const IconData rule = Icons.rule_outlined;

  /// 分析
  static const IconData analytics = Icons.analytics_rounded;

  /// 展示图表
  static const IconData showChart = Icons.show_chart_rounded;

  /// 数字1
  static const IconData looksOne = Icons.looks_one;

  /// 数字2
  static const IconData looksTwo = Icons.looks_two;

  /// 数字3
  static const IconData looksThree = Icons.looks_3;

  /// 数字4
  static const IconData looksFour = Icons.looks_4;

  /// 数字5
  static const IconData looksFive = Icons.looks_5;

  /// 竖大拇指
  static const IconData thumbUp = Icons.thumb_up_outlined;

  /// 倒大拇指
  static const IconData thumbDown = Icons.thumb_down_outlined;

  /// 非常满意
  static const IconData sentimentVerySatisfied = Icons.sentiment_very_satisfied;

  /// 非常不满意
  static const IconData sentimentVeryDissatisfied = Icons.sentiment_very_dissatisfied;

  /// 满意
  static const IconData sentimentSatisfied = Icons.sentiment_satisfied;

  /// 中立
  static const IconData sentimentNeutral = Icons.sentiment_neutral;

  /// 不满意
  static const IconData sentimentDissatisfied = Icons.sentiment_dissatisfied;

  /// 心理学
  static const IconData psychology = Icons.psychology_rounded;

  /// 工作空间高级
  static const IconData workspacePremium = Icons.workspace_premium;

  /// 麦克风
  static const IconData recordVoice = Icons.record_voice_over;

  // ============================================================
  // 单词本图标
  // ============================================================

  /// 翻译
  static const IconData translate = Icons.translate_outlined;

  /// 语言
  static const IconData language = Icons.language;

  /// 拼写检查
  static const IconData spellcheck = Icons.spellcheck;

  // ============================================================
  // 设置图标
  // ============================================================

  /// 调整
  static const IconData tune = Icons.tune_rounded;

  /// 亮色模式
  static const IconData lightMode = Icons.light_mode_outlined;

  /// 暗色模式
  static const IconData darkMode = Icons.dark_mode_outlined;

  /// 亮度自动
  static const IconData brightnessAuto = Icons.brightness_auto_outlined;

  /// 调色板
  static const IconData palette = Icons.palette_outlined;

  /// 彩色镜头
  static const IconData colorLens = Icons.color_lens_rounded;

  /// 显示
  static const IconData display = Icons.desktop_mac_outlined;

  /// 账户钱包
  static const IconData accountBalanceWallet = Icons.account_balance_wallet_outlined;

  // ============================================================
  // 获取图标的便捷方法
  // ============================================================

  /// 获取图标
  ///
  /// [iconData] 图标数据
  /// [size] 图标大小，默认24
  /// [color] 图标颜色
  static Icon getIcon(IconData iconData, {double size = 24, Color? color}) {
    return Icon(iconData, size: size.w, color: color);
  }

  /// 获取填充图标
  ///
  /// 将非填充图标转换为对应的填充版本
  /// [iconData] 非填充图标
  /// [size] 图标大小，默认24
  /// [color] 图标颜色
  static Icon getFilledIcon(IconData iconData, {double size = 24, Color? color}) {
    return Icon(_toFilledIcon(iconData), size: size, color: color);
  }

  /// 将非填充图标转换为填充版本
  static IconData _toFilledIcon(IconData icon) {
    // 导航类
    if (icon == arrowBack) return Icons.arrow_back;
    if (icon == arrowForward) return Icons.arrow_forward;
    if (icon == expandMore) return Icons.expand_more;
    if (icon == expandLess) return Icons.expand_less;
    if (icon == menu) return Icons.menu;
    if (icon == close) return Icons.close;
    if (icon == check) return Icons.check;

    // 操作类
    if (icon == add) return Icons.add;
    if (icon == delete) return Icons.delete;
    if (icon == settings) return Icons.settings;
    if (icon == search) return Icons.search;
    if (icon == refresh) return Icons.refresh;

    // 媒体类
    if (icon == play) return Icons.play_arrow;
    if (icon == pause) return Icons.pause;
    if (icon == stop) return Icons.stop;
    if (icon == subtitles) return Icons.subtitles;
    if (icon == videoLibrary) return Icons.video_library;

    // 用户类
    if (icon == person) return Icons.person;
    if (icon == accountCircle) return Icons.account_circle;

    // 主页类
    if (icon == home) return Icons.home;
    if (icon == explore) return Icons.explore;
    if (icon == school) return Icons.school;

    return icon;
  }
}

// ============================================================
// PNG图标定义（特殊情况下使用）
// ============================================================

/// PNG图标资产路径
class PngIcons {
  PngIcons._();

  // ============================================================
  // Logo图标
  // ============================================================

  /// 应用Logo
  static const String appLogo = 'assets/icons/app_logo.png';

  /// 启动页Logo
  static const String splashLogo = 'assets/icons/splash_logo.png';

  // ============================================================
  // 空状态图标
  // ============================================================

  /// 空文件夹
  static const String emptyFolder = 'assets/icons/empty_folder.png';

  /// 空列表
  static const String emptyList = 'assets/icons/empty_list.png';

  /// 空搜索结果
  static const String emptySearch = 'assets/icons/empty_search.png';

  // ============================================================
  // 状态图标
  // ============================================================

  /// 加载中
  static const String loading = 'assets/icons/loading.png';

  /// 错误状态
  static const String errorState = 'assets/icons/error_state.png';

  /// 成功状态
  static const String successState = 'assets/icons/success_state.png';

  /// 网络错误
  static const String networkError = 'assets/icons/network_error.png';

  // ============================================================
  // 获取PNG图标组件
  // ============================================================

  /// 获取PNG图标
  ///
  /// [pngPath] PNG资产路径
  /// [width] 图标宽度
  /// [height] 图标高度
  /// [color] 图标颜色（会覆盖图片颜色）
  static Widget getPngIcon(String pngPath, {double? width, double? height, Color? color}) {
    return Image.asset(
      pngPath,
      width: width,
      height: height,
      color: color,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Icon(Icons.broken_image_outlined, size: width ?? 24, color: Colors.grey);
      },
    );
  }
}

/// 三类资源的图标（Hugeicons 统一入口）
///
/// 集中管理文件夹级和单资源级的图标映射，
/// 未来如需替换图标集只需改此处。
abstract final class ResourceIcons {
  // ─── 文件夹（合集）图标 ─────────────────────
  static const folderVideo = HugeIcons.strokeRoundedFolderVideo;
  static const folderArticle = HugeIcons.strokeRoundedBookOpenText;
  static const folderAudio = HugeIcons.strokeRoundedFolderMusic;

  // ─── 单资源图标 ────────────────────────────
  static const itemVideo = HugeIcons.strokeRoundedFileVideo;
  static const itemArticle = HugeIcons.strokeRoundedNote02;
  static const itemAudio = HugeIcons.strokeRoundedFileMusic;

  /// 根据类型取文件夹图标
  static const Map<String, List<List<dynamic>>> _folderIcons = {
    'video': folderVideo,
    'article': folderArticle,
    'music': folderAudio,
  };

  /// 根据类型取单资源图标
  static const Map<String, List<List<dynamic>>> _itemIcons = {
    'video': itemVideo,
    'article': itemArticle,
    'music': itemAudio,
  };

  /// 获取类型对应的文件夹图标
  static List<List<dynamic>> folderIconFor(String type) => _folderIcons[type] ?? folderVideo;

  /// 获取类型对应的单资源图标
  static List<List<dynamic>> itemIconFor(String type) => _itemIcons[type] ?? itemVideo;

  // ─── 卡片展示图标（Material Icons） ──────────
  static const IconData displayVideo = Icons.movie;
  static const IconData displayArticle = Icons.menu_book;
  static const IconData displayAudio = Icons.music_note;

  /// 根据类型取卡片展示图标
  static const Map<String, IconData> _displayIcons = {
    'video': displayVideo,
    'article': displayArticle,
    'music': displayAudio,
  };

  static IconData displayIconFor(String type) => _displayIcons[type] ?? displayVideo;

  /// 助记标签文案
  static String unitLabel(String type) {
    switch (type) {
      case 'article':
        return '篇';
      case 'music':
        return '首';
      default:
        return '集';
    }
  }
}
