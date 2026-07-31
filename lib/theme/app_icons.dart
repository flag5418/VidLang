/// 图标系统
///
/// 统一管理应用中使用的所有图标，基于 TDesign Icons (TDIcons)。
/// - 官方文档: https://tdesign.tencent.com/flutter/components/icon
/// - 图标数量: 2114+
/// - 风格: Material rounded 线性风格（与 TDesign 组件库完全统一）
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
/// // 使用 TDesign 图标
/// Icon(AppIcons.home)
/// Icon(AppIcons.play, size: 24, color: Colors.blue)
///
/// // 获取便捷方法
/// AppIcons.getIcon(AppIcons.videoLibrary)
/// ```
library;

import 'package:flutter/painting.dart' show Color, BoxFit;
import 'package:flutter/widgets.dart' show Widget, Icon, Image, IconData;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:hugeicons/hugeicons.dart';

/// 应用图标类
///
/// 包含所有图标定义，提供统一的访问接口。
/// 所有图标均来自 TDesign TDIcons，确保视觉风格统一。
class AppIcons {
  AppIcons._();

  // ============================================================
  // 导航图标
  // ============================================================

  /// 返回/后退
  static const IconData arrowBack = TDIcons.arrow_left;

  /// 前进
  static const IconData arrowForward = TDIcons.arrow_right;

  /// 展开更多
  static const IconData expandMore = TDIcons.chevron_down;

  /// 收起
  static const IconData expandLess = TDIcons.chevron_up;

  /// 菜单
  static const IconData menu = TDIcons.menu;

  /// 关闭
  static const IconData close = TDIcons.close;

  /// 检查
  static const IconData check = TDIcons.check;

  /// 右箭头
  static const IconData chevronRight = TDIcons.chevron_right;

  /// 左箭头（iOS风格）
  static const IconData arrowBackIos = TDIcons.arrow_left;

  /// 左箭头（iOS新风格）
  static const IconData arrowBackIosNew = TDIcons.arrow_left;

  /// 取消
  static const IconData cancel = TDIcons.close_circle;

  /// 上箭头
  static const IconData arrowUpward = TDIcons.arrow_up;

  /// 下箭头
  static const IconData arrowDownward = TDIcons.arrow_down;

  /// 键盘上箭头
  static const IconData keyboardArrowUp = TDIcons.caret_up;

  /// 键盘下箭头
  static const IconData keyboardArrowDown = TDIcons.caret_down;

  // ============================================================
  // 操作图标
  // ============================================================

  /// 添加
  static const IconData add = TDIcons.add;

  /// 添加圆形轮廓
  static const IconData addCircleOutline = TDIcons.add_circle;

  /// 删除
  static const IconData delete = TDIcons.delete;

  /// 永久删除
  static const IconData deleteForever = TDIcons.delete;

  /// 批量删除
  static const IconData deleteSweep = TDIcons.delete;

  /// 编辑/修改
  static const IconData edit = TDIcons.edit;

  /// 分享
  static const IconData share = TDIcons.share;

  /// 更多（纵向）
  static const IconData moreVert = TDIcons.more;

  /// 更多（横向）
  static const IconData moreHoriz = TDIcons.ellipsis;

  /// 设置
  static const IconData settings = TDIcons.setting;

  /// 搜索
  static const IconData search = TDIcons.search;

  /// 刷新
  static const IconData refresh = TDIcons.refresh;

  /// 筛选
  static const IconData filter = TDIcons.filter;

  /// 复制
  static const IconData copy = TDIcons.copy;

  /// 下载
  static const IconData download = TDIcons.download;

  /// 上传
  static const IconData upload = TDIcons.upload;

  /// 保存
  static const IconData save = TDIcons.save;

  /// 清除
  static const IconData clear = TDIcons.clear;

  /// 移除
  static const IconData remove = TDIcons.remove;

  /// 列表
  static const IconData list = TDIcons.list;

  /// 钉钉
  static const IconData pushPin = TDIcons.pin;

  /// 仪表盘
  static const IconData dashboard = TDIcons.dashboard;

