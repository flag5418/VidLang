import 'package:flutter/material.dart';
import 'package:vidlang/theme/app_colors.dart';

/// 余额不足充值引导弹窗
/// 多处复用：字幕点击、翻译、TTS、跟读评分等场景
class RechargeDialog extends StatelessWidget {
  final double requiredCny;
  final double balanceCny;
  final String featureName;
  final VoidCallback dismiss;
  final VoidCallback goRecharge;

  const RechargeDialog({
    super.key,
    required this.requiredCny,
    required this.balanceCny,
    required this.featureName,
    required this.dismiss,
    required this.goRecharge,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 32),
          padding: EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
            boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 8))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.orange.withValues(alpha: 0.15)),
                child: Icon(Icons.account_balance_wallet_outlined, color: Colors.orangeAccent, size: 26),
              ),
              const SizedBox(height: 16),

              Text(
                '余额不足',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                  children: [
                    TextSpan(text: '使用'),
                    TextSpan(
                      text: featureName,
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: '需要 '),
                    TextSpan(
                      text: '¥${requiredCny.toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: '\n当前余额仅 '),
                    TextSpan(
                      text: '¥${balanceCny.toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: dismiss,
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          '取消',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: goRecharge,
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(gradient: AppColors.sunsetGradient, borderRadius: BorderRadius.circular(24)),
                        child: Text(
                          '去充值',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
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

  /// 快捷方法：Overlay 弹窗
  static void show(
    BuildContext context, {
    required double requiredCny,
    required double balanceCny,
    required String featureName,
    VoidCallback? onGoRecharge,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => RechargeDialog(
        requiredCny: requiredCny,
        balanceCny: balanceCny,
        featureName: featureName,
        dismiss: () => Navigator.of(ctx).pop(),
        goRecharge: () {
          Navigator.of(ctx).pop();
          onGoRecharge?.call();
        },
      ),
    );
  }
}
