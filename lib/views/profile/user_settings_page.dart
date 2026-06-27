/// 子账号设置页面
///
/// 功能：展示本地子账号列表，支持新增、编辑、删除子账号
library;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vidlang/config.dart';
import 'package:vidlang/models/user.dart';
import 'package:vidlang/services/auth_service.dart';
import 'package:vidlang/widgets/app_dialogs.dart';
import 'package:vidlang/utils/dialog_utils.dart';

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
          icon: Icon(Icons.arrow_back_ios, color: cs.onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('子账号设置', style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600, color: cs.onSurface)),
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
                            Icon(Icons.people_outline, size: 48.sp, color: cs.outline),
                            SizedBox(height: 12.h),
                            Text('暂无子账号', style: TextStyle(fontSize: 14.sp, color: cs.onSurfaceVariant)),
                            SizedBox(height: 4.h),
                            Text('点击下方按钮为家庭成员创建本地账号', style: TextStyle(fontSize: 12.sp, color: cs.outline)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                        itemCount: _users.length,
                        itemBuilder: (_, i) => _buildUserCard(_users[i], cs),
                      ),
          ),
          // 底部添加按钮
          Container(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.1))),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 44.h,
              child: FilledButton.icon(
                onPressed: () => _showUserDialog(),
                icon: Icon(Icons.person_add_alt, size: 18.sp),
                label: Text('添加子账号', style: TextStyle(fontSize: 15.sp)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 用户卡片 ====================

  Widget _buildUserCard(User user, ColorScheme cs) {
    final isCurrent = AppConfig.currentUser?.code == user.code;
    final displayName = user.nickname.isNotEmpty ? user.nickname : user.username;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14.r),
        border: isCurrent ? Border.all(color: cs.primary.withValues(alpha: 0.4), width: 1.5) : null,
      ),
      child: Row(
        children: [
          // 头像
          CircleAvatar(
            radius: 22.r,
            backgroundColor: isCurrent ? cs.primary.withValues(alpha: 0.2) : cs.outline.withValues(alpha: 0.15),
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: isCurrent ? cs.primary : cs.onSurfaceVariant),
            ),
          ),
          SizedBox(width: 12.w),
          // 信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600, color: cs.onSurface)),
                SizedBox(height: 2.h),
                Text(
                  '登录名：${user.username}${isCurrent ? '  ·  当前登录' : ''}',
                  style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          // 操作按钮
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _iconBtn(Icons.edit_outlined, cs.onSurfaceVariant, () => _showUserDialog(user: user)),
              SizedBox(width: 4.w),
              _iconBtn(Icons.delete_outline, cs.error, () => _confirmDelete(user, displayName)),
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
        width: 36.w,
        height: 36.w,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Icon(icon, size: 18.sp, color: color),
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
              width: 311.w,
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题
                  Text(isEdit ? '编辑子账号' : '添加子账号',
                      style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600, color: cs.onSurface)),
                  SizedBox(height: 20.h),

                  // 头像预览
                  CircleAvatar(
                    radius: 28.r,
                    backgroundColor: cs.primary.withValues(alpha: 0.15),
                    child: Text(
                      (nicknameCtrl.text.isNotEmpty ? nicknameCtrl.text : '?')[0].toUpperCase(),
                      style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: cs.primary),
                    ),
                  ),
                  SizedBox(height: 20.h),

                  // 昵称
                  _field(ctx, '昵称', '显示名称（可选）', nicknameCtrl, cs),
                  SizedBox(height: 12.h),

                  // 登录名
                  _field(ctx, '登录名', '不可使用邮箱', usernameCtrl, cs, enabled: !isEdit),
                  SizedBox(height: 12.h),

                  // 密码
                  _field(ctx, isEdit ? '新密码（留空不修改）' : '密码', '至少6位', passwordCtrl, cs, obscure: true),
                  SizedBox(height: 24.h),

                  // 按钮
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            side: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                          ),
                          child: Text('取消', style: TextStyle(fontSize: 15.sp, color: cs.onSurfaceVariant)),
                        ),
                      ),
                      SizedBox(width: 12.w),
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
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                          ),
                          child: Text(isEdit ? '保存' : '添加', style: TextStyle(fontSize: 15.sp)),
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
        Text(label, style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
        SizedBox(height: 6.h),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          enabled: enabled,
          style: TextStyle(fontSize: 14.sp, color: cs.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 14.sp, color: cs.outline),
            filled: true,
            fillColor: enabled ? cs.surfaceContainerHighest : cs.surfaceContainerHighest.withValues(alpha: 0.5),
            contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: BorderSide.none),
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
