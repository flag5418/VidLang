/// VidLang 启动页面（Splash Screen）
///
/// 主题自适应启动页，使用 app_icon 图标布局。
/// - 亮色模式：浅色渐变背景 + 白色图标容器
/// - 暗色模式：深蓝渐变背景 + 微光图标容器
///
/// 布局：居中图标 + 应用名称 + 标语 + 底部加载指示器
library;

import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

/// 启动页面组件
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    const Color(0xFF1A1A2E),
                    const Color(0xFF16213E),
                  ]
                : [
                    const Color(0xFFE8EEF7),
                    const Color(0xFFF8FAFE),
                  ],
          ),
        ),
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
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.4)
                          : const Color(0xFF1E88E5).withValues(alpha: 0.25),
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
                  color: colorScheme.primary,
                  letterSpacing: 1.5,
                ),
              ),

              const SizedBox(height: 10),

              // 标语
              Text(
                '看视频，听英语，轻松学英语',
                style: TextStyle(
                  fontSize: 15,
                  color: colorScheme.onSurface.withValues(alpha: 0.55),
                  letterSpacing: 0.8,
                ),
              ),

              const Spacer(flex: 2),

              // 底部加载指示器（使用 TDesign TDLoading）
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
