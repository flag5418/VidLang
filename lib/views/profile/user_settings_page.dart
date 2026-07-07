/// 子账号设置页面
///
/// 功能：展示本地子账号列表，支持新增、编辑、删除子账号
library;

import 'package:flutter/material.dart';
import 'package:vidlang/services/app_keys_service.dart';
import 'package:vidlang/models/user.dart';
import 'package:vidlang/services/auth_service.dart';
import 'package:vidlang/widgets/app_dialogs.dart';
import 'package:vidlang/utils/dialog_utils.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';

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
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.arrowBackIos, color: cs.onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('子账号设置', style: TextStyle(fontSize: Adaptive.sp(context, 17), fontWeight: FontWeight.w600, color: cs.onSurface)),
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
                            Icon(AppIcons.peopleOutline, size: Adaptive.sp(context, 48), color: cs.outline),
                            SizedBox(height: Adaptive.h(context, 12)),
                            Text('暂无子账号', style: TextStyle(fontSize: Adaptive.sp(context, 14), color: cs.onSurfaceVariant)),
                            SizedBox(height: Adaptive.h(context, 4)),
                            Text('点击下方按钮为家庭成员创建本地账号', style: TextStyle(fontSize: Adaptive.sp(context, 12), color: cs.outline)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: Adaptive.w(context, 16), vertical: Adaptive.h(context, 8)),
                        itemCount: _users.length,
                        itemBuilder: (_, i) => _buildUserCard(_users[i], cs),
                      ),
          ),
          // 底部添加按钮
          Container(
            padding: EdgeInsets.fromLTRB(Adaptive.w(context, 16), Adaptive.h(context, 12), Adaptive.w(context, 16), Adaptive.h(context, 12) + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.1))),
            ),
            child: SizedBox(
              width: double.infinity,
              height: Adaptive.h(context, 44),
              child: FilledButton.icon(
                onPressed: () => _showUserDialog(),
                icon: Icon(AppIcons.personAddAlt, size: Adaptive.sp(context, 18)),
                label: Text('添加子账号', style: TextStyle(fontSize: Adaptive.sp(context, 15))),
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
    final displayName = user.nickname.isNotEmpty ? user.nickname : user.username;

    return Container(
      margin: EdgeInsets.only(bottom: Adaptive.h(context, 10)),
      padding: EdgeInsets.symmetric(horizontal: Adaptive.w(context, 14), vertical: Adaptive.h(context, 14)),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Adaptive.r(context, 14)),
        border: isCurrent ? Border.all(color: cs.primary.withValues(alpha: 0.4), width: 1.5) : null,
      ),
      child: Row(
        children: [
          // 头像
          CircleAvatar(
            radius: Adaptive.r(context, 22),
            backgroundColor: isCurrent ? cs.primary.withValues(alpha: 0.2) : cs.outline.withValues(alpha: 0.15),
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
              style: TextStyle(fontSize: Adaptive.sp(context, 16), fontWeight: FontWeight.w600, color: isCurrent ? cs.primary : cs.onSurfaceVariant),
            ),
          ),
          SizedBox(width: Adaptive.w(context, 12)),
          // 信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName, style: TextStyle(fontSize: Adaptive.sp(context, 15), fontWeight: FontWeight.w600, color: cs.onSurface)),
                SizedBox(height: Adaptive.h(context, 2)),
                Text(
                  '登录名：${user.username}${isCurrent ? '  ·  当前登录' : ''}',
                  style: TextStyle(fontSize: Adaptive.sp(context, 12), color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          // 操作按钮
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _iconBtn(AppIcons.edit, cs.onSurfaceVariant, () => _showUserDialog(user: user)),
              SizedBox(width: Adaptive.w(context, 4)),
              _iconBtn(AppIcons.delete, cs.error, () => _confirmDelete(user, displayName)),
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
        width: Adaptive.w(context, 36),
        height: Adaptive.w(context, 36),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(Adaptive.r(context, 10)),
        ),
        child: Icon(icon, size: Adaptive.sp(context, 18), color: color),
      ),
    );
  }

  // ==================== 添加/编辑 弹窗 ====================

  void _showUserDialog({User? user}) {
    final isEdit = user != null;
    final nicknameCtrl = TextEditingController(text: isEdit ? user.nickname : '');
    final usernameCtrl = TextEditingController(text: isEdit ? user.username : '');
    final passwordCtrl = TextEditingController();

    DialogUtils.show(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: Adaptive.w(context, 311),
              padding: EdgeInsets.all(Adaptive.w(context, 20)),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(Adaptive.r(context, 14)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题
                  Text(isEdit ? '编辑子账号' : '添加子账号',
                      style: TextStyle(fontSize: Adaptive.sp(context, 17), fontWeight: FontWeight.w600, color: cs.onSurface)),
                  SizedBox(height: Adaptive.h(context, 20)),

                  // 头像预览
                  CircleAvatar(
                    radius: Adaptive.r(context, 28),
                    backgroundColor: cs.primary.withValues(alpha: 0.15),
                    child: Text(
                      (nicknameCtrl.text.isNotEmpty ? nicknameCtrl.text : '?')[0].toUpperCase(),
                      style: TextStyle(fontSize: Adaptive.sp(context, 20), fontWeight: FontWeight.bold, color: cs.primary),
                    ),
                  ),
                  SizedBox(height: Adaptive.h(context, 20)),

                  // 昵称
                  _field(ctx, '昵称', '显示名称（可选）', nicknameCtrl, cs),
                  SizedBox(height: Adaptive.h(context, 12)),

                  // 登录名
                  _field(ctx, '登录名', '不可使用邮箱', usernameCtrl, cs, enabled: !isEdit),
                  SizedBox(height: Adaptive.h(context, 12)),

                  // 密码
                  _field(ctx, isEdit ? '新密码（留空不修改）' : '密码', '至少6位', passwordCtrl, cs, obscure: true),
                  SizedBox(height: Adaptive.h(context, 24)),

                  // 按钮
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: Adaptive.h(context, 12)),
                            side: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Adaptive.r(context, 8))),
                          ),
                          child: Text('取消', style: TextStyle(fontSize: Adaptive.sp(context, 15), color: cs.onSurfaceVariant)),
                        ),
                      ),
                      SizedBox(width: Adaptive.w(context, 12)),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            final username = usernameCtrl.text.trim();
                            final password = passwordCtrl.text.trim();
                            final nickname = nicknameCtrl.text.trim();

                            if (!isEdit && (username.isEmpty || password.isEmpty)) {
                              _toast('登录名和密码不能为空');
                              return;
                            }
                            if (!isEdit && password.length < 6) {
                              _toast('密码至少需要6位');
                              return;
                            }
                            if (isEdit && password.isNotEmpty && password.length < 6) {
                              _toast('密码至少需要6位');
                              return;
                            }

                            Navigator.pop(ctx);
                            try {
                              if (isEdit) {
                                await AuthService.instance.updateLocalUser(
                                  userCode: user.code!,
                                  nickname: nickname.isNotEmpty ? nickname : null,
                                  newPassword: password.isNotEmpty ? password : null,
                                );
                                _toast('修改成功');
                              } else {
                                await AuthService.instance.createLocalUser(
                                  username: username,
                                  password: password,
                                  nickname: nickname.isNotEmpty ? nickname : null,
                                );
                                _toast('创建成功');
                              }
                              _loadUsers();
                            } on AuthException catch (e) {
                              _toast(e.message);
                            }
                          },
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: Adaptive.h(context, 12)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Adaptive.r(context, 8))),
                          ),
                          child: Text(isEdit ? '保存' : '添加', style: TextStyle(fontSize: Adaptive.sp(context, 15))),
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

  Widget _field(BuildContext ctx, String label, String hint, TextEditingController ctrl, ColorScheme cs,
      {bool obscure = false, bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: Adaptive.sp(context, 12), color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
        SizedBox(height: Adaptive.h(context, 6)),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          enabled: enabled,
          style: TextStyle(fontSize: Adaptive.sp(context, 14), color: cs.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: Adaptive.sp(context, 14), color: cs.outline),
            filled: true,
            fillColor: enabled ? cs.surfaceContainerHighest : cs.surfaceContainerHighest.withValues(alpha: 0.5),
            contentPadding: EdgeInsets.symmetric(horizontal: Adaptive.w(context, 12), vertical: Adaptive.h(context, 10)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(Adaptive.r(context, 8)), borderSide: BorderSide.none),
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
