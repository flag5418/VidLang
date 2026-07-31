/// "我的"页面
///
/// 布局：
/// 1. 顶部个人信息（头像、昵称）
/// 2. 模式切换（免费/收费）
/// 3. 学习统计入口
/// 4. 设置列表
/// 5. 底部固定（退出登录）
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidlang/components/dialogs/app_dialogs.dart';
import 'package:vidlang/models/base_entity.dart';
import 'package:vidlang/models/device_type.dart';
import 'package:vidlang/models/user.dart';
import 'package:vidlang/providers/subscription_provider.dart';
import 'package:vidlang/providers/theme_provider.dart';
import 'package:vidlang/services/app_keys_service.dart';
import 'package:vidlang/services/auth_service.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/learning/learning_stats_service.dart';
import 'package:vidlang/services/settings_service.dart';
// import 'package:vidlang/services/learning/stats_service.dart'; // 已合并到 LearningStatsService
import 'package:vidlang/services/tts/tts_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;
import 'package:vidlang/views/forum/forum_home_page.dart';
import 'package:vidlang/views/profile/billing_page.dart';
import 'package:vidlang/views/profile/billing_rules_page.dart';
import 'package:vidlang/views/profile/edit_profile_page.dart';
import 'package:vidlang/views/profile/learning_stats_page.dart';
import 'package:vidlang/views/profile/providers/device_type_provider.dart';
import 'package:vidlang/views/profile/providers/difficulty_provider.dart';
import 'package:vidlang/views/profile/topup_page.dart';
import 'package:vidlang/views/profile/user_settings_page.dart';

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
  _SettingItem({required this.icon, required this.title, this.subtitle, this.onTap});
}

/// 功能项数据模型（用于模式卡片中的功能标签）
class _FeatureItem {
  final IconData icon;
  final String label;
  _FeatureItem({required this.icon, required this.label});
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _isSupabaseUser = false;
  User? _currentUser;
  SummaryStats _summaryStats = const SummaryStats();
  int _companionshipDays = 0; // 陪伴天数（从注册日计算）
  int _wifiPort = 9999;
  String _ttsCacheLabel = '加载中...';

  @override
  void initState() {
    super.initState();
    _checkUser();
    _loadSummaryStats();
    _loadCompanionshipDays();
    _loadWifiPort();
    _loadTtsCacheInfo();
    _refreshBalance(); // 进入页面时刷新最新余额
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
            SliverToBoxAdapter(child: _buildProfileHeader(colorScheme, brightness)),

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
                      subtitle: ref.watch(deviceTypeProvider).isTablet ? 'iPad 布局' : 'iPhone 布局',
                      onTap: () => _showDeviceTypeCombobox(),
                    ),
                    _SettingItem(icon: AppIcons.tune, title: '学习难度', subtitle: difficulty.label, onTap: () => _showDifficultyPicker()),