  /// 档案
  static const IconData assignment = TDIcons.assignment;

  /// 应用
  static const IconData apps = TDIcons.app;
  static const IconData appsRound = TDIcons.app_filled;

  // ============================================================
  // 媒体图标
  // ============================================================

  /// 播放
  static const IconData play = TDIcons.play;

  /// 暂停
  static const IconData pause = TDIcons.pause;

  /// 停止
  static const IconData stop = TDIcons.stop;

  /// 上一首
  static const IconData skipPrevious = TDIcons.previous;

  /// 下一首
  static const IconData skipNext = TDIcons.next;

  /// 全屏
  static const IconData fullscreen = TDIcons.fullscreen;

  /// 退出全屏
  static const IconData fullscreenExit = TDIcons.fullscreen_exit;

  /// 字幕
  static const IconData subtitles = TDIcons.subtitle;
  static const IconData subtitlesOutline = TDIcons.subtitle;

  /// 音频
  static const IconData audioTrack = TDIcons.audio;

  /// 视频
  static const IconData video = TDIcons.video;

  /// 摄像机
  static const IconData videocam = TDIcons.camera;

  /// 音乐笔记
  static const IconData musicNote = TDIcons.audio;

  /// 耳机
  static const IconData headphones = TDIcons.earphone;

  /// 相机
  static const IconData cameraAlt = TDIcons.camera;

  /// 照片库
  static const IconData photoLibrary = TDIcons.browse_gallery;

  /// 音频文件
  static const IconData audioFile = TDIcons.file_music;

  /// 电影
  static const IconData movie = TDIcons.film; // 使用 film 作为替代

  /// 影片
  static const IconData film = TDIcons.film;

  // ============================================================
  // 文件图标
  // ============================================================

  /// 文件夹
  static const IconData folder = TDIcons.folder;

  /// 文件夹打开
  static const IconData folderOpen = TDIcons.folder_open;

  /// 文件
  static const IconData insertDriveFile = TDIcons.file;

  /// 图片
  static const IconData image = TDIcons.image;

  /// 压缩包
  static const IconData zipFile = TDIcons.file_zip;

  /// 文章
  static const IconData article = TDIcons.article;
  static const IconData articleRound = TDIcons.article_filled;

  /// 菜单书
  static const IconData menuBook = TDIcons.book_open;

  /// 图书
  static const IconData book = TDIcons.book;

  // ============================================================
  // 状态图标
  // ============================================================

  /// 收藏/喜欢（填充）
  static const IconData favorite = TDIcons.heart_filled;

  /// 未收藏/不喜欢（轮廓）
  static const IconData favoriteBorder = TDIcons.heart;

  /// 星标（填充）
  static const IconData star = TDIcons.star_filled;

  /// 空星标（轮廓）
  static const IconData starBorder = TDIcons.star;
  static const IconData starOutline = TDIcons.star;

  /// 可见
  static const IconData visibility = TDIcons.browse;

  /// 不可见
  static const IconData visibilityOff = TDIcons.browse_off;

  /// 错误
  static const IconData error = TDIcons.error;
  static const IconData errorState = TDIcons.error_circle;

  /// 警告 - 使用 error_circle 作为替代（TDesign无专用warning图标）
  static const IconData warning = TDIcons.error_circle;

  /// 信息 - 使用 info_circle
  static const IconData info = TDIcons.info_circle;

  /// 帮助
  static const IconData help = TDIcons.help;

  /// 检查圆圈（填充）
  static const IconData checkCircle = TDIcons.check_circle_filled;

  /// 检查圆圈（轮廓）
  static const IconData checkCircleOutline = TDIcons.check_circle;

  /// 书签边框
  static const IconData bookmarkBorder = TDIcons.bookmark;

  /// 书签填充
  static const IconData bookmarkFill = TDIcons.bookmark_filled;

  /// 旗帜
  static const IconData flag = TDIcons.flag;

  /// 安全 - 使用认证/验证图标
  static const IconData security = TDIcons.verified;
  static const IconData shield = TDIcons.verified;

