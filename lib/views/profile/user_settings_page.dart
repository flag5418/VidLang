/// 子账号设置页面
///
/// 功能：展示本地子账号列表，支持新增、编辑、删除子账号
library;

import 'package:flutter/material.dart';
import 'package:vidlang/components/ui/ui_components.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

import 'package:vidlang/services/app_keys_service.dart';
import 'package:vidlang/models/user.dart';
import 'package:vidlang/services/auth_service.dart';
import 'package:vidlang/components/dialogs/app_dialogs.dart';
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
        _users = users.where((u) => u.authProvider == 'local').toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('加载失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppNavBar(
        title: '子账号设置',
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: cs.primary))
                : _users.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          AppIcons.peopleOutline,
                          size: adaptive.Adaptive.sp(48),
                          color: cs.outline,
                        ),
                        SizedBox(height: adaptive.Adaptive.h(12)),
                        Text(
                          '暂无子账号',
                          style: TextStyle(
                            fontSize: adaptive.Adaptive.sp(14),
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(height: adaptive.Adaptive.h(4)),
                        Text(
                          '点击下方按钮为家庭成员创建本地账号',
                          style: TextStyle(
                            fontSize: adaptive.Adaptive.sp(12),
                            color: cs.outline,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(
                      horizontal: adaptive.Adaptive.w(16),
                      vertical: adaptive.Adaptive.h(8),
                    ),
                    itemCount: _users.length,
                    itemBuilder: (_, i) => _buildUserCard(_users[i], cs),
                  ),
          ),
          // 底部添加按钮
          Container(
            padding: EdgeInsets.fromLTRB(
              adaptive.Adaptive.w(16),
              adaptive.Adaptive.h(12),
              adaptive.Adaptive.w(16),
              adaptive.Adaptive.h(12) + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(
                top: BorderSide(color: cs.outline.withValues(alpha: 0.1)),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: adaptive.Adaptive.h(44),
              child: FilledButton.icon(
                onPressed: () => _showUserDialog(),
                icon: Icon(
                  AppIcons.personAddAlt,
                  size: adaptive.Adaptive.sp(18),
                ),
                label: Text(
                  '添加子账号',
                  style: TextStyle(fontSize: adaptive.Adaptive.sp(15)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 用户卡片 ====================

  Widget _buildUserCard(User user, ColorScheme cs) {
    final isCurrent = AppKeysService.currentUser?.code == user.code;
    final displayName = user.nickname.isNotEmpty
        ? user.nickname
        : user.username;

    return BaseCard.outlined(
      margin: EdgeInsets.only(bottom: adaptive.Adaptive.h(10)),
      padding: EdgeInsets.symmetric(
        horizontal: adaptive.Adaptive.w(14),
        vertical: adaptive.Adaptive.h(14),
      ),
      backgroundColor: cs.surfaceContainerHighest,
      borderRadius: adaptive.Adaptive.r(14),
      child: Row(
        children: [
          // 头像
          Avatar(text: displayName, size: AvatarSize.sm),
          SizedBox(width: adaptive.Adaptive.w(12)),
          // 信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(15),
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                SizedBox(height: adaptive.Adaptive.h(2)),
                Text(
                  '登录名：${user.username}${isCurrent ? '  ·  当前登录' : ''}',
                  style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(12),
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // 操作按钮
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _iconBtn(
                AppIcons.edit,
                cs.onSurfaceVariant,
                () => _showUserDialog(user: user),
              ),
              SizedBox(width: adaptive.Adaptive.w(4)),
              _iconBtn(
                AppIcons.delete,
                cs.error,
                () => _confirmDelete(user, displayName),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: adaptive.Adaptive.w(36),
        height: adaptive.Adaptive.w(36),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(10)),
        ),
        child: Icon(icon, size: adaptive.Adaptive.sp(18), color: color),
      ),
    );
  }

  // ==================== 添加/编辑 弹窗 ====================

  void _showUserDialog({User? user}) {
    final isEdit = user != null;
    final nicknameCtrl = TextEditingController(
      text: isEdit ? user.nickname : '',
    );
    final usernameCtrl = TextEditingController(
      text: isEdit ? user.username : '',
    );
    final passwordCtrl = TextEditingController();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      barrierLabel: 'UserDialog',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) {
        final cs = Theme.of(context).colorScheme;
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: adaptive.Adaptive.w(311),
              padding: EdgeInsets.all(adaptive.Adaptive.w(20)),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(adaptive.Adaptive.r(14)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题
                  Text(
                    isEdit ? '编辑子账号' : '添加子账号',
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(17),
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  SizedBox(height: adaptive.Adaptive.h(20)),

                  // 头像预览
                  CircleAvatar(
                    radius: adaptive.Adaptive.r(28),
                    backgroundColor: cs.primary.withValues(alpha: 0.15),
                    child: Text(
                      (nicknameCtrl.text.isNotEmpty
                              ? nicknameCtrl.text
                              : '?')[0]
                          .toUpperCase(),
                      style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(20),
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    ),
                  ),
                  SizedBox(height: adaptive.Adaptive.h(20)),

                  // 昵称
                  _field(context, '昵称', '显示名称（可选）', nicknameCtrl, cs),
                  SizedBox(height: adaptive.Adaptive.h(12)),

                  // 登录名
                  _field(
                    context,
                    '登录名',
                    '不可使用邮箱',
                    usernameCtrl,
                    cs,
                    enabled: !isEdit,
                  ),
                  SizedBox(height: adaptive.Adaptive.h(12)),

                  // 密码
                  _field(
                    context,
                    isEdit ? '新密码（留空不修改）' : '密码',
                    '至少6位',
                    passwordCtrl,
                    cs,
                    obscure: true,
                  ),
                  SizedBox(height: adaptive.Adaptive.h(24)),

                  // 按钮
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: adaptive.Adaptive.h(12),
                            ),
                            side: BorderSide(
                              color: cs.outline.withValues(alpha: 0.3),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                adaptive.Adaptive.r(8),
                              ),
                            ),
                          ),
                          child: Text(
                            '取消',
                            style: TextStyle(
                              fontSize: adaptive.Adaptive.sp(15),
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: adaptive.Adaptive.w(12)),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            final username = usernameCtrl.text.trim();
                            final password = passwordCtrl.text.trim();
                            final nickname = nicknameCtrl.text.trim();

                            if (!isEdit &&
                                (username.isEmpty || password.isEmpty)) {
                              _toast('登录名和密码不能为空');
                              return;
                            }
                            if (!isEdit && password.length < 6) {
                              _toast('密码至少需要6位');
                              return;
                            }
                            if (isEdit &&
                                password.isNotEmpty &&
                                password.length < 6) {
                              _toast('密码至少需要6位');
                              return;
                            }

                            Navigator.of(context).pop();
                            try {
                              if (isEdit) {
                                await AuthService.instance.updateLocalUser(
                                  userCode: user.code!,
                                  nickname: nickname.isNotEmpty
                                      ? nickname
                                      : null,
                                  newPassword: password.isNotEmpty
                                      ? password
                                      : null,
                                );
                                _toast('修改成功');
                              } else {
                                await AuthService.instance.createLocalUser(
                                  username: username,
                                  password: password,
                                  nickname: nickname.isNotEmpty
                                      ? nickname
                                      : null,
                                );
                                _toast('创建成功');
                              }
                              _loadUsers();
                            } on AuthException catch (e) {
                              _toast(e.message);
                            }
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
                            isEdit ? '保存' : '添加',
                            style: TextStyle(
                              fontSize: adaptive.Adaptive.sp(15),
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
      transitionBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }

  Widget _field(
    BuildContext ctx,
    String label,
    String hint,
    TextEditingController ctrl,
    ColorScheme cs, {
    bool obscure = false,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: adaptive.Adaptive.sp(12),
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: adaptive.Adaptive.h(6)),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          enabled: enabled,
          style: TextStyle(
            fontSize: adaptive.Adaptive.sp(14),
            color: cs.onSurface,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: adaptive.Adaptive.sp(14),
              color: cs.outline,
            ),
            filled: true,
            fillColor: enabled
                ? cs.surfaceContainerHighest
                : cs.surfaceContainerHighest.withValues(alpha: 0.5),
            contentPadding: EdgeInsets.symmetric(
              horizontal: adaptive.Adaptive.w(12),
              vertical: adaptive.Adaptive.h(10),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(adaptive.Adaptive.r(8)),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  // ==================== 删除确认 ====================

  Future<void> _confirmDelete(User user, String displayName) async {
    final ok = await AppConfirmDialog.show(
      context,
      title: '删除子账号',
      content: '确定要删除 "$displayName" 吗？\n该操作不可恢复。',
      confirmText: '删除',
      cancelText: '取消',
      destructive: true,
    );
    if (ok != true) return;
    if (user.code == null) return;

    try {
      await AuthService.instance.deleteLocalUser(userCode: user.code!);
      _toast('已删除 $displayName');
      _loadUsers();
    } on AuthException catch (e) {
      _toast(e.message);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    AppToast.show(context, msg);
  }
}