                    _SettingItem(icon: AppIcons.forum, title: '论坛', subtitle: '学习交流社区', onTap: () => _navigateToForum()),
                    _SettingItem(icon: AppIcons.volumeUp, title: 'TTS 缓存管理', subtitle: _ttsCacheLabel, onTap: () => _showTtsCacheDialog()),
                    _SettingItem(icon: AppIcons.rule, title: '计费规则', subtitle: '查看各项AI功能费用', onTap: () => _navigateToBillingRulesPage()),
                    if (_isSupabaseUser)
                      _SettingItem(icon: AppIcons.manageAccounts, title: '子账号设置', subtitle: '子账号管理', onTap: () => _navigateToUserSettings()),
                    _SettingItem(icon: AppIcons.wifiTethering, title: 'WiFi 传输', subtitle: '端口：$_wifiPort', onTap: () => _showWifiPortDialog()),
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
    final displayName = _currentUser?.nickname.isNotEmpty == true ? _currentUser!.nickname : (_currentUser?.username ?? '未登录');
    final avatarPath = _currentUser?.avatar;
    // 陪伴天数：从注册日计算，和学习统计口径不同
    final companionshipLabel = _companionshipDays > 0 ? '已陪伴您 $_companionshipDays 天' : '欢迎加入 VidLang';

    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(AppSpacing.pagePadding, adaptive.Adaptive.h(12), AppSpacing.pagePadding, 0),
      padding: EdgeInsets.fromLTRB(AppSpacing.space5, adaptive.Adaptive.h(24), AppSpacing.space5, adaptive.Adaptive.h(24)),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: brightness == Brightness.dark ? 0.2 : 0.04),
            blurRadius: adaptive.Adaptive.w(12),
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: brightness == Brightness.dark ? 0.1 : 0.02),
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
                child: Hero(tag: 'profile_avatar', child: _buildAvatarWidget(colorScheme, avatarPath, displayName, size: 64)),
              ),
              SizedBox(width: adaptive.Adaptive.w(16)),
              // 信息区
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(fontSize: adaptive.Adaptive.sp(20), fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: adaptive.Adaptive.h(6)),
                    // 陪伴天数 — 从注册日计算，无图标，和昵称左对齐
                    Text(
                      companionshipLabel,
                      style: TextStyle(fontSize: adaptive.Adaptive.sp(13), color: colorScheme.onSurfaceVariant),
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
                    border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(adaptive.Adaptive.r(10)),
                  ),
                  child: Icon(AppIcons.chevronRight, size: adaptive.Adaptive.icon(18), color: colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          SizedBox(height: adaptive.Adaptive.h(20)),

          // 快速统计行（学习数据概览，点击跳转详情）
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LearningStatsPage())),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(16), vertical: adaptive.Adaptive.h(14)),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _quickStatItem(AppIcons.calendarToday, '${_summaryStats.totalDays}', '天数', colorScheme),
                  _quickStatDivider(colorScheme),
                  _quickStatItem(AppIcons.movieCreation, '${_summaryStats.videoTotal}', '视频', colorScheme),
                  _quickStatDivider(colorScheme),
                  _quickStatItem(AppIcons.musicNote, '${_summaryStats.audioTotal}', '音频', colorScheme),
                  _quickStatDivider(colorScheme),
                  _quickStatItem(AppIcons.menuBook, '${_summaryStats.articleTotal}', '文章', colorScheme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickStatItem(IconData icon, String value, String label, ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: adaptive.Adaptive.sp(18), color: cs.primary.withValues(alpha: 0.7)),
        SizedBox(height: adaptive.Adaptive.h(4)),
        Text(
          value,
          style: TextStyle(fontSize: adaptive.Adaptive.sp(17), fontWeight: FontWeight.w700, color: cs.onSurface),
        ),
        Text(
          label,
          style: TextStyle(fontSize: adaptive.Adaptive.sp(10), color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _quickStatDivider(ColorScheme cs) {
    return Container(height: adaptive.Adaptive.h(24), width: 1, color: cs.outline.withValues(alpha: 0.2));
  }

  // ==================== 头像组件 ====================

  Widget _buildAvatarWidget(ColorScheme colorScheme, String? avatarPath, String displayName, {double size = 52}) {
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
        style: TextStyle(fontSize: size * 0.35, fontWeight: FontWeight.bold, color: colorScheme.primary),
      ),
    );
  }

  // ==================== 模式切换（iOS / Android 差异化） ====================

  Widget _buildModeSwitch(ColorScheme colorScheme, SubscriptionState subState) {
    if (subState.isIOS) {
      return _buildIOSModeCard(colorScheme, subState);
    } else {
      return _buildAndroidModeCard(colorScheme, subState);
    }
  }

  /// iOS 模式区域：横向双卡片（免费 | 收费 并排）
  Widget _buildIOSModeCard(ColorScheme colorScheme, SubscriptionState subState) {
    final isPremium = subState.mode == SubscriptionMode.premium;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 左卡片：免费模式
          Expanded(
            child: _buildFreeModeCard(
              colorScheme,
              !isPremium,
              onTap: () async {
                if (isPremium) {
                  await ref.read(subscriptionProvider.notifier).setMode(SubscriptionMode.free);
                }
              },
            ),
          ),
          SizedBox(width: adaptive.Adaptive.w(12)),
          // 右卡片：收费模式
          Expanded(
            child: _buildPremiumModeCard(
              colorScheme,
              subState,
              isPremium,
              onTap: () async {
                if (!isPremium) {
                  await ref.read(subscriptionProvider.notifier).setMode(SubscriptionMode.premium);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 免费模式卡片（左侧）— 带功能说明的丰满版
  ///
  /// 与右侧收费卡片保持等高：通过 IntrinsicHeight + Expanded 布局实现
  Widget _buildFreeModeCard(ColorScheme colorScheme, bool isActive, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(AppSpacing.space5),
        decoration: BoxDecoration(
          color: isActive ? colorScheme.surface : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: isActive ? colorScheme.primary.withValues(alpha: 0.8) : Colors.transparent, width: 2),
          boxShadow: isActive
              ? [BoxShadow(color: colorScheme.primary.withValues(alpha: 0.12), blurRadius: adaptive.Adaptive.w(20), offset: const Offset(0, 8))]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行 + 选择圆圈
            Row(
              children: [
                Expanded(
                  child: Text(
                    '免费模式',
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(16),
                      fontWeight: FontWeight.w700,
                      color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                _buildSelectionIndicator(isActive, colorScheme),
              ],
            ),

            SizedBox(height: adaptive.Adaptive.h(12)),

            // ✅ 可用功能
            _buildFeatureTag(context, Icons.menu_book, '基础释义', true),
            SizedBox(height: adaptive.Adaptive.h(6)),
            _buildFeatureTag(context, Icons.record_voice_over, '标准发音', true),
            SizedBox(height: adaptive.Adaptive.h(6)),
            _buildFeatureTag(context, Icons.mic_none, '基础识别', true),

            SizedBox(height: adaptive.Adaptive.h(14)),
            // 分割线
            Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
            SizedBox(height: adaptive.Adaptive.h(12)),

            // ❌ 不可用功能
            _buildFeatureTag(context, Icons.translate, 'AI 深度翻译', false),
            SizedBox(height: adaptive.Adaptive.h(6)),
            _buildFeatureTag(context, Icons.chat_bubble_outline, 'AI 语伴对话', false),
            SizedBox(height: adaptive.Adaptive.h(6)),
            _buildFeatureTag(context, Icons.assessment_outlined, 'AI 智能评测', false),

            const Spacer(),
          ],
        ),
      ),
    );
  }

  /// 构建单个功能标签（✅ 可用 / ❌ 不可用）
  Widget _buildFeatureTag(BuildContext context, IconData icon, String label, bool available) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          available ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
          size: adaptive.Adaptive.sp(14),
          color: available ? colorScheme.primary.withValues(alpha: 0.6) : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
        ),
        SizedBox(width: adaptive.Adaptive.w(8)),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(12),
              fontWeight: available ? FontWeight.w500 : FontWeight.w400,
              color: available ? colorScheme.onSurface : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// 收费模式卡片（右侧）— 带余额和充值
  Widget _buildPremiumModeCard(ColorScheme colorScheme, SubscriptionState subState, bool isActive, {VoidCallback? onTap}) {
    final premiumColor = AppColors.premium;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(AppSpacing.space5),
        decoration: BoxDecoration(
          color: isActive ? colorScheme.surface : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: isActive ? colorScheme.primary.withValues(alpha: 0.8) : Colors.transparent, width: 2),
          boxShadow: isActive
              ? [BoxShadow(color: colorScheme.primary.withValues(alpha: 0.12), blurRadius: adaptive.Adaptive.w(20), offset: const Offset(0, 8))]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行 + 选择圆圈
            Row(
              children: [
                Expanded(
                  child: Text(
                    '收费模式',
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(16),
                      fontWeight: FontWeight.w700,
                      color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                _buildSelectionIndicator(isActive, colorScheme),
              ],
            ),

            SizedBox(height: adaptive.Adaptive.h(16)),

            // 余额显示区
            Container(
              padding: EdgeInsets.all(adaptive.Adaptive.w(12)),
              decoration: BoxDecoration(
                color: isActive ? colorScheme.primary.withValues(alpha: 0.04) : colorScheme.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '当前余额',
                    style: TextStyle(fontSize: adaptive.Adaptive.sp(11), fontWeight: FontWeight.w500, color: colorScheme.onSurfaceVariant),
                  ),
                  SizedBox(height: adaptive.Adaptive.h(4)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '¥',
                        style: TextStyle(
                          fontSize: adaptive.Adaptive.sp(14),
                          fontWeight: FontWeight.w700,
                          color: isActive ? premiumColor : colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(width: adaptive.Adaptive.w(2)),
                      Text(
                        subState.balance.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: adaptive.Adaptive.sp(24),
                          fontWeight: FontWeight.w800,
                          color: isActive ? premiumColor : colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: adaptive.Adaptive.h(16)),

            // 今日消费行
            GestureDetector(
              onTap: _navigateToBillingPage,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(4), vertical: adaptive.Adaptive.h(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '今日预估消费',
                      style: TextStyle(fontSize: adaptive.Adaptive.sp(12), color: colorScheme.onSurfaceVariant),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '¥0.00',
                          style: TextStyle(fontSize: adaptive.Adaptive.sp(12), fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                        ),
                        Icon(AppIcons.chevronRight, size: adaptive.Adaptive.sp(14), color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // 充值按钮
            SizedBox(
              width: double.infinity,
              height: adaptive.Adaptive.h(40),
              child: FilledButton(
                onPressed: _navigateToTopupPage,
                style: FilledButton.styleFrom(
                  backgroundColor: isActive ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                  foregroundColor: isActive ? Colors.white : colorScheme.onSurfaceVariant,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  padding: EdgeInsets.zero,
                ),
                child: Text(
                  '立即充值',
                  style: TextStyle(fontSize: adaptive.Adaptive.sp(14), fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 选择指示器组件
  Widget _buildSelectionIndicator(bool isActive, ColorScheme colorScheme) {
    return Container(
      width: adaptive.Adaptive.w(22),
      height: adaptive.Adaptive.w(22),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? colorScheme.primary : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border.all(color: isActive ? colorScheme.primary : colorScheme.outlineVariant.withValues(alpha: 0.5), width: 1.5),
      ),
      child: isActive ? Icon(AppIcons.check, size: adaptive.Adaptive.sp(14), color: Colors.white) : null,
    );
  }

  /// Android 模式卡片：自然展示为收费产品，无切换开关
  Widget _buildAndroidModeCard(ColorScheme colorScheme, SubscriptionState subState) {
    final balance = subState.balance;
    final premiumColor = AppColors.premium;

    return Container(
      padding: EdgeInsets.all(AppSpacing.space5),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.1)),
        boxShadow: [BoxShadow(color: colorScheme.primary.withValues(alpha: 0.04), blurRadius: adaptive.Adaptive.w(16), offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(adaptive.Adaptive.w(8)),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(adaptive.Adaptive.r(10)),
                ),
                child: Icon(AppIcons.workspacePremium, color: colorScheme.primary, size: adaptive.Adaptive.w(20)),
              ),
              SizedBox(width: adaptive.Adaptive.w(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VidLang Pro',
                      style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(17),
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'AI 驱动的沉浸式语言学习助手',
                      style: TextStyle(fontSize: adaptive.Adaptive.sp(12), color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: adaptive.Adaptive.h(20)),

          // 功能亮点
          _buildAndroidFeatureHighlights(colorScheme),

          SizedBox(height: adaptive.Adaptive.h(20)),

          // 余额 + 充值行
          Container(
            padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(16), vertical: adaptive.Adaptive.h(14)),
            decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '账户余额',
                      style: TextStyle(fontSize: adaptive.Adaptive.sp(11), fontWeight: FontWeight.w500, color: colorScheme.onSurfaceVariant),
                    ),
                    SizedBox(height: adaptive.Adaptive.h(2)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '¥',
                          style: TextStyle(fontSize: adaptive.Adaptive.sp(14), fontWeight: FontWeight.w700, color: premiumColor),
                        ),
                        SizedBox(width: adaptive.Adaptive.w(2)),
                        Text(
                          balance.toStringAsFixed(2),
                          style: TextStyle(fontSize: adaptive.Adaptive.sp(22), fontWeight: FontWeight.w800, color: premiumColor, letterSpacing: -0.5),
                        ),
                      ],
                    ),
                  ],
                ),
                FilledButton(
                  onPressed: _navigateToTopupPage,
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(20)),
                  ),
                  child: Text(
                    '立即充值',
                    style: TextStyle(fontSize: adaptive.Adaptive.sp(14), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Android 功能亮点（更自然的展示方式）
  Widget _buildAndroidFeatureHighlights(ColorScheme colorScheme) {
    final features = [
      _FeatureItem(icon: AppIcons.translate, label: '智能翻译'),
      _FeatureItem(icon: AppIcons.volumeUp, label: '标准发音'),
      _FeatureItem(icon: AppIcons.micRounded, label: '跟读评测'),
      _FeatureItem(icon: AppIcons.chatBubbleOutline, label: 'AI 对话'),
      _FeatureItem(icon: AppIcons.assignment, label: '单元评测'),
      _FeatureItem(icon: AppIcons.analytics, label: '综合评测'),
      _FeatureItem(icon: AppIcons.showChart, label: 'AI 学习分析'),
    ];

    return Wrap(
      spacing: adaptive.Adaptive.w(8),
      runSpacing: adaptive.Adaptive.h(8),
      children: features.map((f) => _buildFeatureChip(f, true)).toList(),
    );
  }

  /// 单个功能标签 Chip
  Widget _buildFeatureChip(_FeatureItem item, bool available) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(10), vertical: adaptive.Adaptive.h(6)),
      decoration: BoxDecoration(
        color: available ? colorScheme.primaryContainer.withValues(alpha: 0.5) : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(6)),
        border: Border.all(color: available ? colorScheme.primary.withValues(alpha: 0.15) : colorScheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            item.icon,
            size: adaptive.Adaptive.sp(14),
            color: available ? colorScheme.primary.withValues(alpha: 0.8) : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          SizedBox(width: adaptive.Adaptive.w(4)),
          Text(
            item.label,
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(12),
              color: available ? colorScheme.onSurface : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 学习统计 ====================
  // 注：学习统计入口已移至设置列表中，此处保留方法供未来使用

  // Widget _buildLearningStats(ColorScheme colorScheme) { ... }
  // 注：_statItem 和 _statDivider 随 _buildLearningStats 一起注释，需要时恢复

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
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.space4, vertical: AppSpacing.space3),
                  child: Row(
                    children: [
                      Container(
                        width: adaptive.Adaptive.w(32),
                        height: adaptive.Adaptive.w(32),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(8)),
                        ),
                        child: Icon(item.icon, size: adaptive.Adaptive.sp(18), color: colorScheme.primary),
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
                                style: TextStyle(fontSize: adaptive.Adaptive.sp(AppTypography.fontSizeXSmall), color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(AppIcons.chevronRight, size: adaptive.Adaptive.sp(20), color: colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
              // Add 0.5pt divider between items
              if (!isLast)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.space4),
                  child: Divider(height: 1, thickness: 0.5, color: colorScheme.outline.withValues(alpha: 0.3)),
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
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.space4, vertical: AppSpacing.space3 + 2),
          child: Row(
            children: [
              Container(
                width: adaptive.Adaptive.w(36),
                height: adaptive.Adaptive.w(36),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(adaptive.Adaptive.r(10)),
                ),
                child: Icon(AppIcons.info, size: adaptive.Adaptive.sp(18), color: colorScheme.primary.withValues(alpha: 0.8)),
              ),
              SizedBox(width: AppSpacing.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '关于',
                      style: TextStyle(fontSize: adaptive.Adaptive.sp(16), fontWeight: FontWeight.w500, color: colorScheme.onSurface),
                    ),
                    SizedBox(height: adaptive.Adaptive.h(2)),
                    Text(
                      'VidLang v1.0.0',
                      style: TextStyle(fontSize: adaptive.Adaptive.sp(13), color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(AppIcons.chevronRight, size: adaptive.Adaptive.sp(20), color: colorScheme.outline.withValues(alpha: 0.5)),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.space3),
        // 退出登录卡片（红色文字）
        _ElevatedCard(
          onTap: () => _logout(),
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.space4, vertical: AppSpacing.space3 + 2),
          child: Row(
            children: [
              Container(
                width: adaptive.Adaptive.w(36),
                height: adaptive.Adaptive.w(36),
                decoration: BoxDecoration(
                  color: colorScheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(adaptive.Adaptive.r(10)),
                ),
                child: Icon(AppIcons.logout, size: adaptive.Adaptive.sp(18), color: colorScheme.error.withValues(alpha: 0.7)),
              ),
              SizedBox(width: AppSpacing.space4),
              Text(
                '退出登录',
                style: TextStyle(fontSize: adaptive.Adaptive.sp(16), fontWeight: FontWeight.w500, color: colorScheme.error),
              ),
              const Spacer(),
              Icon(AppIcons.chevronRight, size: adaptive.Adaptive.sp(20), color: colorScheme.outline.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== 导航与对话框 ====================

  void _navigateToEditProfile() async {
    await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const EditProfilePage()));
    _checkUser();
  }

  void _navigateToUserSettings() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const UserSettingsPage()));
  }

  void _navigateToForum() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ForumHomePage()));
  }

  void _navigateToBillingPage() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const BillingPage())).then((_) {
      if (!mounted) return;
    });
  }

  void _navigateToTopupPage() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const TopupPage())).then((_) {
      if (!mounted) return;
      _refreshBalance();
    });
  }

  void _navigateToBillingRulesPage() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const BillingRulesPage()));
  }

  void _showThemePicker() async {
    final currentMode = ref.read(themeModeProvider);
    final items = AppThemeMode.values.map((mode) {
      return AppSelectionItem<AppThemeMode>(value: mode, icon: mode.icon, title: mode.label);
    }).toList();
    final result = await AppSelectionDialog.show<AppThemeMode>(
      context,
      title: '外观设置',
      subtitle: '选择你喜欢的界面风格',
      icon: Icons.palette_outlined,
      items: items,
      width: adaptive.Adaptive.w(320),
      currentValue: currentMode,
    );
    if (result != null && result != currentMode) {
      await ref.read(themeModeProvider.notifier).setMode(result);
    }
  }

  void _showDifficultyPicker() async {
    final currentLevel = ref.read(difficultyProvider);
    final items = DifficultyLevel.values.map((level) {
      return AppSelectionItem<DifficultyLevel>(value: level, icon: level.icon, title: level.label, subtitle: level.description);
    }).toList();
    final result = await AppSelectionDialog.show<DifficultyLevel>(
      context,
      title: '学习难度',
      subtitle: '选择适合你的学习水平',
      icon: Icons.school_outlined,
      items: items,
      width: adaptive.Adaptive.w(400),
      currentValue: currentLevel,
    );
    if (result != null && result != currentLevel) {
      await ref.read(difficultyProvider.notifier).setLevel(result);
    }
  }

  void _showDeviceTypeCombobox() async {
    final currentType = ref.read(deviceTypeProvider);
    final items = AppDeviceType.values.map((type) {
      return AppSelectionItem<AppDeviceType>(
        value: type,
        icon: type.isTablet ? Icons.tablet_mac : Icons.phone_iphone,
        title: type.isTablet ? 'iPad 布局' : 'iPhone 布局',
        subtitle: type.isTablet ? '按平板尺寸适配，布局更宽裕' : '按手机尺寸适配，内容紧凑',
      );
    }).toList();
    final result = await AppSelectionDialog.show<AppDeviceType>(
      context,
      title: '设备类型',
      icon: Icons.devices_rounded,
      items: items,
      currentValue: currentType,
      width: adaptive.Adaptive.w(350),
    );
    if (result != null && result != currentType) {
      await ref.read(deviceTypeProvider.notifier).setDeviceType(result);
    }
  }

  /// 设置 WiFi 传输端口 — 使用 AppInputDialog（支持 iPad 自适应）
  void _showWifiPortDialog() async {
    final result = await AppInputDialog.show(context, title: 'WiFi 传输端口', hintText: '端口号', initialValue: _wifiPort.toString(), confirmText: '确定');
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
              decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(adaptive.Adaptive.r(14))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题
                  Row(
                    children: [
                      Icon(AppIcons.volumeUp, color: cs.primary, size: adaptive.Adaptive.sp(22)),
                      SizedBox(width: adaptive.Adaptive.w(8)),
                      Text(
                        'TTS 缓存管理',
                        style: TextStyle(fontSize: adaptive.Adaptive.sp(17), fontWeight: FontWeight.w600, color: cs.onSurface),
                      ),
                    ],
                  ),
                  SizedBox(height: adaptive.Adaptive.h(16)),

                  // 当前状态 - 统计卡片
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(adaptive.Adaptive.w(12)),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(adaptive.Adaptive.r(10)),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.15), width: 0.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              '${stats.count}',
                              style: TextStyle(fontSize: adaptive.Adaptive.sp(20), fontWeight: FontWeight.bold, color: cs.primary),
                            ),
                            Text(
                              '缓存条数',
                              style: TextStyle(fontSize: adaptive.Adaptive.sp(11), color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                        Container(width: 1, height: adaptive.Adaptive.h(30), color: cs.outline.withValues(alpha: 0.3)),
                        Column(
                          children: [
                            Text(
                              stats.sizeLabel,
                              style: TextStyle(fontSize: adaptive.Adaptive.sp(16), fontWeight: FontWeight.bold, color: cs.primary),
                            ),
                            Text(
                              '占用空间',
                              style: TextStyle(fontSize: adaptive.Adaptive.sp(11), color: cs.onSurfaceVariant),
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
                      style: TextStyle(fontSize: adaptive.Adaptive.sp(13), fontWeight: FontWeight.w500, color: cs.onSurface),
                    ),
                  ),
                  SizedBox(height: adaptive.Adaptive.h(6)),
                  TextField(
                    controller: sizeController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: adaptive.Adaptive.sp(15), color: cs.onSurface),
                    decoration: InputDecoration(
                      hintText: '输入 5-200 之间的数字',
                      hintStyle: TextStyle(fontSize: adaptive.Adaptive.sp(13), color: cs.outline),
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                      contentPadding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(12), vertical: adaptive.Adaptive.h(10)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(adaptive.Adaptive.r(8)), borderSide: BorderSide.none),
                    ),
                  ),
                  SizedBox(height: adaptive.Adaptive.h(6)),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '提示：相同文本的 TTS 音频会缓存在本地，重复播放时秒开。',
                      style: TextStyle(fontSize: adaptive.Adaptive.sp(11), color: cs.onSurfaceVariant),
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
                            AppToast.show(context, 'TTS 缓存已清除', type: ToastType.success);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: adaptive.Adaptive.h(12)),
                            side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(adaptive.Adaptive.r(8))),
                          ),
                          child: Text(
                            '清除缓存',
                            style: TextStyle(fontSize: adaptive.Adaptive.sp(14), color: cs.error),
                          ),
                        ),
                      ),
                      SizedBox(width: adaptive.Adaptive.w(12)),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            final newSize = int.tryParse(sizeController.text.trim());
                            if (newSize == null || newSize < 5 || newSize > 200) {
                              AppToast.show(buildContext, '请输入 5-200 之间的数字', type: ToastType.warning);
                              return;
                            }
                            await SettingsService.setTtsCacheSize(newSize);
                            if (!mounted) return;
                            Navigator.pop(buildContext);
                            if (!mounted) return;
                            setState(() {
                              _ttsCacheLabel = '${stats.count} 条缓存 · ${stats.sizeLabel}';
                            });
                            AppToast.show(context, '已设置为 $newSize 条', type: ToastType.success);
                          },
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: adaptive.Adaptive.h(12)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(adaptive.Adaptive.r(8))),
                          ),
                          child: Text(
                            '保存',
                            style: TextStyle(fontSize: adaptive.Adaptive.sp(14), color: Colors.white),
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
    await prefs.setString('last_login_tab', user?.authProvider == 'supabase' ? 'supabase' : 'local');

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

  /// 加载陪伴天数（从用户注册日期到今天的天数）
  Future<void> _loadCompanionshipDays() async {
    try {
      final user = _currentUser;
      if (user == null) return;

      // 优先使用 createdAt，如果没有则尝试从 Supabase 获取
      DateTime? registeredAt = user.createdAt;
      if (registeredAt == null && _isSupabaseUser) {
        // 尝试从 Supabase 用户 metadata 获取
        final userData = AuthService.instance.currentUser?.userMetadata;
        final createdAtStr = userData?['created_at']?.toString();
        if (createdAtStr != null && createdAtStr.isNotEmpty) {
          registeredAt = DateTime.parse(createdAtStr);
        }
      }

      if (registeredAt != null && mounted) {
        final now = DateTime.now();
        final days = now.difference(registeredAt).inDays;
        setState(() => _companionshipDays = days > 0 ? days : 0);
      }
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

class _ElevatedCardState extends State<_ElevatedCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 100), vsync: this);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
        builder: (context, child) => Transform.scale(scale: _scaleAnimation.value, child: child),
        child: Container(
          padding: widget.padding ?? EdgeInsets.all(adaptive.Adaptive.w(16.0)),
          decoration: BoxDecoration(
            color: AppColors.getSurface(brightness: brightness),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: brightness == Brightness.dark ? 0.3 : 0.06),
                blurRadius: adaptive.Adaptive.w(12),
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: brightness == Brightness.dark ? 0.2 : 0.03),
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