  /// 趋势上升
  static const IconData trendingUp = TDIcons.trending_up;

  // ============================================================
  // 用户相关图标
  // ============================================================

  /// 用户（轮廓）
  static const IconData person = TDIcons.user;

  /// 用户（填充）
  static const IconData personFill = TDIcons.user_filled;

  /// 退出登录
  static const IconData logout = TDIcons.logout;

  /// 登录
  static const IconData login = TDIcons.login;

  // ============================================================
  // 主页/标签栏图标
  // ============================================================

  /// 首页/主页（轮廓）
  static const IconData home = TDIcons.home;

  /// 首页（选中/填充）
  static const IconData homeFill = TDIcons.home_filled;

  /// 发现/探索（轮廓）
  static const IconData explore = TDIcons.explore;

  /// 发现（选中/填充）
  static const IconData exploreFill = TDIcons.explore_filled;

  /// 学习（轮廓）- 使用 education 图标更贴切
  static const IconData school = TDIcons.education;

  /// 学习（选中/填充）
  static const IconData schoolFill = TDIcons.education_filled;

  /// 个人中心（轮廓）
  static const IconData accountCircle = TDIcons.user;

  /// 个人中心（选中/填充）
  static const IconData accountCircleFill = TDIcons.user_filled;

  // ============================================================
  // 网络/连接图标
  // ============================================================

  /// WiFi
  static const IconData wifi = TDIcons.wifi;

  /// 断开连接
  static const IconData wifiOff = TDIcons.wifi_off;

  /// 云上传
  static const IconData cloudUpload = TDIcons.cloud_upload;

  /// 云下载
  static const IconData cloudDownload = TDIcons.cloud_download;

  /// 云
  static const IconData cloud = TDIcons.cloud;

  /// 链接
  static const IconData link = TDIcons.link;

  /// GPS定位
  static const IconData gpsFixed = TDIcons.gps;

  /// 地球
  static const IconData earth = TDIcons.earth;

  /// 邮箱
  static const IconData email = TDIcons.mail;

  // ============================================================
  // 时间/日期图标
  // ============================================================

  /// 日历
  static const IconData calendarToday = TDIcons.calendar;

  /// 历史
  static const IconData history = TDIcons.history;

  /// 时钟/时间 - 使用 time 或 clock
  static const IconData schedule = TDIcons.time;
  static const IconData accessTime = TDIcons.time;

  // ============================================================
  // 文件操作图标
  // ============================================================

  /// 导入
  static const IconData fileDownload = TDIcons.file_download;

  /// 导出
  static const IconData fileUpload = TDIcons.file_export;

  /// 创建新文件夹
  static const IconData createNewFolder = TDIcons.folder_add;

  // ============================================================
  // 对话图标
  // ============================================================

  /// 聊天气泡
  static const IconData chatBubbleOutline = TDIcons.chat_bubble;

  /// 聊天
  static const IconData chat = TDIcons.chat;

  /// 发送
  static const IconData send = TDIcons.send;

  /// 翻译
  static const IconData translate = TDIcons.translate;

  // ============================================================
  // 评测图标
  // ============================================================

  /// 分析
  static const IconData analytics = TDIcons.analytics;

  /// 展示图表
  static const IconData showChart = TDIcons.chart;

  /// 竖大拇指
  static const IconData thumbUp = TDIcons.thumb_up;

  /// 倒大拇指
  static const IconData thumbDown = TDIcons.thumb_down;

  /// 非常满意
  static const IconData sentimentVerySatisfied = TDIcons.smile_filled;

  /// 非常不满意 - 使用愤怒表情（TDesign无cry/disappointment）
  static const IconData sentimentVeryDissatisfied = TDIcons.angry;

  /// 满意
  static const IconData sentimentSatisfied = TDIcons.smile;

  /// 中立 - 使用中性表情（TDesign无neutral）
  static const IconData sentimentNeutral = TDIcons.smile;

  /// 不满意 - 使用一般不满表情（TDesign无dissatisfied）
  static const IconData sentimentDissatisfied = TDIcons.angry;

