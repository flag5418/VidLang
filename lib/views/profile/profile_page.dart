/// "我的"页面
///
/// 布局：
/// 1. 顶部个人信息（头像、昵称）
/// 2. 模式切换（免费/收费）
/// 3. 学习统计入口
/// 4. 设置列表
/// 5. 底部固定（退出登录）
library;
import 'dart:io';import 'package:vidlang/utils/adaptive.dart' as adaptive;


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vidlang/services/app_keys_service.dart';
import 'package:vidlang/services/billing/billing_service.dart';
import 'package:vidlang/models/base_entity.dart';
import 'package:vidlang/models/device_type.dart';
import 'package:vidlang/models/user.dart';
import 'package:vidlang/providers/difficulty_provider.dart';
import 'package:vidlang/providers/device_type_provider.dart';
import 'package:vidlang/providers/subscription_provider.dart';
import 'package:vidlang/providers/theme_provider.dart';
import 'package:vidlang/services/auth_service.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/settings_service.dart';
import 'package:vidlang/services/learning/stats_service.dart';
import 'package:vidlang/services/tts/tts_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/views/profile/billing_page.dart';
import 'package:vidlang/views/profile/billing_rules_page.dart';
import 'package:vidlang/views/profile/edit_profile_page.dart';
import 'package:vidlang/views/profile/learning_stats_page.dart';
import 'package:vidlang/views/profile/topup_page.dart';
import 'package:vidlang/views/profile/user_settings_page.dart';
import 'package:vidlang/widgets/app_dialogs.dart';


