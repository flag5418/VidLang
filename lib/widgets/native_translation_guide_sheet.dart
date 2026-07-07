import 'package:flutter/material.dart';
import 'package:vidlang/services/ios_native_features.dart';
import 'package:vidlang/theme/app_icons.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';

/// 系统翻译引导弹窗
///
/// 当 iOS 系统翻译功能未就绪时显示，引导用户前往系统设置下载语言包。
/// 支持 iPad 自适应尺寸。
class NativeTranslationGuideSheet extends StatelessWidget {
  final VoidCallback? onRetry;

  const NativeTranslationGuideSheet({super.key, this.onRetry});

  /// 显示弹窗并返回用户是否选择重试
  static Future<bool> show(BuildContext context, {VoidCallback? onRetry}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NativeTranslationGuideSheet(onRetry: onRetry),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).padding.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final pad = isIPad(context);

    // 限制弹窗最大高度为屏幕的 55%，避免溢出
    final maxHeight = screenHeight * 0.55;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: Adaptive.w(context, pad ? 16 : 8)),
      padding: EdgeInsets.fromLTRB(Adaptive.w(context, pad ? 20 : 16), Adaptive.h(context, pad ? 16 : 12), Adaptive.w(context, pad ? 20 : 16), bottom + Adaptive.h(context, pad ? 16 : 12)),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(Adaptive.r(context, pad ? 20 : 16))),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部指示条
              Center(
                child: Container(
                  width: Adaptive.w(context, pad ? 40 : 32),
                  height: Adaptive.h(context, 4),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: Adaptive.h(context, pad ? 20 : 16)),

              // 标题行（带图标）
              Row(
                children: [
                  Icon(AppIcons.translate, size: Adaptive.icon(context, pad ? 22 : 18), color: colorScheme.primary),
                  SizedBox(width: Adaptive.w(context, pad ? 10 : 8)),
                  Text(
                    '启用系统翻译',
                    style: TextStyle(
                      fontSize: Adaptive.sp(context, pad ? 17 : 15),
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              SizedBox(height: Adaptive.h(context, pad ? 10 : 8)),

              // 说明文字
              Text(
                '系统翻译需要先准备语言包（English → 中文）。首次使用可能会弹出系统下载/授权提示。',
                style: TextStyle(
                  fontSize: Adaptive.sp(context, pad ? 14 : 12),
                  height: 1.4,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: Adaptive.h(context, pad ? 16 : 12)),

              // 建议路径卡片
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(Adaptive.w(context, pad ? 16 : 12)),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Adaptive.r(context, pad ? 10 : 8)),
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '建议路径',
                      style: TextStyle(
                        fontSize: Adaptive.sp(context, pad ? 14 : 12),
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: Adaptive.h(context, pad ? 6 : 4)),
                    Text(
                      '系统设置 → 通用 → 语言与地区 → 翻译',
                      style: TextStyle(
                        fontSize: Adaptive.sp(context, pad ? 13 : 11),
                        height: 1.4,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '下载 English / 简体中文 后回到 App 点"重试"。',
                      style: TextStyle(
                        fontSize: Adaptive.sp(context, pad ? 13 : 11),
                        height: 1.4,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: Adaptive.h(context, pad ? 20 : 16)),

              // 按钮行
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await IosNativeFeatures.openAppSettings();
                        if (context.mounted) Navigator.of(context).pop(false);
                      },
                      icon: Icon(AppIcons.settings, size: Adaptive.icon(context, pad ? 17 : 14)),
                      label: Text(
                        '去设置',
                        style: TextStyle(fontSize: Adaptive.sp(context, pad ? 15 : 13), fontWeight: FontWeight.w500),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: Adaptive.h(context, pad ? 12 : 10)),
                        foregroundColor: colorScheme.primary,
                        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Adaptive.r(context, pad ? 10 : 8))),
                      ),
                    ),
                  ),
                  SizedBox(width: Adaptive.w(context, pad ? 12 : 10)),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: Icon(AppIcons.refresh, size: Adaptive.icon(context, pad ? 17 : 14)),
                      label: Text(
                        '重试',
                        style: TextStyle(fontSize: Adaptive.sp(context, pad ? 15 : 13), fontWeight: FontWeight.w500),
                      ),
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: Adaptive.h(context, pad ? 12 : 10)),
                        backgroundColor: colorScheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Adaptive.r(context, pad ? 10 : 8))),
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
  }
}