  /// 奖杯/礼品
  static const IconData emojiEvents = TDIcons.gift_filled;

  // ============================================================
  // 媒体和列表图标补充
  // ============================================================

  /// 无序列表/项目符号 - 使用 list（TDesign无formatListBulleted）
  static const IconData formatListBulleted = TDIcons.list;

  /// 电影创作 - 使用 video 或 film（TDesign无movieCreation）
  static const IconData movieCreation = TDIcons.video;

  // ============================================================
  // 设置图标
  // ============================================================

  /// 调整
  static const IconData tune = TDIcons.adjustment;

  /// 亮色模式 - 使用 sunny 图标（TDesign无light_mode/sun_filled）
  static const IconData lightMode = TDIcons.sunny;

  /// 暗色模式
  static const IconData darkMode = TDIcons.moon_filled;

  /// 亮度自动 - 使用 brightness 图标
  static const IconData brightnessAuto = TDIcons.brightness;

  /// 调色板
  static const IconData palette = TDIcons.palette;

  /// 显示/桌面
  static const IconData display = TDIcons.desktop;

  /// 账户钱包
  static const IconData accountBalanceWallet = TDIcons.wallet;

  /// 亮度
  static const IconData brightness = TDIcons.brightness;

  // ============================================================
  // 难度等级图标
  // ============================================================

  /// 入门 - 微笑，表示友好简单
  static const IconData levelBeginner = TDIcons.smile;

  /// 初级 - 星星，表示开始进阶
  static const IconData levelElementary = TDIcons.star;

  /// 中级 - 点赞，表示不错
  static const IconData levelIntermediate = TDIcons.thumb_up;

  /// 高级 - 奖杯/成就
  static const IconData levelAdvanced = TDIcons.gift_filled;

  /// 专业 - VIP/皇冠，表示专业
  static const IconData levelProfessional = TDIcons.user_vip;

  // ============================================================
  // 媒体控制补充图标
  // ============================================================

  /// 速度/倍速 - 使用 speed 或 time 图标
  static const IconData speed = TDIcons.time;

  /// 录音 - 使用 microphone 图标
  static const IconData recordVoiceOver = TDIcons.microphone;

  /// 麦克风
  static const IconData mic = TDIcons.microphone;

  /// 麦克风（圆角）- 使用 microphone_filled
  static const IconData micRounded = TDIcons.microphone_filled;

  /// 麦克风（无）- 使用 microphone（TDesign无microphone_off）
  static const IconData micNone = TDIcons.microphone;

  /// 音量增大 - 使用 sound 图标（TDesign无volume）
  static const IconData volumeUp = TDIcons.sound;

  /// 音量降低 - 使用 sound 图标
  static const IconData volumeDown = TDIcons.sound;

  /// 静音 - 使用 sound_mute
  static const IconData volumeOff = TDIcons.sound_mute;

  /// 停止圆形 - 使用 stop_circle
  static const IconData stopCircle = TDIcons.stop_circle;

  /// 播放圆形填充 - 使用 play_circle_filled
  static const IconData playCircleFill = TDIcons.play_circle_filled;

  /// 播放圆形轮廓 - 使用 play_circle
  static const IconData playCircleOutline = TDIcons.play_circle;

  /// 循环播放 - 使用 anticlockwise（TDesign无repeat）
  static const IconData repeat = TDIcons.anticlockwise;

  /// 单曲循环 - 使用 anticlockwise_filled
  static const IconData repeatOne = TDIcons.anticlockwise_filled;

  /// 随机播放 - 使用 swap（TDesign无shuffle）
  static const IconData shuffle = TDIcons.swap;

  /// 快退 - 使用 previous
  static const IconData rewind = TDIcons.previous;

  /// 快进 - 使用 next
  static const IconData fastForward = TDIcons.next;

  /// 歌词 - 使用 subtitle
  static const IconData lyrics = TDIcons.subtitle;

  /// 封闭字幕 - 使用 subtitle
  static const IconData closedCaption = TDIcons.subtitle;

