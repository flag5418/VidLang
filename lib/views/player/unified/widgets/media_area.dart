import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:omni_player/omni_player.dart';
import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;
import 'package:vidlang/widgets/selectable_english_line.dart';

/// 媒体区域组件
///
/// 布局设计（基于 V1.2 文档）:
/// - 视频 → VideoWidget 占上部 ~1/3 空间 + 字幕覆盖层(下部)
/// - 音频 → 全部空间用于字幕显示（封面背景 + 字幕列表）
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
  });

  @override
  Widget build(BuildContext context) {
    if (isVideo) {
      return isLandscape ? _buildVideoLandscape(context) : _buildVideoPortrait(context);
    } else {
      return _buildAudioArea(context);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 视频模式 — 竖屏 (Portrait)
  // ═══════════════════════════════════════════════════════════

  /// 竖屏视频：上部视频(~1/3) + 下部字幕区域
  Widget _buildVideoPortrait(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final videoAreaHeight = screenHeight * 0.38; // 视频占约 38%

    return Column(
      children: [
        // 上部：视频播放器
        SizedBox(
          height: videoAreaHeight,
          width: double.infinity,
          child: VideoWidget(player: player),
        ),

        // 下部：字幕区域（有字幕时显示）
        if (subtitleVisible && subtitlesList.isNotEmpty)
          Expanded(
            child: _buildSubtitleOverlayArea(context),
          )
        else
          Expanded(child: const SizedBox.shrink()),
      ],
    );
  }

  /// 字幕覆盖层区域（竖屏视频下部）
  Widget _buildSubtitleOverlayArea(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: adaptive.Adaptive.w(context, 16),
        vertical: adaptive.Adaptive.h(context, 12),
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
      ),
      child: _buildSubtitleListView(context, showCurrentHighlight: true),
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
            bottom: adaptive.Adaptive.h(context, 80), // 底部控制栏上方
            child: Center(
              child: _buildFloatingSubtitleBar(context),
            ),
          ),
      ],
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
        horizontal: adaptive.Adaptive.w(context, 20),
        vertical: adaptive.Adaptive.h(context, 8),
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 20)),
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
                  top: adaptive.Adaptive.h(context, 52), // TopBar 高度（紧凑）
                  bottom: adaptive.Adaptive.h(context, 160), // BottomControls 预留（紧凑）
                ),
                child: _buildSubtitleListView(context, showCurrentHighlight: true),
              ),
            )
          else
            Center(
              child: Text(
                '暂无字幕',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: adaptive.Adaptive.sp(context, 14),
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
  Widget _buildSubtitleListView(BuildContext context, {required bool showCurrentHighlight}) {
    // 自动滚动到当前句的 ScrollController
    final scrollController = ScrollController();

    // 当 currentIndex 变化时，延迟一帧后滚动到当前句
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentIndex != null && currentIndex! >= 0 && currentIndex! < subtitlesList.length) {
        // 计算大致的偏移量：每个 item 高约 60-80pt
        final estimatedItemHeight = adaptive.Adaptive.h(context, showCurrentHighlight ? 70 : 55);
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
        horizontal: adaptive.Adaptive.w(context, 12), // 减小左右边距 16→12
        vertical: adaptive.Adaptive.h(context, 6),
      ),
      itemBuilder: (context, index) {
        final sub = subtitlesList[index];
        final isCurrent = index == currentIndex;

        return GestureDetector(
          onTap: () => onTapSubtitle?.call(index),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: adaptive.Adaptive.w(context, 10), // 减小内部左右边距
              vertical: adaptive.Adaptive.h(context, showCurrentHighlight ? 12 : 9),
            ),
            margin: EdgeInsets.only(bottom: adaptive.Adaptive.h(context, 6)),
            decoration: BoxDecoration(
              color: isCurrent && showCurrentHighlight
                  ? AppColors.primary.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 12)),
              border: isCurrent && showCurrentHighlight
                  ? Border.all(
                      color: AppColors.primary.withValues(alpha: 0.5),
                      width: 1,
                    )
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SelectableEnglishLine(
                  text: sub.content,
                  fontSize: fontSize * (isCurrent && showCurrentHighlight ? 1.08 : 1.0),
                  fontColor: isCurrent && showCurrentHighlight ? Colors.white : Colors.white70,
                  onSelectionChanged: (words) => onWordSelected?.call(words, sub),
                ),

                // 注音
                if (pronunciationVisible &&
                    sub.pronunciation != null &&
                    sub.pronunciation!.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: adaptive.Adaptive.h(context, 3)),
                    child: Text(
                      sub.pronunciation!,
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: adaptive.Adaptive.sp(context, fontSize * 0.7),
                      ),
                    ),
                  ),

                // 翻译
                if (translateVisible &&
                    sub.contentTranslate != null &&
                    sub.contentTranslate!.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: adaptive.Adaptive.h(context, 5)),
                    child: Text(
                      sub.contentTranslate!,
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: adaptive.Adaptive.sp(context, fontSize * 0.8),
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
