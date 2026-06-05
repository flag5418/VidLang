/// VidLang 应用入口文件
///
/// 负责应用初始化和根组件渲染。
///
/// 初始化流程：
/// 1. 确保Flutter绑定初始化
/// 2. 注册数据库实体
/// 3. 初始化屏幕适配（ScreenUtil）
/// 4. 渲染应用根组件
///
/// 主题说明：
/// - 支持亮色/暗色主题
/// - 跟随系统主题切换（themeMode: ThemeMode.system）
/// - 所有样式使用DesignTokens定义，确保一致性
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_vscode_logger/flutter_vscode_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:vidlang/config.dart' as app_config;
import 'package:vidlang/models/config.dart';
import 'package:vidlang/models/error_log.dart';
import 'package:vidlang/models/participle.dart';
import 'package:vidlang/models/study_record.dart';
import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/models/article.dart';
import 'package:vidlang/models/article_chapter.dart';
import 'package:vidlang/models/article_sentence.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/models/recording_record.dart';
import 'package:vidlang/models/user.dart';
import 'package:vidlang/models/video_folder.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/providers/user_provider.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/views/login/index.dart';

/// 应用入口函数
///
/// 在调用runApp之前完成所有初始化操作
void main() async {
  // 确保Flutter绑定初始化
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  VscodeLogger.instance.init(appName: 'VidLang', minLevel: LogLevel.debug, printToConsole: true);
  FlutterError.onError = (details) {
    logger.error(
      'FlutterError',
      tag: 'UNCAUGHT',
      error: details.exception,
      stackTrace: details.stack,
      extra: {
        'library': details.library,
        'context': details.context?.toDescription(),
        'information': details.informationCollector?.call().map((e) => e.toString()).toList(),
      },
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    logger.fatal('PlatformDispatcher', tag: 'UNCAUGHT', error: error, stackTrace: stack);
    return true;
  };

  await Supabase.initialize(url: app_config.AppConfig.supabaseUrl, anonKey: app_config.AppConfig.supabaseAnonKey);

  // ============================================================
  // 数据库实体注册
  // ============================================================
  //
  // 注册所有数据实体到数据库服务，每个实体需要提供：
  // - creator: 实体构造函数
  // - description: 实体描述（用于日志和调试）
  // - enableFullTextSearch: 是否启用全文检索（字幕和分词需要）
  // 注意：键名必须与实体的 tableName 属性完全匹配
  DatabaseService.registerEntities({
    'video_folder': EntityConfig(creator: () => VideoFolder(), description: '视频文件夹表'),
    'video_info': EntityConfig(creator: () => VideoInfo(), description: '视频信息表'),
    'subtitles': EntityConfig(creator: () => Subtitles(), description: '字幕表（支持全文检索）', enableFullTextSearch: true),
    'participle': EntityConfig(creator: () => Participle(), description: '分词表（支持全文检索）', enableFullTextSearch: true),
    'config': EntityConfig(creator: () => Config(), description: '配置表'),
    'study_record': EntityConfig(creator: () => StudyRecord(), description: '学习记录表'),
    'user': EntityConfig(creator: () => User(), description: '用户表'),
    'error_log': EntityConfig(creator: () => ErrorLog(), description: '错误日志表'),
    'article': EntityConfig(creator: () => Article(), description: '文章表'),
    'article_chapter': EntityConfig(creator: () => ArticleChapter(), description: '文章章节表'),
    'article_sentence': EntityConfig(creator: () => ArticleSentence(), description: '文章句子表', enableFullTextSearch: true),
    'word_book': EntityConfig(creator: () => WordBook(), description: '单词本表'),
    'recording_record': EntityConfig(creator: () => RecordingRecord(), description: '跟读录音记录表'),
  });

  // 预热数据库并执行缺表迁移（含 study_record）
  try {
    await DatabaseService.database;
    await ensureDefaultAdminSession();
  } catch (e, st) {
    logger.error('数据库初始化失败，将以无数据库模式运行', tag: 'INIT', error: e, stackTrace: st);
  }

  // ============================================================
  // 运行应用
  // ============================================================

  runApp(
    // ProviderScope: Riverpod状态管理的根容器
    const ProviderScope(child: VidLangApp()),
  );
}

/// VidLang应用根组件
///
/// 配置应用的主题、语言、路由等全局设置
class VidLangApp extends StatelessWidget {
  const VidLangApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ============================================================
    // ScreenUtilInit: 屏幕适配初始化
    // ============================================================
    //
    // 确保在应用根部初始化ScreenUtil，以支持：
    // - 不同屏幕尺寸的自适应
    // - iPhone和iPad的响应式布局
    // - 字体大小根据屏幕密度调整
    //
    // 设计尺寸：
    // - width: 375 (iPhone标准宽度)
    // - height: 812 (iPhone标准高度)
    // - allowFontScaling: true (允许字体根据系统设置缩放)
    return ScreenUtilInit(
      designSize: const Size(375, 812), // 设计稿标准尺寸（iPhone）
      builder: (context, child) {
        return MaterialApp(
          // 应用名称
          title: 'VidLang',

          // ============================================================
          // 主题配置
          // ============================================================
          //
          // lightTheme: 亮色主题
          // darkTheme: 暗色主题
          // themeMode: 跟随系统主题切换
          //
          // 使用DesignTokens确保样式一致性
          theme: AppTheme.darkTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          // 是否显示调试标记
          debugShowCheckedModeBanner: false,

          // 应用主页
          home: const LoginPage(),
        );
      },
    );
  }
}