  /// 字幕关闭 - 使用 close_circle（TDesign无subtitle_off）
  static const IconData subtitlesOff = TDIcons.close_circle;

  /// 重放 - 使用 refresh
  static const IconData replay = TDIcons.refresh;

  // ============================================================
  // 文本和编辑图标
  // ============================================================

  /// 文本字段 - 使用 edit（TDesign无text_format）
  static const IconData textFields = TDIcons.edit;

  /// 短文本 - 使用 edit
  static const IconData shortText = TDIcons.edit;

  /// 灯泡 - 使用 lightbulb
  static const IconData lightbulb = TDIcons.lightbulb;

  /// 灯泡轮廓 - 使用 lightbulb
  static const IconData lightbulbOutline = TDIcons.lightbulb;

  /// 彩色镜头 - 使用 palette
  static const IconData colorLens = TDIcons.palette;

  /// 自动填充/AI - 使用 star（TDesign无star_1/sparkle）
  static const IconData autoAwesome = TDIcons.star;

  /// 提示更新 - 使用 tips 或 info
  static const IconData tipsAndUpdates = TDIcons.info_circle;

  /// 本地火灾 - 使用 fire 或 trending_up
  static const IconData localFireDepartment = TDIcons.trending_up;

  /// 破损图片 - 使用 error
  static const IconData brokenImage = TDIcons.error;

  // ============================================================
  // 其他实用图标
  // ============================================================

  /// 礼品
  static const IconData gift = TDIcons.gift;

  /// 卡片
  static const IconData card = TDIcons.card;

  /// 商店
  static const IconData shop = TDIcons.shop;

  /// 购物车/测试篮 - 使用 shop 图标
  static const IconData shoppingCart = TDIcons.shop;

  /// 标签
  static const IconData tag = TDIcons.tag;

  /// 通知
  static const IconData notification = TDIcons.notification;

  /// 位置
  static const IconData location = TDIcons.location;

  /// 服务器
  static const IconData server = TDIcons.server;

  /// 笔记本/电脑
  static const IconData laptop = TDIcons.laptop;

  /// 电视
  static const IconData tv = TDIcons.tv;

  /// 地图
  static const IconData map = TDIcons.map;

  /// 指南针
  static const IconData compass = TDIcons.compass;

  /// 代码
  static const IconData code = TDIcons.code;

  /// 终端
  static const IconData terminal = TDIcons.terminal;

  /// 密钥
  static const IconData key = TDIcons.key;

  /// 图层 - 使用 chart_stacked（TDesign无stack/layers）
  static const IconData layers = TDIcons.chart_stacked;

  /// 排序 - 使用 filter_sort（TDesign无sort）
  static const IconData sort = TDIcons.filter_sort;

  /// 反馈 - 使用 chat_bubble（TDesign无comment）
  static const IconData feedback = TDIcons.chat_bubble;

  /// 分类 - 使用 category 或 app
  static const IconData category = TDIcons.app;

  /// 拖拽手柄 - 使用 component_grid（4点网格设计，更有拖拽感）
  static const IconData dragHandle = TDIcons.component_grid;

  /// 返回退格 - 使用 delete（TDesign无backspace）
  static const IconData backspace = TDIcons.delete;

  /// 自动修复 - 使用 setting（TDesign无tool）
  static const IconData autoFixHigh = TDIcons.setting;

  /// 有序列表 - 使用 view_list（TDesign无list_ordered）
  static const IconData formatListNumbered = TDIcons.view_list;

  /// 标签轮廓 - 使用 tag
  static const IconData labelOutline = TDIcons.tag;

  /// 应用（圆角）- 已在上面定义，此处删除重复定义
  // static const IconData appsRound = TDIcons.app_filled; // 重复，已删除

  /// 视频库 - 使用 video_library 或 video
  static const IconData videoLibrary = TDIcons.video;

  /// 播放列表 - 使用 playlist 或 list
  static const IconData playlistPlay = TDIcons.list;

