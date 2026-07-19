import 'dart:io';

import 'package:flutter/material.dart';
import 'package:omni_player/omni_player.dart';
import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;
import 'package:vidlang/components/selectable_english_line.dart';

/// 媒体区域组件
///
/// 布局设计（V2.1 重构，参考 deepenglish_pad VideoPlayerBase + 用户截图）:
/// - 竖屏视频 → Column(上部视频~40% + 下部字幕列表)，黑色背景
/// - 横屏视频 → 全屏视频(Stack.fill) + 浮动当前句字幕条
/// - 音频 → 全部空间用于字幕显示（封面背景 + 字幕列表）
///
/// 关键变更:
/// 1. 竖屏视频使用 Column 分区（非 Stack 叠加），与图2一致
/// 2. 字幕从卡片式改为流式布局（左侧指示条 + 文字亮度区分）
class MediaArea extends StatelessWidget {
  final bool isVideo;
  final bool isLandscape;
  final OmniPlayer player;
  final String? coverPath;
  final String videoCode;
  final List<Subtitles> subtitlesList;
  final int? currentIndex;
  final bool subtitleVisible;
  final bool translateVisible;
  final bool pronunciationVisible;
  final double fontSize;
  final void Function(int index)? onTapSubtitle;
  final void Function(List<String> words, Subtitles sub)? onWordSelected;

  /// 全屏切换回调（仅视频模式使用）
  /// 由播放器页面传入 _toggleFullscreen，用于在设备锁定旋转时手动切换横竖屏
  final VoidCallback? onToggleFullscreen;

