/// 编辑资料页面
///
/// 列表式展示：头像、昵称、登录名。
/// 头像支持从相册选择/拍照，按用户ID存为本地PNG。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vidlang/services/app_keys_service.dart';
import 'package:vidlang/models/user.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/widgets/app_dialogs.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  User? _user;
  File? _avatarFile;

  @override
  void initState() {
    super.initState();
    _user = AppKeysService.currentUser;
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    try {
      final file = File(await _avatarPath);
      if (await file.exists()) {
        if (!mounted) return;
        setState(() => _avatarFile = file);
      }
    } catch (_) {}
  }

  Future<String> get _avatarPath async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/avatars');
    if (!await dir.exists()) await dir.create(recursive: true);
    return '${dir.path}/${_user!.id}.png';
  }

  Future<void> _pickAvatar() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AvatarPickerSheet(onSelect: (source) => Navigator.pop(ctx, source)),
    );
    if (result == null) return;

    final source = result == 'camera' ? ImageSource.camera : ImageSource.gallery;
    try {
      final picked = await ImagePicker().pickImage(source: source, maxWidth: 512, maxHeight: 512);
      if (picked == null) return;

      final targetPath = await _avatarPath;
      await File(picked.path).copy(targetPath);
      if (!mounted) return;
      setState(() => _avatarFile = File(targetPath));

      _user!.avatar = targetPath;
      await DatabaseService.update(_user!);
      AppKeysService.currentUser = _user;
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, '头像保存失败: $e');
    }
  }

  Future<void> _editNickname() async {
    final result = await AppInputDialog.show(context, title: '修改昵称', hintText: '请输入新昵称', initialValue: _user?.nickname ?? '', confirmText: '保存');
    if (result != null && result.isNotEmpty && _user != null) {
      try {
        _user!.nickname = result.trim();
        await DatabaseService.update(_user!);
        AppKeysService.currentUser = _user;
        if (!mounted) return;
        setState(() {});
      } catch (e) {
        if (!mounted) return;
        AppToast.show(context, '保存失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final user = _user;
    final nickname = user?.nickname.isNotEmpty == true ? user!.nickname : user?.username ?? '';
    final initial = (nickname.isNotEmpty ? nickname[0] : '?').toUpperCase();

    return Scaffold(
      backgroundColor: isDark ? cs.surface : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          '编辑资料',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: cs.onSurface),
        ),
        centerTitle: true,
        backgroundColor: isDark ? cs.surface : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: cs.onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Container(
            decoration: BoxDecoration(color: isDark ? cs.surface : Colors.white, borderRadius: BorderRadius.circular(16.r)),
            child: Column(
              children: [
                _buildRow('头像', trailing: _buildAvatar(cs, initial), onTap: _pickAvatar),
                _buildRow('昵称', value: nickname, onTap: _editNickname),
                _buildRow('登录名', value: user?.username ?? ''),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(ColorScheme cs, String initial) {
    if (_avatarFile != null) {
      return ClipOval(
        child: Image.file(_avatarFile!, width: 44.w, height: 44.w, fit: BoxFit.cover),
      );
    }
    return CircleAvatar(
      radius: 22.r,
      backgroundColor: cs.primary.withValues(alpha: 0.12),
      child: Text(
        initial,
        style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: cs.primary),
      ),
    );
  }

  Widget _buildRow(String label, {String value = '', Widget? trailing, VoidCallback? onTap}) {
    final cs = Theme.of(context).colorScheme;
    final interactive = onTap != null;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w500, color: cs.onSurface),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ?trailing,
                  if (value.isNotEmpty && trailing == null)
                    Flexible(
                      child: Text(
                        value,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15.sp, color: interactive ? cs.onSurface : cs.onSurfaceVariant),
                      ),
                    ),
                  if (interactive) ...[SizedBox(width: 6.w), Icon(Icons.chevron_right_rounded, size: 20.sp, color: cs.outline)],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 头像选择底部弹窗
class _AvatarPickerSheet extends StatelessWidget {
  final void Function(String source) onSelect;
  const _AvatarPickerSheet({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36.w,
              height: 4.h,
              margin: EdgeInsets.only(bottom: 12.h),
              decoration: BoxDecoration(color: cs.onSurface.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2.r)),
            ),
            Text(
              '选择头像',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: cs.onSurface),
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: _OptionCard(icon: Icons.photo_library_rounded, label: '相册', cs: cs, onTap: () => onSelect('gallery')),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _OptionCard(icon: Icons.camera_alt_rounded, label: '拍照', cs: cs, onTap: () => onSelect('camera')),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: cs.surfaceContainerHighest,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
                child: Text(
                  '取消',
                  style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w500, color: cs.onSurface),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme cs;
  final VoidCallback onTap;
  const _OptionCard({required this.icon, required this.label, required this.cs, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 20.h),
        decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(12.r)),
        child: Column(
          children: [
            Icon(icon, size: 32.sp, color: cs.primary),
            SizedBox(height: 8.h),
            Text(
              label,
              style: TextStyle(fontSize: 13.sp, color: cs.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}