  /// 播放列表添加 - 使用 add_circle
  static const IconData playlistAdd = TDIcons.add_circle;

  /// 锁定 - 使用 file_locked（TDesign无lock）
  static const IconData lock = TDIcons.file_locked;

  /// 解锁 - 使用 file_unlocked
  static const IconData lockOpen = TDIcons.file_unlocked;

  /// 同步 - 使用 refresh 或 sync
  static const IconData sync = TDIcons.refresh;

  /// WiFi热点 - 使用 wifi
  static const IconData wifiTethering = TDIcons.wifi;

  /// WiFi热点关闭 - 使用 wifi_off
  static const IconData wifiTetheringOff = TDIcons.wifi_off;

  /// 云关闭 - 使用 cloud（TDesign无cloud_off）
  static const IconData cloudOff = TDIcons.cloud;

  /// HTTP - 使用 link 或 server
  static const IconData http = TDIcons.server;

  /// 替代邮件 - 使用 mail
  static const IconData alternateEmail = TDIcons.mail;

  /// 日期范围 - 使用 calendar_2（TDesign无calendar_range）
  static const IconData dateRange = TDIcons.calendar_2;

  /// 计时器 - 使用 time（TDesign无timer）
  static const IconData timer = TDIcons.time;

  /// 历史切换关闭 - 使用 history 图标（原 close 图标语义不当）
  static const IconData historyToggleOff = TDIcons.history;

  /// 重命名 - 使用 edit
  static const IconData driveFileRename = TDIcons.edit;

  /// 问答 - 使用 help 或 question
  static const IconData quiz = TDIcons.help;

  /// 论坛 - 使用 forum 或 chat
  static const IconData forum = TDIcons.chat;

  /// 评论 - 使用 chat_bubble（TDesign无comment）
  static const IconData comment = TDIcons.chat_bubble;

  /// 智能机器人 - 使用 user_talk（TDesign无ai/robot）
  static const IconData smartToy = TDIcons.user_talk;

  /// 规则 - 使用 fact_check（TDesign无rule/document）
  static const IconData rule = TDIcons.fact_check;

  /// 数字1 - 使用 chart_bar（TDesign无numeric_x）
  static const IconData looksOne = TDIcons.chart_bar;

  /// 数字2 - 使用 chart_pie
  static const IconData looksTwo = TDIcons.chart_pie;

  /// 数字3 - 使用 chart_line
  static const IconData looksThree = TDIcons.chart_line;

  /// 数字4 - 使用 chart_bubble
  static const IconData looksFour = TDIcons.chart_bubble;

  /// 数字5 - 使用 chart_bubble（TDesign无chart_histogram）
  static const IconData looksFive = TDIcons.chart_bubble;

  /// 复选框 - 使用 component_checkbox（TDesign无checkbox）
  static const IconData checkBox = TDIcons.component_checkbox;

  /// 复选框空白 - 使用 check_rectangle（TDesign无checkbox_unchecked）
  static const IconData checkBoxOutlineBlank = TDIcons.check_rectangle;

  /// 单选按钮未选中 - 使用 component_radio（TDesign无radio_unchecked）
  static const IconData radioButtonUnchecked = TDIcons.component_radio;

  /// 管理账户 - 使用 user_setting
  static const IconData manageAccounts = TDIcons.user_setting;

  /// 添加用户 - 使用 user_add
  static const IconData personAddAlt = TDIcons.user_add;

  /// 用户组 - 使用 usergroup（TDesign无users）
  static const IconData group = TDIcons.usergroup;

  /// 人群 - 使用 usergroup
  static const IconData people = TDIcons.usergroup;

  /// 人群轮廓 - 使用 usergroup
  static const IconData peopleOutline = TDIcons.usergroup;

  /// 心理学 - 使用 user_safety（TDesign无brain/psychology）
  static const IconData psychology = TDIcons.user_safety;

  /// 工作空间高级 - 使用 user_vip（TDesign无crown）
  static const IconData workspacePremium = TDIcons.user_vip;

  /// 麦克风录音 - 使用 microphone
  static const IconData recordVoice = TDIcons.microphone;

