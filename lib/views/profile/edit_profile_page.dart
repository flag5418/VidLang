/// 编辑资料页面
///
/// 列表式展示：头像、昵称、登录名。
/// 头像支持从相册选择/拍照，按用户ID存为本地PNG。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vidlang/services/app_keys_service.dart';
import 'package:vidlang/models/user.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/widgets/app_dialogs.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/theme/app_spacing.dart';
import 'package:vidlang/theme/app_radius.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';

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
    String? selectedSource;

    await TDActionSheet(
      context,
      description: '选择头像来源',
      items: [
        TDActionSheetItem(
          label: '相册',
          icon: Icon(AppIcons.photoLibrary, size: Adaptive.sp(context, 22)),
        ),
        TDActionSheetItem(
          label: '拍照',
          icon: Icon(AppIcons.cameraAlt, size: Adaptive.sp(context, 22)),
        ),
      ],
      onSelected: (item, _) {
        selectedSource = item.label == '相册' ? 'gallery' : 'camera';
      },
      visible: true,
    );

    if (selectedSource == null) return;
    final source = selectedSource == 'camera'
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
            fontSize: Adaptive.sp(context, 18),
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        centerTitle: true,
        backgroundColor: cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.arrowBackIos, color: cs.onSurface, size: 20),
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
              icon: AppIcons.edit,
              onTap: _editNickname,
              cs: cs,
            ),
            SizedBox(height: AppSpacing.space3),
            // 登录名卡片（只读）
            _buildInfoCard(
              label: '登录名',
              value: user?.username ?? '',
              icon: AppIcons.alternateEmail,
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
          width: Adaptive.w(context, 44),
          height: Adaptive.w(context, 44),
          fit: BoxFit.cover,
        ),
      );
    }
    return CircleAvatar(
      radius: Adaptive.r(context, 22),
      backgroundColor: cs.primary.withValues(alpha: 0.12),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: Adaptive.sp(context, 18),
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
            width: Adaptive.w(context, 40),
            height: Adaptive.w(context, 40),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(Adaptive.r(context, 12)),
            ),
            child: Icon(
              AppIcons.photoCamera,
              size: Adaptive.sp(context, 20),
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
                    fontSize: Adaptive.sp(context, 16),
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                SizedBox(height: Adaptive.h(context, 2)),
                Text(
                  '点击更换头像',
                  style: TextStyle(fontSize: Adaptive.sp(context, 12), color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          // 右侧头像预览
          _buildAvatar(cs, initial),
          SizedBox(width: Adaptive.w(context, 6)),
          Icon(
            AppIcons.chevronRight,
              size: Adaptive.sp(context, 20),
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
                width: Adaptive.w(context, 36),
                height: Adaptive.w(context, 36),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(Adaptive.r(context, 10)),
                ),
                child: Icon(
                  icon,
                  size: Adaptive.sp(context, 18),
                  color: cs.primary.withValues(alpha: 0.8),
                ),
              ),
              SizedBox(width: AppSpacing.space4),
              Text(
                label,
                style: TextStyle(
                  fontSize: Adaptive.sp(context, 16),
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
                      fontSize: Adaptive.sp(context, 15),
                      color: interactive ? cs.onSurface : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              if (interactive) ...[
                SizedBox(width: Adaptive.w(context, 6)),
                Icon(
                  AppIcons.chevronRight,
                  size: Adaptive.sp(context, 20),
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
          // 用 Expanded 包裹 child，确保在 unbounded 宽度约束下不会报错
          // 同时不影响正常布局（外层有约束时 Expanded 自适应）
          child: widget.child,
        ),
      ),
    );
  }
}


