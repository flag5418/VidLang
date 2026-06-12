/// 用户设置页面（仅 Supabase 管理员用户可进入）
///
/// 功能：
/// 1. 修改密码（Supabase 用户）
/// 2. 添加子用户
/// 3. 管理/删除子用户
library;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vidlang/config.dart';
import 'package:vidlang/models/user.dart';
import 'package:vidlang/services/auth_service.dart';
import 'package:vidlang/theme/theme.dart';

class UserSettingsPage extends StatefulWidget {
  const UserSettingsPage({super.key});

  @override
  State<UserSettingsPage> createState() => _UserSettingsPageState();
}

class _UserSettingsPageState extends State<UserSettingsPage> {
  List<User> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final users = await AuthService.instance.getAllUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnackBar('加载用户列表失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: colorScheme.onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '用户设置',
          style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 修改密码
            _buildSectionTitle('安全', colorScheme),
            _buildMenuItem(Icons.lock_outline, '修改密码', '修改主账号密码', colorScheme,
                onTap: () => _showChangePasswordDialog()),
            const Divider(height: 1),
            SizedBox(height: AppSpacing.md),

            // 用户管理
            _buildSectionTitle('子用户管理', colorScheme),
            _buildMenuItem(Icons.group_add, '添加子用户', '为家庭成员创建本地账号', colorScheme,
                onTap: () => _showAddUserDialog()),
            SizedBox(height: 8),

            // 用户列表
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (_users.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('暂无用户', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                ),
              )
            else
              ..._users.map((user) => _buildUserTile(user, colorScheme)),
          ],
        ),
      ),
    );
  }

  // ==================== 用户列表项 ====================

  Widget _buildUserTile(User user, ColorScheme colorScheme) {
    final isCurrent = AppConfig.currentUser?.code == user.code;
    final isLocal = user.authProvider == 'local';
    final displayName = user.nickname.isNotEmpty ? user.nickname : user.username;
    final badge = user.authProvider == 'supabase' ? '主账号' : '本地用户';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.surfaceElevated,
        border: isCurrent ? Border.all(color: colorScheme.primary.withValues(alpha: 0.4)) : null,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: isCurrent
                ? colorScheme.primary.withValues(alpha: 0.2)
                : colorScheme.surfaceContainerHighest,
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 14,
                color: isCurrent ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14.sp,
                  ),
                ),
                Text(
                  '$badge${isCurrent ? ' · 当前' : ''}',
                  style: TextStyle(
                      fontSize: 12.sp, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (isLocal && !isCurrent)
            IconButton(
              icon: Icon(Icons.delete_outline, color: colorScheme.error, size: 20),
              onPressed: () => _confirmDeleteUser(user, displayName),
            ),
        ],
      ),
    );
  }

  // ==================== 修改密码 ====================

  void _showChangePasswordDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    final newPwdController = TextEditingController();
    final confirmPwdController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title: Text('修改密码', style: TextStyle(color: colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: newPwdController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: '新密码',
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              style: TextStyle(color: colorScheme.onSurface),
            ),
            SizedBox(height: 12),
            TextField(
              controller: confirmPwdController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: '确认新密码',
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
              final newPwd = newPwdController.text;
              final confirmPwd = confirmPwdController.text;
              if (newPwd.isEmpty || newPwd.length < 6) {
                _showSnackBar('密码至少需要6位');
                return;
              }
              if (newPwd != confirmPwd) {
                _showSnackBar('两次输入的密码不一致');
                return;
              }
              Navigator.pop(ctx);
              try {
                await AuthService.instance.changeSupabasePassword(newPassword: newPwd);
                _showSnackBar('密码修改成功');
              } on AuthException catch (e) {
                _showSnackBar(e.message);
              }
            },
            child: Text('确认', style: TextStyle(color: colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  // ==================== 添加子用户 ====================

  void _showAddUserDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    final usernameController = TextEditingController();
    final nicknameController = TextEditingController();
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
                labelText: '用户名（不可使用邮箱）',
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              style: TextStyle(color: colorScheme.onSurface),
            ),
            SizedBox(height: 12),
            TextField(
              controller: nicknameController,
              decoration: InputDecoration(
                labelText: '昵称（可选）',
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
              final nickname = nicknameController.text.trim();
              if (username.isEmpty || password.isEmpty) {
                _showSnackBar('用户名和密码不能为空');
                return;
              }
              if (password.length < 6) {
                _showSnackBar('密码至少需要6位');
                return;
              }
              Navigator.pop(ctx);
              try {
                await AuthService.instance.createLocalUser(
                  username: username,
                  password: password,
                  nickname: nickname.isNotEmpty ? nickname : null,
                );
                _showSnackBar('用户创建成功');
                _loadUsers(); // 刷新列表
              } on AuthException catch (e) {
                _showSnackBar(e.message);
              }
            },
            child: Text('添加', style: TextStyle(color: colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  // ==================== 删除用户 ====================

  Future<void> _confirmDeleteUser(User user, String displayName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          title: Text('确认删除', style: TextStyle(color: cs.onSurface)),
          content: Text('确定要删除用户 "$displayName" 吗？此操作不可恢复。',
              style: TextStyle(color: cs.onSurfaceVariant)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('取消', style: TextStyle(color: cs.onSurfaceVariant))),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('删除', style: TextStyle(color: cs.error)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;
    if (user.code == null) return;

    try {
      await AuthService.instance.deleteLocalUser(userCode: user.code!);
      _showSnackBar('已删除用户: $displayName');
      _loadUsers();
    } on AuthException catch (e) {
      _showSnackBar(e.message);
    }
  }

  // ==================== 通用 ====================

  Widget _buildSectionTitle(String title, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
            fontSize: AppTypography.fontSizeSmall.sp,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, String subtitle, ColorScheme colorScheme,
      {VoidCallback? onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: colorScheme.onSurfaceVariant),
      title: Text(title,
          style: TextStyle(
              fontSize: 14.sp, color: colorScheme.onSurface)),
      subtitle: subtitle.isNotEmpty
          ? Text(subtitle,
              style: TextStyle(
                  fontSize: 12.sp, color: colorScheme.onSurfaceVariant))
          : null,
      trailing:
          Icon(Icons.chevron_right, size: 18.sp, color: colorScheme.onSurfaceVariant),
      onTap: onTap,
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }
}
