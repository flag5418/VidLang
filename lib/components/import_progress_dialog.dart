/// 导入进度弹窗组件
/// 
/// 提供美观的进度展示，包含动画效果和进度条
library;
import 'package:flutter/material.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

/// 导入进度弹窗
/// 
/// 显示导入进度，包含动画效果
class ImportProgressDialog extends StatefulWidget {
  /// 弹窗标题
  final String title;
  
  /// 进度更新回调
  final ValueChanged<bool> onComplete;

  const ImportProgressDialog({
    super.key,
    required this.title,
    required this.onComplete,
  });

  @override
  State<ImportProgressDialog> createState() => _ImportProgressDialogState();
}

class _ImportProgressDialogState extends State<ImportProgressDialog> {
  int _current = 0;
  int _total = 0;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    // 模拟进度更新
    _simulateProgress();
  }

  Future<void> _simulateProgress() async {
    for (int i = 1; i <= 100; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
      setState(() {
        _progress = i / 100;
        _current = i;
        _total = 100;
      });
    }
    widget.onComplete(true);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(adaptive.Adaptive.w(context, 20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 20)),
          color: cs.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: adaptive.Adaptive.w(context, 20),
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: EdgeInsets.all(adaptive.Adaptive.w(context, 24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 动画图标
            _buildAnimationIcon(cs),
            SizedBox(height: adaptive.Adaptive.h(context, 20)),
            // 标题
            Text(
              widget.title,
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(context, 18),
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            SizedBox(height: adaptive.Adaptive.h(context, 8)),
            // 状态文本
            Text(
              '正在处理视频文件...',
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(context, 14),
                color: cs.onSurfaceVariant,
              ),
            ),
            SizedBox(height: adaptive.Adaptive.h(context, 24)),
            // 进度条
            _buildProgressBar(cs),
            SizedBox(height: adaptive.Adaptive.h(context, 12)),
            // 进度文字
            Text(
              '$_current / $_total',
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(context, 14),
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建动画图标
  Widget _buildAnimationIcon(AppColorsData cs) {
    return Container(
      width: adaptive.Adaptive.w(context, 80),
      height: adaptive.Adaptive.w(context, 80),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 40)),
        gradient: LinearGradient(
          colors: [
            cs.primary,
            cs.primaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 3,
        ),
      ),
    );
  }

  /// 构建进度条
  Widget _buildProgressBar(AppColorsData cs) {
    return Container(
      height: adaptive.Adaptive.h(context, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 4)),
        color: cs.surfaceContainerHighest,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 4)),
        child: LinearProgressIndicator(
          value: _progress,
          backgroundColor: Colors.transparent,
          valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
          minHeight: 8,
        ),
      ),
    );
  }
}
