/// "我的"页面
///
/// 布局：
/// 1. 顶部个人信息（头像、昵称、登录名，右箭头进入编辑页）
/// 2. 模式切换（简化卡片，无功能列表）
/// 3. 学习统计（学习天数、视频数量、音频数量、文章数量）
/// 4. 设置（Supabase 用户首项为"用户设置"）
/// 5. 底部固定（关于 + 退出登录）
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/views/profile/billing_page.dart';
import 'package:vidlang/views/profile/edit_profile_page.dart';
import 'package:vidlang/views/profile/learning_stats_page.dart';
import 'package:vidlang/views/profile/user_settings_page.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _isSupabaseUser = false;
  User? _currentUser;
  late Future<BillingOverview> _billingOverviewFuture;

  @override
  void initState() {
    super.initState();
    _billingOverviewFuture = BillingService.fetchOverview();
    _checkUser();
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
    // 同时检查 Supabase 客户端状态，确保判断准确
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
    final subState = ref.watch(subscriptionProvider);
    final difficulty = ref.watch(difficultyProvider);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // 可滚动区域
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(AppSpacing.md.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题
                    Text(
                      '我的',
                      style: TextStyle(fontSize: AppTypography.fontSizeLarge.sp, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                    ),
                    SizedBox(height: AppSpacing.md.h),

                    // 1. 个人信息卡片
                    _buildProfileCard(colorScheme),
                    SizedBox(height: AppSpacing.md.h),

                    // 2. 模式切换
                    _buildModeSwitch(colorScheme, subState),
                    SizedBox(height: AppSpacing.md.h),

                    // 3. 学习统计
                    _buildSectionTitle('学习统计', colorScheme),
                    SizedBox(height: 8.h),
                    _buildLearningStats(colorScheme),
                    SizedBox(height: AppSpacing.md.h),

                    // 4. 设置
                    _buildSectionTitle('设置', colorScheme),
                    _buildMenuItem(Icons.palette_outlined, '外观设置', ref.watch(themeModeProvider).label, colorScheme, onTap: () => _showThemePicker()),
                    _buildMenuItem(Icons.speed_rounded, '学习难度', difficulty.label, colorScheme, onTap: () => _showDifficultyPicker()),
                    if (_isSupabaseUser)
                      _buildMenuItem(Icons.manage_accounts, '用户设置', '密码修改、子用户管理', colorScheme, onTap: () => _navigateToUserSettings()),
                    _buildMenuItem(Icons.play_circle_outline, '播放设置', '跳过片头片尾、缩略图时间', colorScheme, onTap: () {}),
                    _buildMenuItem(Icons.translate, '翻译与TTS', '配置翻译和语音', colorScheme, onTap: () {}),
                    _buildMenuItem(Icons.quiz_outlined, '测试设置', '题目类型和数量', colorScheme, onTap: () {}),
                  ],
                ),
              ),
            ),

            // 5. 底部固定
            _buildBottomBar(colorScheme),
          ],
        ),
      ),
    );
  }

  // ==================== 个人信息卡片 ====================

  /// 获取当前主题下的卡片背景色
  Color _cardColor(ColorScheme cs) {
    return cs.brightness == Brightness.dark ? AppColors.surfaceElevated : AppColors.lightSurface;
  }

  Widget _buildProfileCard(ColorScheme colorScheme) {
    final displayName = _currentUser?.nickname.isNotEmpty == true ? _currentUser!.nickname : (_currentUser?.username ?? '未登录');
    final loginName = _currentUser?.username ?? '';

    return GestureDetector(
      onTap: () => _navigateToEditProfile(),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16.r), color: _cardColor(colorScheme)),
        child: Row(
          children: [
            // 头像
            CircleAvatar(
              radius: 28.r,
              backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold, color: colorScheme.primary),
              ),
            ),
            SizedBox(width: 14.w),
            // 昵称 + 登录名
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    loginName,
                    style: TextStyle(fontSize: 13.sp, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            // 右箭头
            Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant, size: 24.w),
          ],
        ),
      ),
    );
  }

  // ==================== 模式切换（简化版） ====================

  Widget _buildModeSwitch(ColorScheme colorScheme, SubscriptionState subState) {
    final isPremium = subState.mode == SubscriptionMode.premium;
    final billingPanelColor = isPremium
        ? (colorScheme.brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.08) : Colors.amber.withValues(alpha: 0.12))
        : colorScheme.primary.withValues(alpha: 0.08);
    final billingButtonColor = isPremium
        ? (colorScheme.brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.10) : Colors.amber.withValues(alpha: 0.18))
        : colorScheme.primary.withValues(alpha: 0.12);
    final billingBorderColor = isPremium
        ? (colorScheme.brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.06) : Colors.amber.withValues(alpha: 0.26))
        : colorScheme.primary.withValues(alpha: 0.14);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14.r),
        gradient: isPremium
            ? LinearGradient(colors: [Colors.amber.withValues(alpha: 0.2), Colors.orange.withValues(alpha: 0.1)])
            : LinearGradient(colors: [Colors.blue.withValues(alpha: 0.1), Colors.blue.withValues(alpha: 0.05)]),
        border: Border.all(color: isPremium ? Colors.amber.withValues(alpha: 0.4) : colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        spacing: 12.h,
        children: [
          Row(
            children: [
              Icon(isPremium ? Icons.workspace_premium : Icons.person, color: isPremium ? Colors.amber : colorScheme.primary, size: 22.w),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPremium ? '收费模式' : '免费模式',
                      style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                    ),
                    Text(
                      '余额：¥${subState.balance.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 12.sp, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (isPremium) ...[
                GestureDetector(
                  onTap: () {
                    // TODO: 充值入口
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8.r), color: Colors.amber.withValues(alpha: 0.2)),
                    child: Text(
                      '充值',
                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: Colors.amber),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
              ],
              GestureDetector(
                onTap: () {
                  ref.read(subscriptionProvider.notifier).setMode(isPremium ? SubscriptionMode.free : SubscriptionMode.premium);
                },
                child: Container(
                  width: 52.w,
                  height: 28.h,
                  padding: EdgeInsets.all(2.w),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14.r),
                    color: isPremium ? Colors.amber : colorScheme.outline.withValues(alpha: 0.3),
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

          if (isPremium)
            FutureBuilder<BillingOverview>(
              future: _billingOverviewFuture,
              builder: (context, snapshot) {
                final dayTotal = snapshot.data?.dayTotal ?? 0;
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: billingPanelColor,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: billingBorderColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10.r),
                            // color: isPremium ? Colors.white.withValues(alpha: 0.08) : colorScheme.primary.withValues(alpha: 0.08),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '当日消费',
                                    style: TextStyle(fontSize: 11.sp, color: colorScheme.onSurfaceVariant),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    '¥${dayTotal.toStringAsFixed(4)}',
                                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                                  ),
                                ],
                              ),

                              GestureDetector(
                                onTap: _navigateToBillingPage,
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10.r),
                                    color: billingButtonColor,
                                    border: Border.all(color: billingBorderColor),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.receipt_long_outlined, size: 16.sp, color: isPremium ? Colors.amber : colorScheme.primary),
                                      SizedBox(width: 6.w),
                                      Text(
                                        '计费明细',
                                        style: TextStyle(
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w600,
                                          color: isPremium ? colorScheme.onSurface : colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ==================== 学习统计 ====================

  Widget _buildLearningStats(ColorScheme colorScheme) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const LearningStatsPage()));
      },
      child: Row(
        children: [
          _statCard(Icons.calendar_today, '学习天数', '0', colorScheme),
          SizedBox(width: 8.w),
          _statCard(Icons.video_library, '视频', '0', colorScheme),
          SizedBox(width: 8.w),
          _statCard(Icons.music_note, '音频', '0', colorScheme),
          SizedBox(width: 8.w),
          _statCard(Icons.article, '文章', '0', colorScheme),
        ],
      ),
    );
  }

  Widget _statCard(IconData icon, String label, String value, ColorScheme colorScheme) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const LearningStatsPage()));
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 8.w),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12.r), color: _cardColor(colorScheme)),
          child: Column(
            children: [
              Icon(icon, size: 22.w, color: colorScheme.primary.withValues(alpha: 0.7)),
              SizedBox(height: 8.h),
              Text(
                value,
                style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
              ),
              SizedBox(height: 4.h),
              Text(
                label,
                style: TextStyle(fontSize: 11.sp, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== 底部固定栏 ====================

  Widget _buildBottomBar(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.1))),
      ),
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMenuItem(Icons.info_outline, '关于', 'VidLang v1.0.0', colorScheme, onTap: () {}),
          _buildMenuItem(Icons.logout, '退出登录', '', colorScheme, isDestructive: true, onTap: () => _logout()),
        ],
      ),
    );
  }

  // ==================== 通用组件 ====================

  Widget _buildSectionTitle(String title, ColorScheme colorScheme) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Text(
        title,
        style: TextStyle(fontSize: AppTypography.fontSizeSmall.sp, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, String subtitle, ColorScheme colorScheme, {VoidCallback? onTap, bool isDestructive = false}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 22.w, color: isDestructive ? colorScheme.error : colorScheme.onSurfaceVariant),
      title: Text(
        title,
        style: TextStyle(fontSize: 14.sp, color: isDestructive ? colorScheme.error : colorScheme.onSurface),
      ),
      subtitle: subtitle.isNotEmpty
          ? Text(
              subtitle,
              style: TextStyle(fontSize: 12.sp, color: colorScheme.onSurfaceVariant),
            )
          : null,
      trailing: Icon(Icons.chevron_right, size: 18.w, color: colorScheme.onSurfaceVariant),
      onTap: onTap,
    );
  }

  // ==================== 导航 ====================

  void _navigateToEditProfile() async {
    final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const EditProfilePage()));
    if (result == true) {
      _checkUser(); // 刷新用户信息
    }
  }

  void _navigateToUserSettings() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const UserSettingsPage()));
  }

  void _navigateToBillingPage() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const BillingPage())).then((_) {
      if (!mounted) return;
      setState(() {
        _billingOverviewFuture = BillingService.fetchOverview();
      });
    });
  }

  // ==================== 主题切换 ====================

  void _showThemePicker() {
    final currentMode = ref.read(themeModeProvider);

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Text(
                    '外观设置',
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: cs.onSurface),
                  ),
                ),
                SizedBox(height: 12.h),
                ...AppThemeMode.values.map((mode) {
                  final isSelected = mode == currentMode;
                  return ListTile(
                    leading: Icon(mode.icon, color: isSelected ? cs.primary : cs.onSurfaceVariant),
                    title: Text(
                      mode.label,
                      style: TextStyle(color: isSelected ? cs.primary : cs.onSurface, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal),
                    ),
                    trailing: isSelected ? Icon(Icons.check, color: cs.primary, size: 20) : null,
                    onTap: () {
                      ref.read(themeModeProvider.notifier).setMode(mode);
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==================== 退出登录 ====================

  void _showDifficultyPicker() {
    final currentLevel = ref.read(difficultyProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final maxHeight = MediaQuery.of(ctx).size.height * 0.7;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Text(
                      '学习难度',
                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: cs.onSurface),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: DifficultyLevel.values.map((level) {
                          final isSelected = level == currentLevel;
                          return ListTile(
                            leading: Icon(level.icon, color: isSelected ? cs.primary : cs.onSurfaceVariant),
                            title: Text(
                              level.label,
                              style: TextStyle(
                                color: isSelected ? cs.primary : cs.onSurface,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              level.description,
                              style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant),
                            ),
                            trailing: isSelected ? Icon(Icons.check, color: cs.primary, size: 20) : null,
                            onTap: () {
                              ref.read(difficultyProvider.notifier).setLevel(level);
                              Navigator.pop(ctx);
                            },
                          );
                        }).toList(),
                      ),
                    ),
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          title: Text('退出登录', style: TextStyle(color: cs.onSurface)),
          content: Text('确定要退出当前用户吗？', style: TextStyle(color: cs.onSurfaceVariant)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('取消', style: TextStyle(color: cs.onSurfaceVariant)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('退出', style: TextStyle(color: cs.error)),
            ),
          ],
        );
      },
    );
    if (confirm != true || !mounted) return;

    // 保存登录名供下次登录时自动填充
    final user = AppConfig.currentUser;
    final loginName = user?.email ?? user?.username ?? '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_login_name', loginName);
    await prefs.setString('last_login_tab', user?.authProvider == 'supabase' ? 'supabase' : 'local');

    await AuthService.instance.logoutCurrentUser();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }
}