  /// 语言 - 使用 language 或 translate
  static const IconData language = TDIcons.translate;

  /// 拼写检查 - 使用 spellcheck 或 check
  static const IconData spellcheck = TDIcons.check;

  /// 文档 - 使用 file_1（TDesign无document/file_text）
  static const IconData description = TDIcons.file_1;

  /// 图书馆 - 使用 library 或 book
  static const IconData libraryBooks = TDIcons.book_open;

  /// 收据 - 使用 file_1（TDesign无file_text）
  static const IconData receiptLong = TDIcons.file_1;

  /// 自动故事 - 使用 auto_stories 或 book
  static const IconData autoStories = TDIcons.book_open;

  /// 照片相机 - 使用 camera
  static const IconData photoCamera = TDIcons.camera;

  /// 键盘语音 - 使用 keyboard_voice 或 microphone
  static const IconData keyboardVoice = TDIcons.microphone;

  /// 均衡器 - 使用 equalizer 或 chart_bar
  static const IconData equalizer = TDIcons.chart_bar;

  /// 视图模块/网格布局
  static const IconData viewModule = TDIcons.view_module;

  /// 引用/引号格式 - TDesign 无 quote，使用 chat 替代
  static const IconData formatQuote = TDIcons.chat;

  /// 信号强度/难度等级
  static const IconData signalCellularAlt = TDIcons.chart_bar;

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
  ///
  /// TDesign 的填充版本通常以 _filled 后缀命名
  static IconData _toFilledIcon(IconData icon) {
    // 导航类
    if (icon == arrowBack) return TDIcons.arrow_left;
    if (icon == arrowForward) return TDIcons.arrow_right;
    if (icon == expandMore) return TDIcons.chevron_down;
    if (icon == expandLess) return TDIcons.chevron_up;
    if (icon == menu) return TDIcons.menu_filled;
    if (icon == close) return TDIcons.close;
    if (icon == check) return TDIcons.check;

    // 操作类
    if (icon == add) return TDIcons.add;
    if (icon == delete) return TDIcons.delete_filled;
    if (icon == edit) return TDIcons.edit_filled;
    if (icon == settings) return TDIcons.setting_filled;
    if (icon == search) return TDIcons.search;
    if (icon == refresh) return TDIcons.refresh;

    // 媒体类
    if (icon == play) return TDIcons.play;
    if (icon == pause) return TDIcons.pause;
    if (icon == stop) return TDIcons.stop;
    if (icon == subtitles) return TDIcons.subtitle;
    if (icon == video) return TDIcons.video;

    // 用户类
    if (icon == person) return TDIcons.user_filled;
    if (icon == accountCircle) return TDIcons.user_filled;

    // 主页类
    if (icon == home) return TDIcons.home_filled;
    if (icon == explore) return TDIcons.explore_filled;
    if (icon == school) return TDIcons.education_filled;

    // 状态类
    if (icon == favorite) return TDIcons.heart_filled;
    if (icon == favoriteBorder) return TDIcons.heart_filled;
    if (icon == star) return TDIcons.star_filled;
    if (icon == starBorder) return TDIcons.star_filled;
    if (icon == bookmarkBorder) return TDIcons.bookmark_filled;
    if (icon == bookmarkFill) return TDIcons.bookmark_filled;
    if (icon == checkCircleOutline) return TDIcons.check_circle_filled;
    if (icon == checkCircle) return TDIcons.check_circle_filled;

    // 文件类
    if (icon == folder) return TDIcons.folder_filled;
    if (icon == insertDriveFile) return TDIcons.file_filled;
    if (icon == article) return TDIcons.article_filled;

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
        return Icon(TDIcons.error, size: width ?? 24, color: const Color(0xFF9E9E9E)); // grey
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

  // ─── 卡片展示图标（TDesign Icons） ──────────
  static const IconData displayVideo = TDIcons.video;
  static const IconData displayArticle = TDIcons.article;
  static const IconData displayAudio = TDIcons.audio;

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
