/// VidLang 启动页面（Splash Screen）
///
/// 纯白背景启动页，使用 app_icon 图标布局。
library;

import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

/// 启动页面组件
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),

              // 应用图标
              Container(
                width: adaptive.Adaptive.w(context, 120),
                height: adaptive.Adaptive.w(context, 120),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 28)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E88E5).withValues(alpha: 0.25),
                      blurRadius: adaptive.Adaptive.w(context, 24),
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 28)),
                  child: Image.asset(
                    'assets/Logo/app_icon.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              SizedBox(height: adaptive.Adaptive.h(context, 28)),

              // 应用名称
              Text(
                'VidLang',
                style: TextStyle(
                  fontSize: adaptive.Adaptive.sp(context, 32),
                  fontWeight: FontWeight.bold,
                  color: context.colors.primary,
                  letterSpacing: 1.5,
                ),
              ),

              SizedBox(height: adaptive.Adaptive.h(context, 10)),

              // 标语
              Text(
                '看视频，听英语，轻松学英语',
                style: TextStyle(
                  fontSize: adaptive.Adaptive.sp(context, 15),
                  color: Colors.black54,
                  letterSpacing: 0.8,
                ),
              ),

              const Spacer(flex: 2),

              // 底部加载指示器
              Padding(
                padding: EdgeInsets.only(bottom: adaptive.Adaptive.h(context, 60)),
                child: SizedBox(
                  width: adaptive.Adaptive.w(context, 22),
                  height: adaptive.Adaptive.w(context, 22),
                  child: TDLoading(
                    size: TDLoadingSize.small,
                    icon: TDLoadingIcon.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
