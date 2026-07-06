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
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/theme/app_spacing.dart';
import 'package:vidlang/theme/app_radius.dart';

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
      barrierColor: Theme.of(
        context,
      ).colorScheme.surface.withValues(alpha: 0.1),
      builder: (ctx) =>
          _AvatarPickerSheet(onSelect: (source) => Navigator.pop(ctx, source)),
    );
    if (result == null) return;

    final source = result == 'camera'
        ? ImageSource.camera
        : ImageSource.gallery;
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
      );
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
    final result = await AppInputDialog.show(
      context,
      title: '修改昵称',
      hintText: '请输入新昵称',
      initialValue: _user?.nickname ?? '',
      confirmText: '保存',
    );
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
    final user = _user;
    final nickname = user?.nickname.isNotEmpty == true
        ? user!.nickname
        : user?.username ?? '';
    final initial = (nickname.isNotEmpty ? nickname[0] : '?').toUpperCase();

    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: AppColors.getSurfaceElevated(brightness: brightness),
      appBar: AppBar(
        title: Text(
          '编辑资料',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        centerTitle: true,
        backgroundColor: cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: cs.onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePadding,
          vertical: AppSpacing.md,
        ),
        child: Column(
          children: [
            // 头像卡片（突出显示）
            _buildAvatarCard(cs, initial),
            SizedBox(height: AppSpacing.space3),
            // 昵称卡片
            _buildInfoCard(
              label: '昵称',
              value: nickname,
              icon: Icons.edit_outlined,
              onTap: _editNickname,
              cs: cs,
            ),
            SizedBox(height: AppSpacing.space3),
            // 登录名卡片（只读）
            _buildInfoCard(
              label: '登录名',
              value: user?.username ?? '',
              icon: Icons.alternate_email_rounded,
              cs: cs,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(ColorScheme cs, String initial) {
    if (_avatarFile != null) {
      return ClipOval(
        child: Image.file(
          _avatarFile!,
          width: 44.w,
          height: 44.w,
          fit: BoxFit.cover,
        ),
      );
    }
    return CircleAvatar(
      radius: 22.r,
      backgroundColor: cs.primary.withValues(alpha: 0.12),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 18.sp,
          fontWeight: FontWeight.bold,
          color: cs.primary,
        ),
      ),
    );
  }

  /// 头像卡片——独立突出的卡片，左侧图标+标签，右侧大头像预览
  Widget _buildAvatarCard(ColorScheme cs, String initial) {
    return _ElevatedCard(
      onTap: _pickAvatar,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space4,
      ),
      child: Row(
        children: [
          // 左侧图标 + 标签
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              Icons.photo_camera_rounded,
              size: 20.sp,
              color: cs.primary,
            ),
          ),
          SizedBox(width: AppSpacing.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '头像',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '点击更换头像',
                  style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          // 右侧头像预览
          _buildAvatar(cs, initial),
          SizedBox(width: 6.w),
          Icon(
            Icons.chevron_right_rounded,
            size: 20.sp,
            color: cs.outline.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  /// 信息卡片——通用的单行信息展示/编辑卡片，两端对齐布局
  Widget _buildInfoCard({
    required String label,
    required String value,
    required IconData icon,
    required ColorScheme cs,
    VoidCallback? onTap,
  }) {
    final interactive = onTap != null;
    return _ElevatedCard(
      onTap: onTap,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space3 + 2,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 左侧：图标 + 标签（固定区域）
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  icon,
                  size: 18.sp,
                  color: cs.primary.withValues(alpha: 0.8),
                ),
              ),
              SizedBox(width: AppSpacing.space4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),

          // 右侧：值 + 箭头
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value.isNotEmpty)
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 15.sp,
                      color: interactive ? cs.onSurface : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              if (interactive) ...[
                SizedBox(width: 6.w),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20.sp,
                  color: cs.outline.withValues(alpha: 0.5),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
/// 带阴影的卡片组件——白色背景 + 阴影 + 圆角 + 可选描边
/// 解决 OutlinedCard 无阴影、与背景色不分的问题
// ═══════════════════════════════════════════════════════════════
class _ElevatedCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const _ElevatedCard({required this.child, this.padding, this.onTap});

  @override
  State<_ElevatedCard> createState() => _ElevatedCardState();
}

class _ElevatedCardState extends State<_ElevatedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
        builder: (context, child) =>
            Transform.scale(scale: _scaleAnimation.value, child: child),
        child: Container(
          padding: widget.padding ?? const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: AppColors.getSurface(brightness: brightness),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: brightness == Brightness.dark ? 0.3 : 0.06,
                ),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: brightness == Brightness.dark ? 0.2 : 0.03,
                ),
                blurRadius: 4,
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
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            Text(
              '选择头像',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: _OptionCard(
                    icon: Icons.photo_library_rounded,
                    label: '相册',
                    cs: cs,
                    onTap: () => onSelect('gallery'),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _OptionCard(
                    icon: Icons.camera_alt_rounded,
                    label: '拍照',
                    cs: cs,
                    onTap: () => onSelect('camera'),
                  ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  '取消',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
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
  const _OptionCard({
    required this.icon,
    required this.label,
    required this.cs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 20.h),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12.r),
        ),
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