class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _SettingItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  _SettingItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _isSupabaseUser = false;
  User? _currentUser;
  SummaryStats _summaryStats = const SummaryStats();
  int _wifiPort = 9999;
  String _ttsCacheLabel = '加载中...';
  double _todayCost = 0;

  @override
  void initState() {
    super.initState();
    _checkUser();
    _loadSummaryStats();
    _loadWifiPort();
    _loadTtsCacheInfo();
    _refreshBalance(); // 进入页面时刷新最新余额
    _loadTodayCost(); // 加载今日消费
  }

  Future<void> _checkUser() async {
    var user = AppKeysService.currentUser;
    if (user == null) {
      final code = await DatabaseService.getCurrentUserCode();
      if (code != null && code.isNotEmpty) {
        user = await BaseEntityExtension.findByCode<User>(code, () => User());
        AppKeysService.currentUser = user;
      }
    }
    if (!mounted) return;
    final isSupabaseFromDb = user?.authProvider == 'supabase';
    final isSupabaseFromClient = AuthService.instance.isLoggedIn;
    setState(() {
      _currentUser = user;
      _isSupabaseUser = isSupabaseFromDb || isSupabaseFromClient;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final subState = ref.watch(subscriptionProvider);
    final difficulty = ref.watch(difficultyProvider);

    return Scaffold(
      backgroundColor: AppColors.getSurfaceHighest(brightness: brightness),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ═══ 顶部个人信息区域（固定头部效果） ═══
            SliverToBoxAdapter(
              child: _buildProfileHeader(colorScheme, brightness),
            ),

            // ═══ 内容列表区 ═══
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  SizedBox(height: adaptive.Adaptive.h(20)),

                  // 模式切换
                  _buildModeSwitch(colorScheme, subState),
                  SizedBox(height: adaptive.Adaptive.h(24)),

                  // // 学习统计入口
                  // _buildSectionTitle('学习统计', colorScheme),
                  // SizedBox(height: adaptive.Adaptive.h(10)),
                  // _buildLearningStats(colorScheme),
                  // SizedBox(height: adaptive.Adaptive.h(24)),

                  // 设置列表
                  _buildSectionTitle('设置', colorScheme),
                  SizedBox(height: adaptive.Adaptive.h(10)),
                  _buildSettingsCard(colorScheme, [
                    _SettingItem(
                      icon: AppIcons.palette,
                      title: '外观设置',
                      subtitle: ref.watch(themeModeProvider).label,
                      onTap: () => _showThemePicker(),
                    ),
                    _SettingItem(
                      icon: Icons.devices,
                      title: '设备类型',
                      subtitle: ref.watch(deviceTypeProvider).isTablet
                          ? 'iPad 布局'
                          : 'iPhone 布局',
                      onTap: () => _showDeviceTypeCombobox(),
                    ),
                    _SettingItem(
                      icon: AppIcons.tune,
                      title: '学习难度',
                      subtitle: difficulty.label,
                      onTap: () => _showDifficultyPicker(),
                    ),

                    _SettingItem(
                      icon: AppIcons.volumeUp,
                      title: 'TTS 缓存管理',
                      subtitle: _ttsCacheLabel,
                      onTap: () => _showTtsCacheDialog(),
                    ),
                    _SettingItem(
                      icon: AppIcons.receiptLong,
                      title: '消费明细',
                      subtitle: '查看今日消费',
                      onTap: () => _navigateToBillingPage(),
                    ),
                    _SettingItem(
                      icon: AppIcons.rule,
                      title: '计费规则',
                      subtitle: '查看各项AI功能费用',
                      onTap: () => _navigateToBillingRulesPage(),
                    ),
                    if (_isSupabaseUser)
                      _SettingItem(
                        icon: AppIcons.manageAccounts,
                        title: '子账号设置',
                        subtitle: '子账号管理',
                        onTap: () => _navigateToUserSettings(),
                      ),
                    _SettingItem(
                      icon: AppIcons.wifiTethering,
                      title: 'WiFi 传输',
                      subtitle: '端口：$_wifiPort',
                      onTap: () => _showWifiPortDialog(),
                    ),
                  ]),
                  SizedBox(height: adaptive.Adaptive.h(24)),

                  // 底部操作
                  _buildBottomActions(colorScheme),
                  SizedBox(height: adaptive.Adaptive.h(32)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ColorScheme colorScheme) {
    return Padding(
      padding: EdgeInsets.only(bottom: adaptive.Adaptive.h(8)),
      child: Text(
        title,
        style: TextStyle(
          fontSize: adaptive.Adaptive.sp(AppTypography.fontSizeSmall),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // 个人信息头部（干净卡片式设计）
  // ═══════════════════════════════════════════════

  Widget _buildProfileHeader(ColorScheme colorScheme, Brightness brightness) {
    final displayName = _currentUser?.nickname.isNotEmpty == true
        ? _currentUser!.nickname
        : (_currentUser?.username ?? '未登录');
    final avatarPath = _currentUser?.avatar;
    final daysLabel = _summaryStats.totalDays > 0
        ? '已坚持学习 ${_summaryStats.totalDays} 天'
        : '开始学习之旅';

    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        adaptive.Adaptive.h(12),
        AppSpacing.pagePadding,
        0,
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.space5,
        adaptive.Adaptive.h(24),
        AppSpacing.space5,
        adaptive.Adaptive.h(24),
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: brightness == Brightness.dark ? 0.2 : 0.04,
            ),
            blurRadius: adaptive.Adaptive.w(12),
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withValues(
              alpha: brightness == Brightness.dark ? 0.1 : 0.02,
            ),
            blurRadius: adaptive.Adaptive.w(4),
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // 头像 + 基本信息 + 编辑按钮
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 头像
              GestureDetector(
                onTap: () => _navigateToEditProfile(),
                child: Hero(
                  tag: 'profile_avatar',
                  child: _buildAvatarWidget(
                    colorScheme,
                    avatarPath,
                    displayName,
                    size: 64,
                  ),
                ),
              ),
              SizedBox(width: adaptive.Adaptive.w(16)),
              // 信息区
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(20),
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: adaptive.Adaptive.h(6)),
                    // 学习天数 — 简洁文字，不用红色标签
                    Row(
                      children: [
                        Icon(
                          AppIcons.schedule,
                          size: adaptive.Adaptive.sp(14),
                          color: colorScheme.primary.withValues(alpha: 0.7),
                        ),
                        SizedBox(width: adaptive.Adaptive.w(4)),
                        Text(
                          daysLabel,
                          style: TextStyle(
                            fontSize: adaptive.Adaptive.sp(13),
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 编辑按钮
              GestureDetector(
                onTap: () => _navigateToEditProfile(),
                child: Container(
                  width: adaptive.Adaptive.w(36),
                  height: adaptive.Adaptive.w(36),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(
                      adaptive.Adaptive.r(10),
                    ),
                  ),
                  child: Icon(
                    AppIcons.chevronRight,
                    size: adaptive.Adaptive.icon(18),
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: adaptive.Adaptive.h(20)),

          // 快速统计行（学习数据概览）
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: adaptive.Adaptive.w(16),
              vertical: adaptive.Adaptive.h(14),
            ),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _quickStatItem(
                  AppIcons.calendarToday,
                  '${_summaryStats.totalDays}',
                  '天数',
                  colorScheme,
                ),
                _quickStatDivider(colorScheme),
                _quickStatItem(
                  AppIcons.movieCreation,
                  '${_summaryStats.videoTotal}',
                  '视频',
                  colorScheme,
                ),
                _quickStatDivider(colorScheme),
                _quickStatItem(
                  AppIcons.musicNote,
                  '${_summaryStats.audioTotal}',
                  '音频',
                  colorScheme,
                ),
                _quickStatDivider(colorScheme),
                _quickStatItem(
                  AppIcons.menuBook,
                  '${_summaryStats.articleTotal}',
                  '文章',
                  colorScheme,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickStatItem(
    IconData icon,
    String value,
    String label,
    ColorScheme cs,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: adaptive.Adaptive.sp(18),
          color: cs.primary.withValues(alpha: 0.7),
        ),
        SizedBox(height: adaptive.Adaptive.h(4)),
        Text(
          value,
          style: TextStyle(
            fontSize: adaptive.Adaptive.sp(17),
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: adaptive.Adaptive.sp(10),
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _quickStatDivider(ColorScheme cs) {
    return Container(
      height: adaptive.Adaptive.h(24),
      width: 1,
      color: cs.outline.withValues(alpha: 0.2),
    );
  }

  // ==================== 头像组件 ====================

  Widget _buildAvatarWidget(
    ColorScheme colorScheme,
    String? avatarPath,
    String displayName, {
    double size = 52,
  }) {
    if (avatarPath != null && avatarPath.isNotEmpty) {
      final file = File(avatarPath);
      if (file.existsSync()) {
        return ClipOval(
          child: Image.file(file, width: size, height: size, fit: BoxFit.cover),
        );
      }
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: size * 0.35,
          fontWeight: FontWeight.bold,
          color: colorScheme.primary,
        ),
      ),
    );
  }

  // ==================== 模式切换 ====================

  Widget _buildModeSwitch(ColorScheme colorScheme, SubscriptionState subState) {
    final isPremium = subState.mode == SubscriptionMode.premium;

    return Container(
      padding: EdgeInsets.all(AppSpacing.space5),
      decoration: BoxDecoration(
        color: isPremium
            ? AppColors.premium.withValues(alpha: 0.08)
            : colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isPremium
              ? AppColors.premium.withValues(alpha: 0.25)
              : colorScheme.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isPremium ? AppIcons.workspacePremium : AppIcons.person,
                color: isPremium ? AppColors.premium : colorScheme.primary,
                size: adaptive.Adaptive.w(22),
              ),
              SizedBox(width: adaptive.Adaptive.w(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPremium ? '收费模式' : '免费模式',
                      style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(15),
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: adaptive.Adaptive.h(2)),
                    Text(
                      isPremium
                          ? '余额：¥${subState.balance.toStringAsFixed(2)}'
                          : '使用基础功能，不产生费用',
                      style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(12),
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Toggle switch（仅 iOS 可切换，Android 强制 premium 不显示开关）
              if (subState.isIOS)
                GestureDetector(
                  onTap: () async {
                    await ref
                        .read(subscriptionProvider.notifier)
                        .setMode(
                          isPremium
                              ? SubscriptionMode.free
                              : SubscriptionMode.premium,
                        );
                  },
                child: Container(
                  width: adaptive.Adaptive.w(50),
                  height: adaptive.Adaptive.h(28),
                  padding: EdgeInsets.all(adaptive.Adaptive.w(2)),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      adaptive.Adaptive.r(14),
                    ),
                    color: isPremium
                        ? AppColors.premium
                        : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    alignment: isPremium
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: adaptive.Adaptive.w(24),
                      height: adaptive.Adaptive.w(24),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                    ),
                  ),
                ),
              // Android 显示锁定图标提示（强制 premium 不可切换）
              if (!subState.isIOS)
                Padding(
                  padding: EdgeInsets.only(right: adaptive.Adaptive.w(4)),
                  child: Icon(
                    AppIcons.lock,
                    size: adaptive.Adaptive.w(16),
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ),
          // 付费模式下额外显示今日消费和充值按钮
          if (isPremium) ...[
            SizedBox(height: adaptive.Adaptive.h(12)),
            Container(
              padding: EdgeInsets.only(top: adaptive.Adaptive.h(12)),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.premium.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // 今日消费
                  Expanded(
                    child: GestureDetector(
                      onTap: _navigateToBillingPage,
                      child: Row(
                        children: [
                          Text(
                            '今日消费',
                            style: TextStyle(
                              fontSize: adaptive.Adaptive.sp(13),
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          SizedBox(width: adaptive.Adaptive.w(8)),
                          Text(
                            '¥${_todayCost.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: adaptive.Adaptive.sp(14),
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          SizedBox(width: adaptive.Adaptive.w(4)),
                          Icon(
                            AppIcons.chevronRight,
                            size: adaptive.Adaptive.sp(16),
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 充值按钮
                  GestureDetector(
                    onTap: _navigateToTopupPage,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: adaptive.Adaptive.w(14),
                        vertical: adaptive.Adaptive.h(6),
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.premium.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(
                          adaptive.Adaptive.r(8),
                        ),
                      ),
                      child: Text(
                        '充值',
                        style: TextStyle(
                          fontSize: adaptive.Adaptive.sp(13),
                          fontWeight: FontWeight.w600,
                          color: AppColors.premium,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== 学习统计 ====================

  Widget _buildLearningStats(ColorScheme colorScheme) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LearningStatsPage()),
      ),
      child: Container(
        padding: EdgeInsets.all(AppSpacing.space4),
        decoration: BoxDecoration(
          color: AppColors.getSurface(brightness: Theme.of(context).brightness),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            _statItem(
              AppIcons.calendarToday,
              '${_summaryStats.totalDays}',
              '天数',
              colorScheme,
            ),
            _statDivider(colorScheme),
            _statItem(
              AppIcons.movie,
              '${_summaryStats.videoTotal}',
              '视频',
              colorScheme,
            ),
            _statDivider(colorScheme),
            _statItem(
              AppIcons.musicNote,
              '${_summaryStats.audioTotal}',
              '音频',
              colorScheme,
            ),
            _statDivider(colorScheme),
            _statItem(
              AppIcons.menuBook,
              '${_summaryStats.articleTotal}',
              '文章',
              colorScheme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(
    IconData icon,
    String value,
    String label,
    ColorScheme colorScheme,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            size: adaptive.Adaptive.sp(20),
            color: colorScheme.primary.withValues(alpha: 0.7),
          ),
          SizedBox(height: adaptive.Adaptive.h(6)),
          Text(
            value,
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(18),
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          SizedBox(height: adaptive.Adaptive.h(2)),
          Text(
            label,
            style: TextStyle(
              fontSize: AppTypography.fontSizeXSmall,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statDivider(ColorScheme colorScheme) {
    return Container(
      height: adaptive.Adaptive.h(30),
      width: adaptive.Adaptive.w(1),
      color: colorScheme.outline.withValues(alpha: 0.3),
    );
  }

  // ==================== 设置列表 ====================

  Widget _buildSettingsCard(ColorScheme colorScheme, List<_SettingItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurface(brightness: Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          final item = items[i];
          final isLast = i == items.length - 1;
          return Column(
            children: [
              InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.space4,
                    vertical: AppSpacing.space3,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: adaptive.Adaptive.w(32),
                        height: adaptive.Adaptive.w(32),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            adaptive.Adaptive.r(8),
                          ),
                        ),
                        child: Icon(
                          item.icon,
                          size: adaptive.Adaptive.sp(18),
                          color: colorScheme.primary,
                        ),
                      ),
                      SizedBox(width: AppSpacing.space4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: TextStyle(
                                fontSize: adaptive.Adaptive.sp(AppTypography.fontSizeBase),
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            if (item.subtitle != null) ...[
                              SizedBox(height: adaptive.Adaptive.h(2)),
                              Text(
                                item.subtitle!,
                                style: TextStyle(
                                  fontSize: adaptive.Adaptive.sp(AppTypography.fontSizeXSmall),
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(
                        AppIcons.chevronRight,
                        size: adaptive.Adaptive.sp(20),
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
              // Add 0.5pt divider between items
              if (!isLast)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.space4),
                  child: Divider(
                    height: 1,
                    thickness: 0.5,
                    color: colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  // ==================== 底部操作 ====================

  Widget _buildBottomActions(ColorScheme colorScheme) {
    return Column(
      children: [
        // 关于卡片
        _ElevatedCard(
          onTap: () {},
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.space4,
            vertical: AppSpacing.space3 + 2,
          ),
          child: Row(
            children: [
              Container(
                width: adaptive.Adaptive.w(36),
                height: adaptive.Adaptive.w(36),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(adaptive.Adaptive.r(10)),
                ),
                child: Icon(
                  AppIcons.info,
                  size: adaptive.Adaptive.sp(18),
                  color: colorScheme.primary.withValues(alpha: 0.8),
                ),
              ),
              SizedBox(width: AppSpacing.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '关于',
                      style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(16),
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: adaptive.Adaptive.h(2)),
                    Text(
                      'VidLang v1.0.0',
                      style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(13),
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                AppIcons.chevronRight,
                size: adaptive.Adaptive.sp(20),
                color: colorScheme.outline.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.space3),
        // 退出登录卡片（红色文字）
        _ElevatedCard(
          onTap: () => _logout(),
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.space4,
            vertical: AppSpacing.space3 + 2,
          ),
          child: Row(
            children: [
              Container(
                width: adaptive.Adaptive.w(36),
                height: adaptive.Adaptive.w(36),
                decoration: BoxDecoration(
                  color: colorScheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(adaptive.Adaptive.r(10)),
                ),
                child: Icon(
                  AppIcons.logout,
                  size: adaptive.Adaptive.sp(18),
                  color: colorScheme.error.withValues(alpha: 0.7),
                ),
              ),
              SizedBox(width: AppSpacing.space4),
              Text(
                '退出登录',
                style: TextStyle(
                  fontSize: adaptive.Adaptive.sp(16),
                  fontWeight: FontWeight.w500,
                  color: colorScheme.error,
                ),
              ),
              const Spacer(),
              Icon(
                AppIcons.chevronRight,
                size: adaptive.Adaptive.sp(20),
                color: colorScheme.outline.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== 导航与对话框 ====================

  void _navigateToEditProfile() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EditProfilePage()),
    );
    _checkUser();
  }

  void _navigateToUserSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UserSettingsPage()),
    );
  }

  void _navigateToBillingPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BillingPage()),
    ).then((_) {
      if (!mounted) return;
    });
  }

  void _navigateToTopupPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TopupPage()),
    ).then((_) {
      if (!mounted) return;
      _refreshBalance();
      _loadTodayCost();
    });
  }

  void _navigateToBillingRulesPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BillingRulesPage()),
    );
  }

  void _showThemePicker() async {
    final currentMode = ref.read(themeModeProvider);
    final items = AppThemeMode.values.map((mode) {
      final isSelected = mode == currentMode;
      return AppBottomSheetMenuItem(
        text: mode.label,
        icon: mode.icon,
        trailing: isSelected
            ? Icon(
                AppIcons.check,
                color: Theme.of(context).colorScheme.primary,
                size: adaptive.Adaptive.sp(20),
              )
            : null,
        onTap: () async =>
            await ref.read(themeModeProvider.notifier).setMode(mode),
      );
    }).toList();
    await AppBottomSheetMenu.show(context, title: '外观设置', items: items);
  }

  void _showDifficultyPicker() async {
    final currentLevel = ref.read(difficultyProvider);
    final items = DifficultyLevel.values.map((level) {
      final isSelected = level == currentLevel;
      return AppBottomSheetMenuItem(
        text: level.label,
        subtitle: level.description,
        icon: level.icon,
        trailing: isSelected
            ? Icon(
                AppIcons.check,
                color: Theme.of(context).colorScheme.primary,
                size: adaptive.Adaptive.sp(20),
              )
            : null,
        onTap: () async =>
            await ref.read(difficultyProvider.notifier).setLevel(level),
      );
    }).toList();
    await AppBottomSheetMenu.show(context, title: '学习难度', items: items);
  }

  void _showDeviceTypeCombobox() async {
    final currentType = ref.read(deviceTypeProvider);
    final result = await AppComboboxDialog.show<AppDeviceType>(
      context,
      title: '设备类型',
      items: AppDeviceType.values,
      currentValue: currentType,
      itemBuilder: (type) => type.isTablet ? 'iPad 布局' : 'iPhone 布局',
    );
    if (result != null && result != currentType) {
      await ref.read(deviceTypeProvider.notifier).setDeviceType(result);
    }
  }

  /// 设置 WiFi 传输端口 — 使用 AppInputDialog（支持 iPad 自适应）
  void _showWifiPortDialog() async {
    final result = await AppInputDialog.show(
      context,
      title: 'WiFi 传输端口',
      hintText: '端口号',
      initialValue: _wifiPort.toString(),
      confirmText: '确定',
    );
    if (result == null || result.isEmpty) return;
    final port = int.tryParse(result.trim());
    if (port != null && port >= 1024 && port <= 65535) {
      await SettingsService.setWifiPort(port);
      if (mounted) setState(() => _wifiPort = port);
    } else if (mounted) {
      AppToast.show(context, '端口号需在 1024-65535 之间', type: ToastType.warning);
    }
  }

  // ==================== TTS 缓存管理 ====================

  Future<void> _loadTtsCacheInfo() async {
    try {
      await SettingsService.getTtsCacheSize();
      final stats = await TtsService().getCacheStats();
      if (mounted) {
        setState(() {
          _ttsCacheLabel = '${stats.count} 条缓存 · ${stats.sizeLabel}';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _ttsCacheLabel = '缓存不可用');
    }
  }

  void _showTtsCacheDialog() async {
    // 先刷新最新数据
    final stats = await TtsService().getCacheStats();
    final cacheSize = await SettingsService.getTtsCacheSize();

    if (!mounted) return;

    final sizeController = TextEditingController(text: cacheSize.toString());

    showGeneralDialog(
      context: context,
      pageBuilder: (buildContext, animation, secondaryAnimation) {
        final cs = Theme.of(buildContext).colorScheme;
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: adaptive.Adaptive.w(320),
              padding: EdgeInsets.all(adaptive.Adaptive.w(20)),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(adaptive.Adaptive.r(14)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题
                  Row(
                    children: [
                      Icon(
                        AppIcons.volumeUp,
                        color: cs.primary,
                        size: adaptive.Adaptive.sp(22),
                      ),
                      SizedBox(width: adaptive.Adaptive.w(8)),
                      Text(
                        'TTS 缓存管理',
                        style: TextStyle(
                          fontSize: adaptive.Adaptive.sp(17),
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: adaptive.Adaptive.h(16)),

                  // 当前状态
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(adaptive.Adaptive.w(12)),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(
                        adaptive.Adaptive.r(10),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              '${stats.count}',
                              style: TextStyle(
                                fontSize: adaptive.Adaptive.sp(20),
                                fontWeight: FontWeight.bold,
                                color: cs.primary,
                              ),
                            ),
                            Text(
                              '缓存条数',
                              style: TextStyle(
                                fontSize: adaptive.Adaptive.sp(11),
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 1,
                          height: adaptive.Adaptive.h(30),
                          color: cs.outline.withValues(alpha: 0.3),
                        ),
                        Column(
                          children: [
                            Text(
                              stats.sizeLabel,
                              style: TextStyle(
                                fontSize: adaptive.Adaptive.sp(16),
                                fontWeight: FontWeight.bold,
                                color: cs.primary,
                              ),
                            ),
                            Text(
                              '占用空间',
                              style: TextStyle(
                                fontSize: adaptive.Adaptive.sp(11),
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: adaptive.Adaptive.h(16)),

                  // 最大条数设置
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '最大缓存条数（5-200）',
                      style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(13),
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  SizedBox(height: adaptive.Adaptive.h(6)),
                  TextField(
                    controller: sizeController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(15),
                      color: cs.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: '输入 5-200 之间的数字',
                      hintStyle: TextStyle(
                        fontSize: adaptive.Adaptive.sp(13),
                        color: cs.outline,
                      ),
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: adaptive.Adaptive.w(12),
                        vertical: adaptive.Adaptive.h(10),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          adaptive.Adaptive.r(8),
                        ),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  SizedBox(height: adaptive.Adaptive.h(6)),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '提示：相同文本的 TTS 音频会缓存在本地，重复播放时秒开。',
                      style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(11),
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),

                  SizedBox(height: adaptive.Adaptive.h(20)),

                  // 按钮行
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await TtsService().clearCache();
                            if (!mounted) return;
                            Navigator.pop(buildContext);
                            if (!mounted) return;
                            setState(() => _ttsCacheLabel = '0 条缓存 · 0KB');
                            AppToast.show(
                              context,
                              'TTS 缓存已清除',
                              type: ToastType.success,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: adaptive.Adaptive.h(12),
                            ),
                            side: BorderSide(
                              color: cs.error.withValues(alpha: 0.5),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                adaptive.Adaptive.r(8),
                              ),
                            ),
                          ),
                          child: Text(
                            '清除缓存',
                            style: TextStyle(
                              fontSize: adaptive.Adaptive.sp(14),
                              color: cs.error,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: adaptive.Adaptive.w(12)),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            final newSize = int.tryParse(
                              sizeController.text.trim(),
                            );
                            if (newSize == null ||
                                newSize < 5 ||
                                newSize > 200) {
                              AppToast.show(
                                buildContext,
                                '请输入 5-200 之间的数字',
                                type: ToastType.warning,
                              );
                              return;
                            }
                            await SettingsService.setTtsCacheSize(newSize);
                            if (!mounted) return;
                            Navigator.pop(buildContext);
                            if (!mounted) return;
                            setState(() {
                              _ttsCacheLabel =
                                  '${stats.count} 条缓存 · ${stats.sizeLabel}';
                            });
                            AppToast.show(
                              context,
                              '已设置为 $newSize 条',
                              type: ToastType.success,
                            );
                          },
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: adaptive.Adaptive.h(12),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                adaptive.Adaptive.r(8),
                              ),
                            ),
                          ),
                          child: Text(
                            '保存',
                            style: TextStyle(
                              fontSize: adaptive.Adaptive.sp(14),
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _logout() async {
    final confirm = await AppConfirmDialog.show(
      context,
      title: '退出登录',
      content: '确定要退出当前用户吗？',
      confirmText: '退出',
      cancelText: '取消',
      destructive: true,
    );
    if (confirm != true || !mounted) return;

    final user = AppKeysService.currentUser;
    final loginName = user?.email ?? user?.username ?? '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_login_name', loginName);
    await prefs.setString(
      'last_login_tab',
      user?.authProvider == 'supabase' ? 'supabase' : 'local',
    );

    await AuthService.instance.logoutCurrentUser();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _loadSummaryStats() async {
    try {
      final stats = await StatsService.getSummaryStats();
      if (!mounted) return;
      setState(() => _summaryStats = stats);
    } catch (_) {}
  }

  Future<void> _loadWifiPort() async {
    final port = await SettingsService.getWifiPort();
    if (!mounted) return;
    setState(() => _wifiPort = port);
  }

  /// 刷新余额（从 Supabase user_wallet 拉取最新值）
  Future<void> _refreshBalance() async {
    await ref.read(subscriptionProvider.notifier).refreshBalance();
  }

  /// 加载今日消费
  Future<void> _loadTodayCost() async {
    try {
      final overview = await BillingService.fetchOverview();
      if (mounted) {
        setState(() => _todayCost = overview.totalCost);
      }
    } catch (_) {
      // 静默失败
    }
  }
}

// ═══════════════════════════════════════════════════════════════
/// 带阴影的卡片组件——白色背景 + 阴影 + 圆角
// ═══════════════════════════════════════════════════════════════
class _ElevatedCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const _ElevatedCard({required this.child, this.padding, this.onTap});

  @override
  State<_ElevatedCard> createState() => _ElevatedCardState();
}

class _ElevatedCardState extends State<_ElevatedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => _controller.forward() : null,
      onTapUp: widget.onTap != null ? (_) => widget.onTap!.call() : null,
      onTapCancel: widget.onTap != null ? () => _controller.reverse() : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) =>
            Transform.scale(scale: _scaleAnimation.value, child: child),
        child: Container(
          padding: widget.padding ?? EdgeInsets.all(adaptive.Adaptive.w(16.0)),
          decoration: BoxDecoration(
            color: AppColors.getSurface(brightness: brightness),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: brightness == Brightness.dark ? 0.3 : 0.06,
                ),
                blurRadius: adaptive.Adaptive.w(12),
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: brightness == Brightness.dark ? 0.2 : 0.03,
                ),
                blurRadius: adaptive.Adaptive.w(4),
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
