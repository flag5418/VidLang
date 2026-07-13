/// VidLang 启动页面（Splash Screen）
///
/// 纯白背景启动页，使用 app_icon 图标布局。
library;

import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

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
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E88E5).withValues(alpha: 0.25),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.asset(
                    'assets/Logo/app_icon.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // 应用名称
              Text(
                'VidLang',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 1.5,
                ),
              ),

              const SizedBox(height: 10),

              // 标语
              Text(
                '看视频，听英语，轻松学英语',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                  letterSpacing: 0.8,
                ),
              ),

              const Spacer(flex: 2),

              // 底部加载指示器
              Padding(
                padding: const EdgeInsets.only(bottom: 60),
                child: SizedBox(
                  width: 22,
                  height: 22,
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
