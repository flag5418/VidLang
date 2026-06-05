/// 导入进度弹窗组件
/// 
/// 提供美观的进度展示，包含动画效果和进度条
library;
import 'package:flutter/material.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 动画图标
            _buildAnimationIcon(colorScheme),
            const SizedBox(height: 20),
            // 标题
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            // 状态文本
            Text(
              '正在处理视频文件...',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            // 进度条
            _buildProgressBar(colorScheme),
            const SizedBox(height: 12),
            // 进度文字
            Text(
              '$_current / $_total',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建动画图标
  Widget _buildAnimationIcon(ColorScheme colorScheme) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primaryContainer,
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
  Widget _buildProgressBar(ColorScheme colorScheme) {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: colorScheme.surfaceContainerHighest,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: _progress,
          backgroundColor: Colors.transparent,
          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          minHeight: 8,
        ),
      ),
    );
  }
}