  const MediaArea({
    super.key,
    required this.isVideo,
    this.isLandscape = false,
    required this.player,
    this.coverPath,
    required this.videoCode,
    this.subtitlesList = const [],
    this.currentIndex,
    this.subtitleVisible = true,
    this.translateVisible = false,
    this.pronunciationVisible = false,
    this.fontSize = 18.0,
    this.onTapSubtitle,
    this.onWordSelected,
    this.onToggleFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    if (isVideo) {
      return isLandscape
          ? _buildVideoLandscape(context)
          : _buildVideoPortrait(context);
    } else {
      return _buildAudioArea(context);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 视频模式 — 竖屏 (Portrait)
  // ═══════════════════════════════════════════════════════════

  /// 竖屏视频：Column 分区布局（参考图2：上部视频 + 下部字幕列表）
  /// 与横屏的 Stack 全屏不同，竖屏采用上下分区
  ///
  /// **布局说明**：
  /// - 外层 UnifiedPlayerPage 已通过 Scaffold + _buildPlayerStack(Stack) 管理
  /// - TopBar 和 BottomControls 是 Stack 上的 Positioned 浮动层
  /// - 本组件只需预留顶部空间给 TopBar（状态栏 + 52pt），不做二次 Scaffold 嵌套
  /// - 视频区域用 Flexible 自适应，字幕列表填充剩余空间
  Widget _buildVideoPortrait(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final statusBarHeight = mediaQuery.padding.top;
    final topBarHeight = adaptive.Adaptive.h(52);
    final topReserved = statusBarHeight + topBarHeight;

    debugPrint(
      '🎬 MediaArea._buildVideoPortrait: '
      'statusBar=$statusBarHeight, topBar=$topBarHeight, '
      'topReserved=$topReserved, '
      'usableHeight=${mediaQuery.size.height - topReserved}',
    );

    return Container(
      color: Colors.black,
      child: SafeArea(
        bottom: false, // 底部不需要 SafeArea，BottomControls 自己处理
        child: Column(
          children: [
            // 给外层 TopBar 让位（状态栏 + 52pt 栏）
            SizedBox(height: topReserved),

            // 上部：视频播放器（Flexible 自适应，不锁死固定高度）
            Flexible(
              flex: 38,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  VideoWidget(player: player),

                  // 全屏切换按钮（视频框内右上角）
                  if (onToggleFullscreen != null)
                    Positioned(
                      top: adaptive.Adaptive.h(8),
                      right: adaptive.Adaptive.w(8),
                      child: _buildFullscreenButton(isLandscape),
                    ),
                ],
              ),
            ),

            // 下部：字幕列表区域（黑色背景，占满剩余空间）
            if (subtitleVisible && subtitlesList.isNotEmpty)
              Flexible(
                flex: 62,
                child: Container(
                  color: Colors.black,
                  child: _buildSubtitleListView(
                    context,
                    showCurrentHighlight: true,
                  ),
                ),
              )
            else
              const Flexible(flex: 62, child: SizedBox.shrink()),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 视频模式 — 横屏 (Landscape)
  // ═══════════════════════════════════════════════════════════

  /// 横屏视频：全屏视频 + 浮动当前句字幕条
  Widget _buildVideoLandscape(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 全屏视频
        Positioned.fill(child: VideoWidget(player: player)),

        // 浮动字幕条（仅当前句，黑底白字）
        if (subtitleVisible &&
            subtitlesList.isNotEmpty &&
            currentIndex != null &&
            currentIndex! >= 0 &&
            currentIndex! < subtitlesList.length)
          Positioned(
            left: 0,
            right: 0,
            bottom: adaptive.Adaptive.h(80), // 底部控制栏上方
            child: Center(child: _buildFloatingSubtitleBar(context)),
          ),

        // 全屏切换按钮（视频右上角：真正顶角，TopBar 已为该区域留出透明空间）
        if (onToggleFullscreen != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + adaptive.Adaptive.h(8),
            right: adaptive.Adaptive.w(12),
            child: _buildFullscreenButton(isLandscape),
          ),
      ],
    );
  }

  /// 全屏切换按钮（黑底半透明圆形 + 白色图标）
  /// 竖屏显示 fullscreen 图标，横屏显示 fullscreen_exit 图标
  /// 点击触发 onToggleFullscreen（由播放器页面处理方向切换）
  Widget _buildFullscreenButton(bool isLandscape) {
    return GestureDetector(
      onTap: () {
        debugPrint('🎯 [MediaArea] 全屏按钮被点击');
        onToggleFullscreen?.call();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.6),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          isLandscape ? Icons.fullscreen_exit : Icons.fullscreen,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  /// 横屏浮动字幕条（仅显示当前句）
  Widget _buildFloatingSubtitleBar(BuildContext context) {
    if (currentIndex == null ||
        currentIndex! < 0 ||
        currentIndex! >= subtitlesList.length) {
      return const SizedBox.shrink();
    }
    final sub = subtitlesList[currentIndex!];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: adaptive.Adaptive.w(20),
        vertical: adaptive.Adaptive.h(8),
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(20)),
      ),
      child: SelectableEnglishLine(
        text: sub.content,
        fontSize: fontSize * 1.1,
        fontColor: Colors.white,
        onSelectionChanged: (words) => onWordSelected?.call(words, sub),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 音频模式 (Audio)
  // ═══════════════════════════════════════════════════════════

  /// 音频模式：全部空间用于字幕显示
  Widget _buildAudioArea(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 背景层
          _buildBackground(),

          // 暗色遮罩
          _buildDarkOverlay(),

          // 字幕列表（占满剩余空间）
          if (subtitlesList.isNotEmpty)
            SafeArea(
              top: false,
              bottom: false, // BottomControls 会自行处理 safe area
              child: Padding(
                padding: EdgeInsets.only(
                  top: adaptive.Adaptive.h(52), // TopBar 高度（紧凑）
                  bottom: adaptive.Adaptive.h(160), // BottomControls 预留（紧凑）
                ),
                child: _buildSubtitleListView(
                  context,
                  showCurrentHighlight: true,
                  showLeftBorder: false, // 竖屏视频字幕：取消左侧边框，仅用文字亮度区分
                ),
              ),
            )
          else
            Center(
              child: Text(
                '暂无字幕',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: adaptive.Adaptive.sp(14),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 背景相关
  // ═══════════════════════════════════════════════════════════

  /// 背景图片或渐变
  Widget _buildBackground() {
    if (coverPath != null &&
        coverPath!.isNotEmpty &&
        File(coverPath!).existsSync()) {
      return Image.file(
        File(coverPath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    return _buildGradientBackground();
  }

  /// 渐变背景（无封面时使用）
  Widget _buildGradientBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
        ),
      ),
    );
  }

  /// 暗色遮罩层
  Widget _buildDarkOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.3),
            Colors.black.withValues(alpha: 0.6),
          ],
          stops: const [0.4, 1.0],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 字幕列表（音频模式和竖屏视频下部共用）
  // ═══════════════════════════════════════════════════════════

  /// 字幕列表视图（带自动滚动）
  ///
  /// [showCurrentHighlight] 是否高亮当前句（字体大小/颜色）
  /// [showLeftBorder] 是否显示当前句的左侧指示条（竖屏视频字幕取消，仅保留文字亮度区分）
  Widget _buildSubtitleListView(
    BuildContext context, {
    required bool showCurrentHighlight,
    bool showLeftBorder = true,
  }) {
    // 自动滚动到当前句的 ScrollController
    final scrollController = ScrollController();

    // 当 currentIndex 变化时，延迟一帧后滚动到当前句
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentIndex != null &&
          currentIndex! >= 0 &&
          currentIndex! < subtitlesList.length) {
        // 计算大致的偏移量：每个 item 高约 60-80pt
        final estimatedItemHeight = adaptive.Adaptive.h(
          showCurrentHighlight ? 70 : 55,
        );
        final targetOffset = currentIndex! * estimatedItemHeight;
        // 动画滚动到目标位置
        scrollController.animateTo(
          targetOffset.clamp(0.0, scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });

    return ListView.builder(
      controller: scrollController,
      itemCount: subtitlesList.length,
      padding: EdgeInsets.symmetric(
        horizontal: adaptive.Adaptive.w(14),
        vertical: adaptive.Adaptive.h(4),
      ),
      itemBuilder: (context, index) {
        final sub = subtitlesList[index];
        final isCurrent = index == currentIndex;

        return GestureDetector(
          onTap: () => onTapSubtitle?.call(index),
          behavior: HitTestBehavior.opaque,
          // V2.0 流式布局：去掉卡片包装，仅保留左侧指示条
          child: Container(
            margin: EdgeInsets.only(bottom: adaptive.Adaptive.h(2)),
            padding: EdgeInsets.symmetric(
              horizontal: adaptive.Adaptive.w(10),
              vertical: adaptive.Adaptive.h(
                isCurrent && showCurrentHighlight ? 8 : 5,
              ),
            ),
            decoration: BoxDecoration(
              // 当前句：左侧 primary 色指示条（竖屏视频字幕不显示，仅保留文字亮度区分）
              border: isCurrent && showCurrentHighlight && showLeftBorder
                  ? const Border(
                      left: BorderSide(color: AppColors.primary, width: 3),
                    )
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SelectableEnglishLine(
                  text: sub.content,
                  fontSize:
                      fontSize *
                      (isCurrent && showCurrentHighlight ? 1.03 : 1.0),
                  fontColor: isCurrent && showCurrentHighlight
                      ? Colors
                            .white // 当前句：纯白
                      : Colors.white54, // 非当前句：更暗
                  onSelectionChanged: (words) =>
                      onWordSelected?.call(words, sub),
                ),

                // 注音
                if (pronunciationVisible &&
                    sub.pronunciation != null &&
                    sub.pronunciation!.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: adaptive.Adaptive.h(2)),
                    child: Text(
                      sub.pronunciation!,
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: adaptive.Adaptive.sp(fontSize * 0.65),
                      ),
                    ),
                  ),

                // 翻译：仅当前句显示，非当前句隐藏
                if (translateVisible &&
                    isCurrent &&
                    sub.contentTranslate != null &&
                    sub.contentTranslate!.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: adaptive.Adaptive.h(3)),
                    child: Text(
                      sub.contentTranslate!,
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: adaptive.Adaptive.sp(fontSize * 0.75),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
