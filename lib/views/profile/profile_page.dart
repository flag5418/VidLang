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
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:vidlang/config.dart';
import 'package:vidlang/models/base_entity.dart';
import 'package:vidlang/models/billing_summary.dart';
import 'package:vidlang/models/user.dart';
import 'package:vidlang/providers/difficulty_provider.dart';
import 'package:vidlang/providers/subscription_provider.dart';
import 'package:vidlang/providers/theme_provider.dart';
import 'package:vidlang/services/auth_service.dart';
import 'package:vidlang/services/billing_service.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/settings_service.dart';
import 'package:vidlang/services/stats_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/views/profile/billing_page.dart';
import 'package:vidlang/views/profile/edit_profile_page.dart';
import 'package:vidlang/views/profile/learning_stats_page.dart';
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
  _SettingItem({required this.icon, required this.title, this.subtitle, this.onTap});
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _isSupabaseUser = false;
  User? _currentUser;
  late Future<BillingOverview> _billingOverviewFuture;
  SummaryStats _summaryStats = const SummaryStats();
  int _wifiPort = 9999;

  @override
  void initState() {
    super.initState();
    _billingOverviewFuture = BillingService.fetchOverview();
    _checkUser();
    _loadSummaryStats();
    _loadWifiPort();
  }

  Future<void> _checkUser() async {
    var user = AppConfig.currentUser;
    if (user == null) {
      final code = await DatabaseService.getCurrentUserCode();
      if (code != null && code.isNotEmpty) {
        user = await BaseEntityExtension.findByCode<User>(code, () => User());
        AppConfig.currentUser = user;
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
      backgroundColor: AppColors.getSurface(brightness: brightness),
      appBar: AppBar(
        title: Text(
          '我的',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
        ),
        elevation: 0,
        backgroundColor: AppColors.getSurface(brightness: brightness),
        scrolledUnderElevation: 0.5,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding, vertical: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 个人信息卡片
              _buildProfileCard(colorScheme),
              SizedBox(height: AppSpacing.lg),

              // 2. 模式切换
              _buildModeSwitch(colorScheme, subState),
              SizedBox(height: AppSpacing.lg),

              // 3. 学习统计入口
              _buildSectionTitle('学习统计', colorScheme),
              _buildLearningStats(colorScheme),
              SizedBox(height: AppSpacing.lg),

              // 4. 设置列表
              _buildSectionTitle('设置', colorScheme),
              _buildSettingsCard(colorScheme, [
                _SettingItem(
                  icon: Icons.palette_outlined,
                  title: '外观设置',
                  subtitle: ref.watch(themeModeProvider).label,
                  onTap: () => _showThemePicker(),
                ),
                _SettingItem(
                  icon: Icons.tune_rounded,
                  title: '学习难度',
                  subtitle: difficulty.label,
                  onTap: () => _showDifficultyPicker(),
                ),
                if (_isSupabaseUser)
                  _SettingItem(
                    icon: Icons.manage_accounts_outlined,
                    title: '子账号设置',
                    subtitle: '子账号管理',
                    onTap: () => _navigateToUserSettings(),
                  ),
                _SettingItem(
                  icon: Icons.wifi_tethering_outlined,
                  title: 'WiFi 传输',
                  subtitle: '端口：$_wifiPort',
                  onTap: () => _showWifiPortDialog(),
                ),
              ]),
              SizedBox(height: AppSpacing.lg),

              // 5. 底部操作
              _buildBottomActions(colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ColorScheme colorScheme) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title,
        style: TextStyle(fontSize: AppTypography.fontSizeSmall.sp, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant),
      ),
    );
  }

  // ==================== 个人信息 ====================

  Widget _buildProfileCard(ColorScheme colorScheme) {
    final displayName = _currentUser?.nickname.isNotEmpty == true ? _currentUser!.nickname : (_currentUser?.username ?? '未登录');
    final loginName = _currentUser?.username ?? '';
    final avatarPath = _currentUser?.avatar;

    return GestureDetector(
      onTap: () => _navigateToEditProfile(),
      child: Container(
        padding: EdgeInsets.all(AppSpacing.space5),
        decoration: BoxDecoration(
          color: AppColors.getSurfaceElevated(brightness: Theme.of(context).brightness),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            _buildAvatarWidget(colorScheme, avatarPath, displayName),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    loginName,
                    style: TextStyle(fontSize: 13.sp, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant, size: 24.w),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarWidget(ColorScheme colorScheme, String? avatarPath, String displayName) {
    if (avatarPath != null && avatarPath.isNotEmpty) {
      final file = File(avatarPath);
      if (file.existsSync()) {
        return ClipOval(child: Image.file(file, width: 52.w, height: 52.w, fit: BoxFit.cover));
      }
    }
    return CircleAvatar(
      radius: 26.r,
      backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
        style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold, color: colorScheme.primary),
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
            ? Colors.amber.withValues(alpha: 0.08)
            : colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isPremium
              ? Colors.amber.withValues(alpha: 0.25)
              : colorScheme.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isPremium ? Icons.workspace_premium : Icons.person_outline,
            color: isPremium ? Colors.amber : colorScheme.primary,
            size: 22.w,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPremium ? '收费模式' : '免费模式',
                  style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                ),
                SizedBox(height: 2.h),
                Text(
                  '余额：¥${subState.balance.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 12.sp, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (isPremium) ...[
            GestureDetector(
              onTap: () {},
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  '充值',
                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: Colors.amber),
                ),
              ),
            ),
            SizedBox(width: 12.w),
          ],
          // Toggle switch
          GestureDetector(
            onTap: () {
              ref.read(subscriptionProvider.notifier).setMode(isPremium ? SubscriptionMode.free : SubscriptionMode.premium);
            },
            child: Container(
              width: 50.w,
              height: 28.h,
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14.r),
                color: isPremium ? Colors.amber : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: isPremium ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 24.w,
                  height: 24.w,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 学习统计 ====================

  Widget _buildLearningStats(ColorScheme colorScheme) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LearningStatsPage())),
      child: Container(
        padding: EdgeInsets.all(AppSpacing.space4),
        decoration: BoxDecoration(
          color: AppColors.getSurfaceElevated(brightness: Theme.of(context).brightness),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            _statItem(Icons.calendar_today_outlined, '${_summaryStats.totalDays}', '天数', colorScheme),
            _statDivider(colorScheme),
            _statItem(Icons.movie_outlined, '${_summaryStats.videoTotal}', '视频', colorScheme),
            _statDivider(colorScheme),
            _statItem(Icons.music_note_outlined, '${_summaryStats.audioTotal}', '音频', colorScheme),
            _statDivider(colorScheme),
            _statItem(Icons.menu_book_outlined, '${_summaryStats.articleTotal}', '文章', colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label, ColorScheme colorScheme) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20.sp, color: colorScheme.primary.withValues(alpha: 0.7)),
          SizedBox(height: 6.h),
          Text(
            value,
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(fontSize: AppTypography.fontSizeXSmall, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _statDivider(ColorScheme colorScheme) {
    return Container(
      height: 30.h,
      width: 1.w,
      color: colorScheme.outline.withValues(alpha: 0.3),
    );
  }

  // ==================== 设置列表 ====================

  Widget _buildSettingsCard(ColorScheme colorScheme, List<_SettingItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurfaceElevated(brightness: Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          final item = items[i];
          return GestureDetector(
            onTap: item.onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.space4, vertical: AppSpacing.space3),
              child: Row(
                children: [
                  Container(
                    width: 32.w,
                    height: 32.w,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(item.icon, size: 18.sp, color: colorScheme.primary),
                  ),
                  SizedBox(width: AppSpacing.space4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(fontSize: AppTypography.fontSizeBase.sp, fontWeight: FontWeight.w500, color: colorScheme.onSurface),
                        ),
                        if (item.subtitle != null) ...[
                          SizedBox(height: 2.h),
                          Text(
                            item.subtitle!,
                            style: TextStyle(fontSize: AppTypography.fontSizeXSmall.sp, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 20.sp, color: colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ==================== 底部操作 ====================

  Widget _buildBottomActions(ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceElevated(brightness: Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          _bottomActionItem('关于', 'VidLang v1.0.0', colorScheme, onTap: () {}),
          Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.3)),
          _bottomActionItem('退出登录', null, colorScheme, isDestructive: true, onTap: () => _logout()),
        ],
      ),
    );
  }

  Widget _bottomActionItem(String title, String? subtitle, ColorScheme colorScheme,
      {bool isDestructive = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.space2),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: AppTypography.fontSizeBase.sp,
                      fontWeight: FontWeight.w500,
                      color: isDestructive ? colorScheme.error : colorScheme.onSurface,
                    ),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: AppTypography.fontSizeXSmall.sp, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
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

  void _navigateToBillingPage() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const BillingPage())).then((_) {
      if (!mounted) return;
      setState(() => _billingOverviewFuture = BillingService.fetchOverview());
    });
  }

  void _showThemePicker() async {
    final currentMode = ref.read(themeModeProvider);
    final items = AppThemeMode.values.map((mode) {
      final isSelected = mode == currentMode;
      return AppBottomSheetMenuItem(
        text: mode.label,
        icon: mode.icon,
        trailing: isSelected ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary, size: 20.sp) : null,
        onTap: () => ref.read(themeModeProvider.notifier).setMode(mode),
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
        trailing: isSelected ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary, size: 20.sp) : null,
        onTap: () => ref.read(difficultyProvider.notifier).setLevel(level),
      );
    }).toList();
    await AppBottomSheetMenu.show(context, title: '学习难度', items: items);
  }

  void _showWifiPortDialog() {
    final controller = TextEditingController(text: _wifiPort.toString());
    showGeneralDialog(
      context: context,
      pageBuilder: (buildContext, animation, secondaryAnimation) {
        return TDInputDialog(
          textEditingController: controller,
          title: 'WiFi 传输端口',
          content: '设置 WiFi 传输服务端口（1024-65535）',
          hintText: '端口号',
          leftBtn: TDDialogButtonOptions(title: '取消', action: () => Navigator.pop(buildContext)),
          rightBtn: TDDialogButtonOptions(
            title: '确定',
            action: () async {
              final port = int.tryParse(controller.text.trim());
              if (port != null && port >= 1024 && port <= 65535) {
                await SettingsService.setWifiPort(port);
                if (mounted) setState(() => _wifiPort = port);
                Navigator.pop(buildContext);
              } else {
                ScaffoldMessenger.of(buildContext).showSnackBar(const SnackBar(content: Text('端口号需在 1024-65535 之间')));
              }
            },
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

    final user = AppConfig.currentUser;
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

  Future<void> _loadWifiPort() async {
    final port = await SettingsService.getWifiPort();
    if (!mounted) return;
    setState(() => _wifiPort = port);
  }
}
