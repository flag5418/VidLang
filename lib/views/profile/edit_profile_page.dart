/// 编辑个人信息页面
///
/// 可修改：昵称、头像
library;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vidlang/config.dart';
import 'package:vidlang/models/user.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/theme/theme.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _nicknameController = TextEditingController();
  User? _user;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _user = AppConfig.currentUser;
    _nicknameController.text = _user?.nickname ?? '';
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = _user;

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
          '编辑个人信息',
          style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary))
                : Text(
                    '保存',
                    style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          spacing: 16.h,
          children: [
            SizedBox(height: 16),
            // 头像
            CircleAvatar(
              radius: 40,
              backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
              child: Text(
                (user?.nickname.isNotEmpty == true ? user!.nickname[0] : (user?.username[0] ?? '?')).toUpperCase(),
                style: TextStyle(fontSize: 32.sp, fontWeight: FontWeight.bold, color: colorScheme.primary),
              ),
            ),

            Text(
              '修改头像（暂未开放）',
              style: TextStyle(fontSize: 12.sp, color: colorScheme.onSurfaceVariant),
            ),

            // 登录名（只读）
            _buildReadOnlyField('登录名', user?.username ?? '', colorScheme),

            // 账号类型（只读）
            _buildReadOnlyField('账号类型', user?.authProvider == 'supabase' ? '主账号（Supabase）' : '本地用户', colorScheme),

            _buildReadOnlyField('昵称', user?.username ?? '', colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: TextStyle(fontSize: 13.sp, color: colorScheme.onSurfaceVariant),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: AppColors.surfaceElevated),
          child: Text(
            value,
            style: TextStyle(fontSize: 15.sp, color: colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      _showSnackBar('昵称不能为空');
      return;
    }

    if (_user == null) return;

    setState(() => _loading = true);
    try {
      _user!.nickname = nickname;
      await DatabaseService.update(_user!);
      AppConfig.currentUser = _user;
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showSnackBar('保存失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }
}
