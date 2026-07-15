import 'package:flutter/material.dart';import 'package:vidlang/utils/adaptive.dart' as adaptive;

import 'package:vidlang/theme/theme.dart';


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
    final pad = adaptive.isIPad();
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: EdgeInsets.symmetric(
            horizontal: adaptive.Adaptive.w(pad ? 48 : 32),
          ),
          padding: EdgeInsets.fromLTRB(
            adaptive.Adaptive.w(24),
            adaptive.Adaptive.h(pad ? 34 : 28),
            adaptive.Adaptive.w(24),
            adaptive.Adaptive.h(pad ? 24 : 20),
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(
              adaptive.Adaptive.r(pad ? 20 : 16),
            ),
            border: Border.all(color: Colors.white12),
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                blurRadius: adaptive.Adaptive.w(20),
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: adaptive.Adaptive.icon(48),
                height: adaptive.Adaptive.icon(48),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.withValues(alpha: 0.15),
                ),
                child: Icon(
                  AppIcons.accountBalanceWallet,
                  color: Colors.orangeAccent,
                  size: adaptive.Adaptive.icon(pad ? 30 : 26),
                ),
              ),
              SizedBox(height: adaptive.Adaptive.h(pad ? 20 : 16)),

              Text(
                '余额不足',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: adaptive.Adaptive.sp(pad ? 20 : 18),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: adaptive.Adaptive.h(pad ? 10 : 8)),

              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: adaptive.Adaptive.sp(pad ? 16 : 14),
                    height: 1.5,
                  ),
                  children: [
                    TextSpan(text: '使用'),
                    TextSpan(
                      text: featureName,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(text: '需要 '),
                    TextSpan(
                      text: '¥${requiredCny.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.orangeAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(text: '\n当前余额仅 '),
                    TextSpan(
                      text: '¥${balanceCny.toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              SizedBox(height: adaptive.Adaptive.h(pad ? 24 : 20)),

              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: dismiss,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: adaptive.Adaptive.h(pad ? 12 : 10),
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24),
                          borderRadius: BorderRadius.circular(
                            adaptive.Adaptive.r(pad ? 28 : 24),
                          ),
                        ),
                        child: Text(
                          '取消',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: adaptive.Adaptive.sp(pad ? 16 : 14),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: adaptive.Adaptive.w(pad ? 14 : 12)),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: goRecharge,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: adaptive.Adaptive.h(pad ? 12 : 10),
                        ),
                        decoration: BoxDecoration(
                          gradient: AppColors.sunsetGradient,
                          borderRadius: BorderRadius.circular(
                            adaptive.Adaptive.r(pad ? 28 : 24),
                          ),
                        ),
                        child: Text(
                          '去充值',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: adaptive.Adaptive.sp(pad ? 16 : 14),
                            fontWeight: FontWeight.w600,
                          ),
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
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      barrierLabel: 'RechargeDialog',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => RechargeDialog(
        requiredCny: requiredCny,
        balanceCny: balanceCny,
        featureName: featureName,
        dismiss: () => Navigator.of(context).pop(),
        goRecharge: () {
          Navigator.of(context).pop();
          onGoRecharge?.call();
        },
      ),
      transitionBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }
}
