import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/providers/player_engine_provider.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/theme/app_icons.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

/// 侧边栏（双Tab：资源列表 / 播放设置）
///
/// 布局设计（基于 V1.2 文档）:
/// - Tab1: 资源列表（封面+标题+图标+时长）
/// - Tab2: 播放设置（Radio播放模式/Slider字号/Popup倍速和循环）
/// - 样式: BackdropFilter 毛玻璃 + 黑色半透明背景
class SideDrawer extends ConsumerWidget {
  final bool isOpen;
  final bool isPermanent;
  final List<VideoInfo> videos;
  final String currentVideoCode;
  final String title;
  final void Function(String code) onSwitchTo;
  final VoidCallback onClose;

  const SideDrawer({
    super.key,
    this.isOpen = false,
    this.isPermanent = false,
    this.videos = const [],
    required this.currentVideoCode,
    required this.title,
    required this.onSwitchTo,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drawerContent = _buildDrawerContent(context, ref);

    if (isPermanent) {
      return _buildPermanentDrawer(context, drawerContent);
    }

    // 滑出模式
    if (!isOpen) return const SizedBox.shrink();

    // 遮罩层
    return GestureDetector(
      onTap: onClose,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        alignment: Alignment.centerRight,
        child: AnimatedSlide(
          offset: Offset(isOpen ? 0.0 : 1.0, 0),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: FractionallySizedBox(
            widthFactor: isIPad(context) ? 0.35 : 0.8,
            alignment: Alignment.centerRight,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: _getDrawerWidth(context),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    border: Border(
                      left: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
                    ),
                  ),
                  child: drawerContent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 固定模式（iPad 横屏分栏）
  Widget _buildPermanentDrawer(BuildContext context, Widget content) {
    return Container(
      width: _getDrawerWidth(context),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        border: Border(
          left: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: content,
    );
  }

  double _getDrawerWidth(BuildContext context) =>
      isIPad(context) ? adaptive.Adaptive.w(context, 400) : adaptive.Adaptive.w(context, 320);

  /// 主内容区（Tab 切换）
  Widget _buildDrawerContent(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Tab 栏
          _buildTabBar(context),

          // 分隔线
          Divider(height: 1, color: Colors.white10),

          // 内容
          Expanded(
            child: TabBarView(
              children: [
                _buildResourceListTab(context),
                _buildSettingsTab(context, ref),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tab 栏
  Widget _buildTabBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(context, 16)),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: TabBar(
        labelColor: AppColors.primary,
        unselectedLabelColor: Colors.white70,
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        indicatorWeight: 2,
        labelStyle: TextStyle(
          fontSize: adaptive.Adaptive.sp(context, 14),
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: adaptive.Adaptive.sp(context, 14),
          fontWeight: FontWeight.normal,
        ),
        tabs: [
          Tab(text: '资源列表'),
          Tab(text: '播放设置'),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Tab1: 资源列表
  // ═══════════════════════════════════════════════════════════

  Widget _buildResourceListTab(BuildContext context) {
    if (videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.folder, size: 48, color: Colors.white24),
            SizedBox(height: adaptive.Adaptive.h(context, 12)),
            Text('暂无内容', style: TextStyle(color: Colors.white38, fontSize: adaptive.Adaptive.sp(context, 14))),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.symmetric(
        horizontal: adaptive.Adaptive.w(context, 8),
        vertical: adaptive.Adaptive.h(context, 8),
      ),
      itemCount: videos.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: Colors.white10),
      itemBuilder: (ctx, index) => _buildListItem(ctx, videos[index]),
    );
  }

  /// 列表项
  Widget _buildListItem(BuildContext context, VideoInfo video) {
    final isSelected = video.code == currentVideoCode;

    return GestureDetector(
      onTap: () => onSwitchTo(video.code ?? ''),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: adaptive.Adaptive.w(context, 12),
          vertical: adaptive.Adaptive.h(context, 10),
        ),
        child: Row(
          children: [
            // 当前播放指示条
            Container(
              width: 3,
              height: adaptive.Adaptive.h(context, 40),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            SizedBox(width: adaptive.Adaptive.w(context, 10)),

            // 封面缩略图
            _buildThumbnail(context, video),

            SizedBox(width: adaptive.Adaptive.w(context, 12)),

            // 信息列
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    video.name,
                    style: TextStyle(
                      color: isSelected ? AppColors.primary : Colors.white,
                      fontSize: adaptive.Adaptive.sp(context, 14),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // 图标行（收藏/历史/播放状态 + 时长）
                  Row(
                    children: [
                      Icon(AppIcons.favoriteBorder, size: 12, color: Colors.white38),
                      SizedBox(width: 4),
                      Icon(AppIcons.history, size: 12, color: Colors.white38),
                      SizedBox(width: 4),
                      if (isSelected)
                        Icon(AppIcons.playCircleFill, size: 12, color: AppColors.primary)
                      else
                        Icon(AppIcons.playCircleOutline, size: 12, color: Colors.white38),
                      Spacer(),
                      Text(
                        _formatDuration(video.duration),
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 波形图占位或更多按钮
            Icon(AppIcons.moreVert, size: 18, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context, VideoInfo video) {
    if (video.cover != null && video.cover!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          video.cover!,
          width: adaptive.Adaptive.w(context, 56),
          height: adaptive.Adaptive.h(context, 42),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholderIcon(context),
        ),
      );
    }
    return _placeholderIcon(context);
  }

  Widget _placeholderIcon(BuildContext context) {
    return Container(
      width: adaptive.Adaptive.w(context, 56),
      height: adaptive.Adaptive.h(context, 42),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(AppIcons.musicNote, size: 20, color: Colors.white30),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // ═══════════════════════════════════════════════════════════
  // Tab2: 播放设置
  // ═══════════════════════════════════════════════════════════

  Widget _buildSettingsTab(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerEngineProvider);
    final notifier = ref.read(playerEngineProvider.notifier);

    return ListView(
      padding: EdgeInsets.all(adaptive.Adaptive.w(context, 16)),
      children: [
        // 播放模式
        _buildSectionTitle(context, '播放模式'),
        SizedBox(height: adaptive.Adaptive.h(context, 8)),
        _buildLoopModeSelector(context, state.loopingMode, notifier),

        SizedBox(height: adaptive.Adaptive.h(context, 24)),

        // 字号
        _buildSectionTitle(context, '字号'),
        SizedBox(height: adaptive.Adaptive.h(context, 8)),
        _buildFontSizeSlider(context, state.subtitleFontSize, notifier),

        SizedBox(height: adaptive.Adaptive.h(context, 24)),

        // 倍速
        _buildSectionTitle(context, '倍速'),
        SizedBox(height: adaptive.Adaptive.h(context, 8)),
        _buildSpeedButton(context, state.speed, notifier),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white70,
        fontSize: adaptive.Adaptive.sp(context, 13),
        fontWeight: FontWeight.w500,
      ),
    );
  }

  /// 循环模式选择器 (Radio 组)
  Widget _buildLoopModeSelector(BuildContext context, String currentMode, PlayerEngineNotifier notifier) {
    final modes = [
      ('single_play', '单集播放'),
      ('list_loop', '列表循环'),
      ('single_loop', '单集循环'),
      ('sequence_play', '顺序播放'),
    ];

    return Wrap(
      spacing: adaptive.Adaptive.w(context, 8),
      runSpacing: adaptive.Adaptive.h(context, 8),
      children: modes.map((m) {
        final selected = currentMode == m.$1;
        return GestureDetector(
          onTap: () => notifier.setLoopingMode(m.$1),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(
              horizontal: adaptive.Adaptive.w(context, 14),
              vertical: adaptive.Adaptive.h(context, 8),
            ),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 20)),
              border: selected ? Border.all(color: AppColors.primary.withValues(alpha: 0.5)) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                  size: 16,
                  color: selected ? AppColors.primary : Colors.white54,
                ),
                SizedBox(width: adaptive.Adaptive.w(context, 6)),
                Text(
                  m.$2,
                  style: TextStyle(
                    color: selected ? AppColors.primary : Colors.white70,
                    fontSize: adaptive.Adaptive.sp(context, 13),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 字号 Slider
  Widget _buildFontSizeSlider(BuildContext context, double value, PlayerEngineNotifier notifier) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('小', style: TextStyle(color: Colors.white54, fontSize: adaptive.Adaptive.sp(context, 11))),
            Text('${value.toInt()}', style: TextStyle(color: AppColors.primary, fontSize: adaptive.Adaptive.sp(context, 14), fontWeight: FontWeight.bold)),
            Text('大', style: TextStyle(color: Colors.white54, fontSize: adaptive.Adaptive.sp(context, 11))),
          ],
        ),
        SizedBox(height: adaptive.Adaptive.h(context, 8)),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: Colors.white24,
            thumbColor: AppColors.primary,
            overlayColor: AppColors.primary.withValues(alpha: 0.15),
          ),
          child: Slider(
            value: value.clamp(12.0, 40.0),
            min: 12,
            max: 40,
            divisions: 28,
            onChanged: (v) => notifier.setSubtitleFontSize(v),
          ),
        ),
      ],
    );
  }

  /// 倍速按钮（触发 ActionSheet）
  Widget _buildSpeedButton(BuildContext context, double speed, PlayerEngineNotifier notifier) {
    return GestureDetector(
      onTap: () => _showSpeedPicker(context, speed, notifier),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: adaptive.Adaptive.w(context, 16),
          vertical: adaptive.Adaptive.h(context, 14),
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(AppIcons.speed, size: 18, color: Colors.white70),
                SizedBox(width: adaptive.Adaptive.w(context, 10)),
                Text('播放速度', style: TextStyle(color: Colors.white, fontSize: adaptive.Adaptive.sp(context, 14))),
              ],
            ),
            Row(
              children: [
                Text('${speed.toStringAsFixed(1)}X', style: TextStyle(color: AppColors.primary, fontSize: adaptive.Adaptive.sp(context, 14), fontWeight: FontWeight.w600)),
                SizedBox(width: adaptive.Adaptive.w(context, 4)),
                Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white38),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSpeedPicker(BuildContext context, double current, PlayerEngineNotifier notifier) {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

    TDActionSheet.showListActionSheet(
      context,
      items: speeds.map((s) {
        final label = s == 1.0 ? '${s}X (正常)' : '${s.toStringAsFixed(2)}X';
        return TDActionSheetItem(label: label);
      }).toList(),
      onSelected: (item, index) {
        notifier.setSpeed(speeds[index]);
      },
    );
  }

  bool isIPad(BuildContext context) => adaptive.isIPad(context);
}
