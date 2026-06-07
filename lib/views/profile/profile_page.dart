/// "我的"页面
///
/// 功能列表：
/// 1. 免费/付费模式切换（影响播放器功能可用性）
/// 2. 个人设置
/// 3. 用户管理（仅 Supabase 管理员可见）
/// 4. 系统设置
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/config.dart';
import 'package:vidlang/models/base_entity.dart';
import 'package:vidlang/models/user.dart';
import 'package:vidlang/providers/subscription_provider.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/responsive_size.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _isSupabaseUser = false; // 是否 Supabase 管理员用户

  @override
  void initState() {
    super.initState();
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
    setState(() {
      _isSupabaseUser = user?.authProvider == 'supabase';
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final subState = ref.watch(subscriptionProvider);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Text(
                '我的',
                style: TextStyle(fontSize: ResponsiveSize.fontSize(context, AppTypography.fontSizeLarge), fontWeight: FontWeight.w600, color: colorScheme.onSurface),
              ),
              SizedBox(height: AppSpacing.md),

              // 模式切换卡片
              _buildModeCard(colorScheme, subState),
              SizedBox(height: AppSpacing.md),

              // 用户信息卡片
              _buildUserCard(colorScheme),
              SizedBox(height: AppSpacing.md),

              // 个人设置
              _buildSectionTitle('设置', colorScheme),
              _buildMenuItem(Icons.speed, '播放设置', '跳过片头片尾、缩略图时间', colorScheme, onTap: () {}),
              _buildMenuItem(Icons.translate, '翻译与TTS', '配置翻译和语音', colorScheme, onTap: () {}),
              _buildMenuItem(Icons.quiz_outlined, '测试设置', '题目类型和数量', colorScheme, onTap: () {}),
              const Divider(height: 1),
              SizedBox(height: AppSpacing.sm),

              // 用户管理（仅 Supabase 用户可见）
              if (_isSupabaseUser) ...[
                _buildSectionTitle('用户管理', colorScheme),
                _buildMenuItem(Icons.group_add, '添加子用户', '为家庭成员创建账号', colorScheme, onTap: () => _showAddUserDialog()),
                _buildMenuItem(Icons.people, '管理用户', '查看和管理子用户', colorScheme, onTap: () {}),
                const Divider(height: 1),
                SizedBox(height: AppSpacing.sm),
              ],

              // 系统
              _buildSectionTitle('系统', colorScheme),
              _buildMenuItem(Icons.info_outline, '关于', 'VidLang v1.0.0', colorScheme, onTap: () {}),
              _buildMenuItem(Icons.logout, '退出登录', '', colorScheme, isDestructive: true, onTap: () => _logout()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard(ColorScheme colorScheme, SubscriptionState subState) {
    final isPremium = subState.mode == SubscriptionMode.premium;
    final features = subState.features;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: isPremium
            ? LinearGradient(colors: [Colors.amber.withValues(alpha: 0.2), Colors.orange.withValues(alpha: 0.1)])
            : LinearGradient(colors: [Colors.blue.withValues(alpha: 0.1), Colors.blue.withValues(alpha: 0.05)]),
        border: Border.all(color: isPremium ? Colors.amber.withValues(alpha: 0.4) : colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(isPremium ? Icons.workspace_premium : Icons.person, color: isPremium ? Colors.amber : colorScheme.primary, size: ResponsiveSize.icon(context)),
                  SizedBox(width: 10),
                  Text(
                    isPremium ? '会员模式' : '免费模式',
                    style: TextStyle(fontSize: ResponsiveSize.fontSize(context, 16), fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                  ),
                ],
              ),
              // 切换开关
              GestureDetector(
                onTap: () {
                  ref.read(subscriptionProvider.notifier).setMode(isPremium ? SubscriptionMode.free : SubscriptionMode.premium);
                },
                child: Container(
                  width: 52,
                  height: 28,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: isPremium ? Colors.amber : colorScheme.outline.withValues(alpha: 0.3),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    alignment: isPremium ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          // 功能可用性列表
          _featureRow('翻译', features.canTranslate, '系统翻译 / DeepSeek', colorScheme),
          _featureRow('TTS 朗读', features.canTts, '系统朗读 / 阿里云', colorScheme),
          _featureRow('文字识别', features.canOcr, '系统识别 / AI', colorScheme),
          _featureRow('口语评分', features.canScoring, '评分引擎', colorScheme),
          _featureRow('AI 分析', features.canAiAnalysis, 'DeepSeek', colorScheme),
          _featureRow('云同步', features.canCloudSync, 'Supabase', colorScheme),

          if (isPremium) ...[
            SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.amber.withValues(alpha: 0.1)),
              child: Row(
                children: [
                  Icon(Icons.monetization_on, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Text(
                    '余额：¥${subState.balance.toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                  ),
                  Spacer(),
                  TextButton(
                    onPressed: () {}, // 充值入口
                    child: Text('充值', style: TextStyle(color: Colors.amber)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _featureRow(String label, bool enabled, String description, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(enabled ? Icons.check_circle : Icons.cancel, size: ResponsiveSize.fontSize(context, 16), color: enabled ? Colors.green : colorScheme.outline),
          SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: ResponsiveSize.fontSize(context, 13), color: colorScheme.onSurface)),
          SizedBox(width: 8),
          Text(description, style: TextStyle(fontSize: ResponsiveSize.fontSize(context, 11), color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildUserCard(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: AppColors.surfaceElevated),
      child: Row(
        children: [
          CircleAvatar(
            radius: ResponsiveSize.icon(context) * 0.7,
            backgroundColor: colorScheme.primary.withValues(alpha: 0.2),
            child: Icon(Icons.person, color: colorScheme.primary),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '本地用户',
                  style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                ),
                Text(_isSupabaseUser ? '已连接Supabase' : '本地模式', style: TextStyle(fontSize: ResponsiveSize.fontSize(context, 12), color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          if (!_isSupabaseUser)
            TextButton(
              onPressed: () {}, // 跳转登录
              child: Text('登录', style: TextStyle(color: colorScheme.primary)),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(fontSize: ResponsiveSize.fontSize(context, AppTypography.fontSizeSmall), fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, String subtitle, ColorScheme colorScheme, {VoidCallback? onTap, bool isDestructive = false}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: isDestructive ? colorScheme.error : colorScheme.onSurfaceVariant),
      title: Text(title, style: TextStyle(fontSize: ResponsiveSize.fontSize(context, 14), color: isDestructive ? colorScheme.error : colorScheme.onSurface)),
      subtitle: subtitle.isNotEmpty ? Text(subtitle, style: TextStyle(fontSize: ResponsiveSize.fontSize(context, 12), color: colorScheme.onSurfaceVariant)) : null,
      trailing: Icon(Icons.chevron_right, size: ResponsiveSize.fontSize(context, 18), color: colorScheme.onSurfaceVariant),
      onTap: onTap,
    );
  }

  void _showAddUserDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title: Text('添加子用户', style: TextStyle(color: colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: usernameController,
              decoration: InputDecoration(
                labelText: '用户名',
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              style: TextStyle(color: colorScheme.onSurface),
            ),
            SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: '密码',
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              style: TextStyle(color: colorScheme.onSurface),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () async {
              final username = usernameController.text.trim();
              final password = passwordController.text.trim();
              if (username.isEmpty || password.isEmpty) return;
              Navigator.pop(ctx);
              // TODO: 保存到本地 user 表
            },
            child: Text('添加', style: TextStyle(color: colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  void _logout() async {
    await DatabaseService.clearCurrentUser();
    if (!mounted) return;
    // 跳转到登录页
    Navigator.pushReplacementNamed(context, '/login');
  }
}
