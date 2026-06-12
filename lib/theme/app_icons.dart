/// 图标系统
///
/// 统一管理应用中使用的所有图标，包括：
/// - Flutter内置Material Icons
/// - 自定义PNG图标（特殊情况下使用）
///
/// 图标分类：
/// - Navigation icons（导航图标）
/// - Action icons（操作图标）
/// - Media icons（媒体图标）
/// - File icons（文件图标）
/// - Status icons（状态图标）
/// - Custom icons（自定义PNG图标）
///
/// 使用方式：
/// ```dart
/// // 使用Flutter内置图标
/// AppIcons.getIcon(AppIcons.videoLibrary)
///
/// // 或直接使用Icon类
/// Icon(AppIcons.videoLibrary)
///
/// // 自定义PNG图标
/// AppIcons.getPngIcon(AppIcons.logo)
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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

  // ============================================================
  // 操作图标
  // ============================================================

  /// 添加
  static const IconData add = Icons.add_rounded;

  /// 删除
  static const IconData delete = Icons.delete_outline_rounded;

  /// 编辑/修改
  static const IconData edit = Icons.edit_outlined;

  /// 分享
  static const IconData share = Icons.share_outlined;

  /// 更多
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

  /// 静音
  static const IconData volumeOff = Icons.volume_off_rounded;

  /// 全屏
  static const IconData fullscreen = Icons.fullscreen_rounded;

  /// 退出全屏
  static const IconData fullscreenExit = Icons.fullscreen_exit_rounded;

  /// 字幕
  static const IconData subtitles = Icons.subtitles_rounded;

  /// 音频
  static const IconData audioTrack = Icons.audiotrack_rounded;

  /// 视频
  static const IconData video = Icons.videocam_outlined;

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

  // ============================================================
  // 文件图标
  // ============================================================

  /// 文件夹
  static const IconData folder = Icons.folder_outlined;

  /// 文件
  static const IconData insertDriveFile = Icons.insert_drive_file_outlined;

  /// 文档
  static const IconData description = Icons.description_outlined;

  /// 图片
  static const IconData image = Icons.image_outlined;

  /// 压缩包
  static const IconData zipFile = Icons.folder_zip_outlined;

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

  /// 可见
  static const IconData visibility = Icons.visibility_rounded;

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
