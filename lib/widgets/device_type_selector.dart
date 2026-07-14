/// 设备类型选择器组件
///
/// 用于个人中心设置页面，允许用户手动切换 iPhone/iPad 布局
/// 修改后会立即触发 MaterialApp 重新布局
library;

import 'package:flutter/material.dart';import 'package:vidlang/utils/adaptive.dart' as adaptive;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:vidlang/models/device_type.dart';
import 'package:vidlang/providers/device_type_provider.dart';
import 'package:vidlang/theme/app_colors.dart';


/// 设备类型选择器组件
///
/// 显示当前设备类型，点击弹出选择对话框
/// 修改后立即生效，触发全应用重新布局
class DeviceTypeSelector extends ConsumerWidget {
  const DeviceTypeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentType = ref.watch(deviceTypeProvider);
    final isLoading = ref.watch(deviceTypeLoadingProvider);

    return GestureDetector(
      onTap: isLoading ? null : () => _showDeviceTypeDialog(context, ref),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.s(16),
          vertical: context.s(12),
        ),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(context.rs(8)),
        ),
        child: Row(
          children: [
            Icon(
              currentType.isTablet ? Icons.tablet_mac : Icons.phone_iphone,
              size: context.is_(24),
              color: context.colors.primary,
            ),
            SizedBox(width: context.s(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '设备类型',
                    style: TextStyle(
                      fontSize: context.ts(16),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: context.s(2)),
                  Text(
                    currentType.isTablet ? 'iPad 布局' : 'iPhone 布局',
                    style: TextStyle(
                      fontSize: context.ts(12),
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isLoading)
              SizedBox(
                width: context.is_(20),
                height: context.is_(20),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.colors.primary,
                ),
              )
            else
              Icon(
                Icons.chevron_right,
                size: context.is_(20),
                color: context.colors.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }

  void _showDeviceTypeDialog(BuildContext context, WidgetRef ref) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'DeviceTypeDialog',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => _DeviceTypeDialog(
        currentType: ref.read(deviceTypeProvider),
        onTypeSelected: (type) async {
          Navigator.of(context).pop();
          await ref.read(deviceTypeProvider.notifier).setDeviceType(type);
        },
      ),
      transitionBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }
}

/// 设备类型选择对话框（标准选择弹窗风格）
class _DeviceTypeDialog extends StatefulWidget {
  final AppDeviceType currentType;
  final ValueChanged<AppDeviceType> onTypeSelected;

  const _DeviceTypeDialog({
    required this.currentType,
    required this.onTypeSelected,
  });

  @override
  State<_DeviceTypeDialog> createState() => _DeviceTypeDialogState();
}

class _DeviceTypeDialogState extends State<_DeviceTypeDialog> {
  late AppDeviceType _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentType;
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final isIpad = context.ipad;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isIpad ? adaptive.Adaptive.w(context, 80) : adaptive.Adaptive.w(context, 32)),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(isIpad ? 16 : 14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: adaptive.Adaptive.w(context, 32),
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── 标题区 ──
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.s(24),
                    context.s(24),
                    context.s(24),
                    context.s(8),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(context.s(12)),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.devices_rounded,
                          size: context.is_(28),
                          color: cs.primary,
                        ),
                      ),
                      SizedBox(height: context.s(10)),
                      Text(
                        '选择设备类型',
                        style: TextStyle(
                          fontSize: context.ts(17),
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      SizedBox(height: context.s(4)),
                      Text(
                        '切换后界面将立即刷新',
                        style: TextStyle(
                          fontSize: context.ts(13),
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── 选项区 ──
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: context.s(20)),
                  child: Column(
                    children: [
                      _DeviceTypeOption(
                        type: AppDeviceType.iphone,
                        icon: Icons.phone_iphone,
                        title: 'iPhone 布局',
                        subtitle: '按手机尺寸适配，内容紧凑',
                        isSelected: _selected.isPhone,
                        onTap: () => setState(() => _selected = AppDeviceType.iphone),
                      ),
                      SizedBox(height: context.s(10)),
                      _DeviceTypeOption(
                        type: AppDeviceType.ipad,
                        icon: Icons.tablet_mac,
                        title: 'iPad 布局',
                        subtitle: '按平板尺寸适配，布局更宽裕',
                        isSelected: _selected.isTablet,
                        onTap: () => setState(() => _selected = AppDeviceType.ipad),
                      ),
                    ],
                  ),
                ),

                // ── 按钮区 ──
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.s(20),
                    context.s(20),
                    context.s(20),
                    context.s(20),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TDButton(
                          text: '取消',
                          size: TDButtonSize.large,
                          type: TDButtonType.outline,
                          shape: TDButtonShape.round,
                          height: context.s(48),
                          style: TDButtonStyle(
                            backgroundColor: Colors.transparent,
                            textColor: AppColors.primary,
                            frameColor: AppColors.primary,
                          ),
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                      SizedBox(width: context.s(12)),
                      Expanded(
                        child: TDButton(
                          text: '确定',
                          size: TDButtonSize.large,
                          type: TDButtonType.fill,
                          theme: TDButtonTheme.primary,
                          shape: TDButtonShape.round,
                          height: context.s(48),
                          style: TDButtonStyle(
                            backgroundColor: AppColors.primary,
                            textColor: AppColors.onPrimary,
                          ),
                          onTap: () => widget.onTypeSelected(_selected),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 设备类型选项组件（带图标的卡片式选项）
class _DeviceTypeOption extends StatelessWidget {
  final AppDeviceType type;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _DeviceTypeOption({
    required this.type,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: context.s(16),
          vertical: context.s(14),
        ),
        decoration: BoxDecoration(
          color: isSelected ? cs.primaryContainer.withValues(alpha: 0.4) : cs.surfaceContainerLow,
          border: Border.all(
            color: isSelected ? cs.primary : cs.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(context.rs(12)),
        ),
        child: Row(
          children: [
            Container(
              width: context.s(44),
              height: context.s(44),
              decoration: BoxDecoration(
                color: isSelected
                    ? cs.primary.withValues(alpha: 0.15)
                    : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(context.rs(12)),
              ),
              child: Icon(
                icon,
                size: context.is_(24),
                color: isSelected ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
            SizedBox(width: context.s(14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: context.ts(15),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? cs.onPrimaryContainer : cs.onSurface,
                    ),
                  ),
                  SizedBox(height: context.s(2)),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: context.ts(12),
                      color: isSelected
                          ? cs.onPrimaryContainer.withValues(alpha: 0.7)
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: context.s(22),
                height: context.s(22),
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  size: context.is_(14),
                  color: cs.onPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
