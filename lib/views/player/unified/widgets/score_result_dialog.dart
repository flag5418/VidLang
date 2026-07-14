import 'package:flutter/material.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;
import 'package:vidlang/views/player/unified/unified_player_logic.dart';

/// 评分结果弹窗组件
///
/// 展示跟读/跟唱评分的 BottomSheet，
/// 包含总分、维度分数和操作按钮。
class ScoreResultDialog {
  /// 显示评分弹窗
  static void show(
    BuildContext context, {
    double? overall,
    double? fluency,
    double? accuracy,
    double? completeness,
    VoidCallback? onReRecord,
    VoidCallback? onNext,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _ScoreResultContent(
        overall: overall,
        fluency: fluency,
        accuracy: accuracy,
        completeness: completeness,
        onReRecord: onReRecord,
        onNext: onNext,
      ),
    );
  }
}

class _ScoreResultContent extends StatelessWidget {
  final double? overall;
  final double? fluency;
  final double? accuracy;
  final double? completeness;
  final VoidCallback? onReRecord;
  final VoidCallback? onNext;

  const _ScoreResultContent({
    this.overall,
    this.fluency,
    this.accuracy,
    this.completeness,
    this.onReRecord,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: EdgeInsets.all(adaptive.Adaptive.w(context, 24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题
          Text(
            '跟读评分',
            style: TextStyle(
              color: colors.onSurface,
              fontSize: adaptive.Adaptive.sp(context, 16),
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(height: adaptive.Adaptive.h(context, 12)),

          // 总分
          if (overall != null)
            Text(
              '${overall!.round()}',
              style: TextStyle(
                color: UnifiedPlayerLogic.scoreColor(overall!),
                fontSize: adaptive.Adaptive.sp(context, 48),
                fontWeight: FontWeight.bold,
              ),
            ),

          SizedBox(height: adaptive.Adaptive.h(context, 8)),

          // 维度分数
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (accuracy != null) _scoreDim(context, '准确', accuracy!),
              if (fluency != null) _scoreDim(context, '流利', fluency!),
              if (completeness != null) _scoreDim(context, '完整', completeness!),
            ],
          ),

          SizedBox(height: adaptive.Adaptive.h(context, 16)),

          // 操作按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onReRecord?.call();
                },
                child: Text('重录', style: TextStyle(color: colors.primary)),
              ),
              SizedBox(width: adaptive.Adaptive.w(context, 20)),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onNext?.call();
                },
                child: Text('下一句', style: TextStyle(color: colors.primary)),
              ),
            ],
          ),

          SizedBox(height: adaptive.Adaptive.h(context, 8)),
        ],
      ),
    );
  }

  /// 维度分数展示
  Widget _scoreDim(BuildContext context, String label, double score) {
    return Column(
      children: [
        Text(
          '${score.round()}',
          style: TextStyle(
            color: UnifiedPlayerLogic.scoreColor(score),
            fontSize: adaptive.Adaptive.sp(context, 20),
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: adaptive.Adaptive.h(context, 2)),
        Text(
          label,
          style: TextStyle(
            color: AppColors.onSurface.withValues(alpha: 0.54),
            fontSize: adaptive.Adaptive.sp(context, 12),
          ),
        ),
      ],
    );
  }
}
