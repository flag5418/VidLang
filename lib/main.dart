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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_vscode_logger/flutter_vscode_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:vidlang/services/app_keys_service.dart';
import 'package:vidlang/models/ai_evaluation_log.dart';
import 'package:vidlang/models/article.dart';
import 'package:vidlang/models/article_bookmark.dart';
import 'package:vidlang/models/article_chapter.dart';
import 'package:vidlang/models/article_paragraph.dart';
import 'package:vidlang/models/article_sentence.dart';
import 'package:vidlang/models/base_entity.dart';
import 'package:vidlang/models/config.dart';
import 'package:vidlang/models/error_log.dart';
import 'package:vidlang/models/participle.dart';
import 'package:vidlang/models/recording_record.dart';
import 'package:vidlang/models/study_record.dart';
import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/models/test_models.dart';
import 'package:vidlang/models/user.dart';
import 'package:vidlang/models/video_folder.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/models/word_book_tag.dart';
import 'package:vidlang/models/word_tag.dart';
import 'package:vidlang/models/device_type.dart';
import 'package:vidlang/providers/theme_provider.dart';
import 'package:vidlang/services/auth_service.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/global_error_handler.dart';
import 'package:vidlang/services/local_ai_service.dart';
import 'package:vidlang/splash_screen.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/device_config.dart';
import 'package:vidlang/utils/device_utils.dart';
import 'package:vidlang/utils/dialog_utils.dart';
import 'package:vidlang/views/test/audio_test_page.dart';
import 'package:vidlang/views/test/shengtong_http_test_page.dart';
import 'package:vidlang/views/login/index.dart';
import 'package:vidlang/views/main/main_page.dart';

/// 全局 Navigator Key，用于排他性登录被顶号时从任意位置跳转至登录页
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// 在 runApp 之前检测设备类型，用于 ScreenUtil 初始化
AppDeviceType _detectInitialDeviceType() {
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final shortestSide = view.physicalSize.shortestSide / view.devicePixelRatio;
  if (shortestSide >= 600) {
    return AppDeviceType.ipad;
  }
  return AppDeviceType.iphone;
}

/// 应用入口函数
///
/// 在调用runApp之前完成所有初始化操作
void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      final view = WidgetsBinding.instance.platformDispatcher.views.first;
      final shortestSide =
          view.physicalSize.shortestSide / view.devicePixelRatio;
      if (shortestSide >= 600) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      }

      VscodeLogger.instance.init(
        appName: 'VidLang',
        minLevel: LogLevel.debug,
        printToConsole: true,
      );
      GlobalErrorHandler.instance.install(navigatorKey: navigatorKey);

      // 禁用系统上下文菜单，避免 Flutter 3.46 主分支的 SystemContextMenu 断言错误
      SystemChannels.platform.invokeMethod('SystemContextMenu.disable');

      // 先执行 runApp，让 Flutter 能够立刻渲染第一帧（Splash Screen）
      // 避免因为网络请求或本地数据库初始化过慢导致长时间黑屏/白屏
      runApp(ProviderScope(child: VidLangApp(initialDeviceType: _detectInitialDeviceType())));

      // 在后台异步进行各项繁重的初始化任务
      _initializeAsyncDependencies();
    },
    (error, stack) {
      GlobalErrorHandler.instance.handleZoneError(error, stack);
    },
  );
}

Future<void> _initializeAsyncDependencies() async {
  try {
    await Supabase.initialize(
      url: AppKeysService.supabaseUrl,
      anonKey: AppKeysService.supabaseAnonKey,
    );

    DatabaseService.registerEntities({
      'video_folder': EntityConfig(
        creator: () => VideoFolder(),
        description: '视频文件夹表',
      ),
      'video_info': EntityConfig(
        creator: () => VideoInfo(),
        description: '视频信息表',
      ),
      'subtitles': EntityConfig(
        creator: () => Subtitles(),
        description: '字幕表（支持全文检索）',
        enableFullTextSearch: true,
      ),
      'participle': EntityConfig(
        creator: () => Participle(),
        description: '分词表（支持全文检索）',
        enableFullTextSearch: true,
      ),
      'config': EntityConfig(creator: () => Config(), description: '配置表'),
      'study_record': EntityConfig(
        creator: () => StudyRecord(),
        description: '学习记录表',
      ),
      'user': EntityConfig(creator: () => User(), description: '用户表'),
      'error_log': EntityConfig(
        creator: () => ErrorLog(),
        description: '错误日志表',
      ),
      'article': EntityConfig(creator: () => Article(), description: '文章表'),
      'article_chapter': EntityConfig(
        creator: () => ArticleChapter(),
        description: '文章章节表（旧版，迁移中）',
      ),
      'article_paragraph': EntityConfig(
        creator: () => ArticleParagraph(),
        description: '文章段落表',
      ),
      'article_sentence': EntityConfig(
        creator: () => ArticleSentence(),
        description: '文章句子表',
        enableFullTextSearch: true,
      ),
      'article_bookmark': EntityConfig(
        creator: () => ArticleBookmark(),
        description: '文章书签表',
      ),
      'word_book': EntityConfig(creator: () => WordBook(), description: '单词本表'),
      'word_tag': EntityConfig(creator: () => WordTag(), description: '单词标签表'),
      'word_book_tag': EntityConfig(
        creator: () => WordBookTag(),
        description: '单词-标签关联表',
      ),
      'recording_record': EntityConfig(
        creator: () => RecordingRecord(),
        description: '跟读录音记录表',
      ),
      'test_session': EntityConfig(
        creator: () => TestSession(),
        description: '评测主记录表',
      ),
      'test_item': EntityConfig(
        creator: () => TestItem(),
        description: '单题记录表',
      ),
      'test_evaluation': EntityConfig(
        creator: () => TestEvaluation(),
        description: 'AI评价报告表',
      ),
      'ai_evaluation_log': EntityConfig(
        creator: () => AiEvaluationLog(),
        description: 'AI学习评价日志表',
      ),
    });

    try {
      await DatabaseService.database;
    } catch (e, st) {
      logger.error(
        '数据库初始化失败，将以无数据库模式运行',
        tag: 'INIT',
        error: e,
        stackTrace: st,
      );
    }

    await DeviceUtils.initialize();

    // 初始化本地 AI 服务（TTS、STT、翻译模型）
    // 不阻塞启动，失败时静默处理
    LocalAiService.instance.initialize().catchError((e) {
      logger.error('本地 AI 服务初始化失败', tag: 'INIT', error: e);
    });
  } catch (e, st) {
    logger.error('后台初始化依赖失败', tag: 'INIT', error: e, stackTrace: st);
  }
}

/// VidLang应用根组件
///
/// 配置应用的主题、语言、路由等全局设置。
/// 同时监听排他性登录被顶号事件，弹出提示并跳转登录页。
class VidLangApp extends StatefulWidget {
  final AppDeviceType initialDeviceType;

  const VidLangApp({super.key, this.initialDeviceType = AppDeviceType.iphone});

  @override
  State<VidLangApp> createState() => _VidLangAppState();
}

class _VidLangAppState extends State<VidLangApp> {
  late final StreamSubscription<SessionHijackedException> _forceLogoutSub;

  @override
  void initState() {
    super.initState();
    _forceLogoutSub = AuthService.instance.forceLogoutStream.listen((_) {
      _handleForceLogout();
    });
  }

  @override
  void dispose() {
    _forceLogoutSub.cancel();
    super.dispose();
  }

  void _handleForceLogout() {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    DialogUtils.show(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('提示'),
        content: const Text('您的账号在其他设备上已登录，请重新登录'),
        actions: [
          TextButton(
            onPressed: () {
              navigatorKey.currentState?.popUntil((r) => r.isFirst);
              navigatorKey.currentState?.pushNamedAndRemoveUntil(
                '/login',
                (r) => false,
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final designSize = DeviceConfig.getDesignSize(widget.initialDeviceType);

    return ScreenUtilInit(
      designSize: designSize,
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return Consumer(
          builder: (context, ref, _) {
            return MaterialApp(
              title: 'VidLang',
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: ref.watch(themeModeProvider).themeMode,
              debugShowCheckedModeBanner: false,
              routes: {
                '/login': (_) => const LoginPage(),
                '/audio-test': (_) => const AudioTestPage(),
                '/shengtong-http-test': (_) => const ShengtongHttpTestPage(),
              },
              navigatorKey: navigatorKey,
              home: const _AppEntry(),
            );
          },
        );
      },
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  late final Future<Widget> _target = _resolveTarget();
  bool _resolved = false;

  Future<Widget> _resolveTarget() async {
    // 第一步：强制检测数据库结构一致性（在进入主界面前必须完成）
    final schemaOk = await _verifyDatabaseSchema();
    if (!schemaOk) {
      return const _SchemaErrorPage();
    }

    // 第二步：快速检查本地是否有用户（不等待数据库完全初始化）
    // 使用优先级更高的检查，避免等待数据库初始化
    final userCode = await _getQuickUserCode();
    if (userCode == null || userCode.isEmpty) {
      return const LoginPage();
    }

    // 第三步：先返回登录页或主界面，让用户看到 UI
    // 后台异步验证登录状态
    try {
      final user = await BaseEntityExtension.findByCode<User>(
        userCode,
        () => User(),
      );
      if (user == null) {
        return const LoginPage();
      }

      AppKeysService.currentUser = user;

      // 第四步：异步验证 Supabase session（不阻塞 UI）
      if (user.authProvider == 'supabase') {
        final ok = await AuthService.instance.silentVerifySupabaseLogin(
          setAsCurrent: true,
        );
        if (!ok) {
          return LoginPage(initialEmail: user.email ?? user.username);
        }
      } else {
        await AuthService.instance.silentVerifySupabaseLogin(
          setAsCurrent: false,
        );
      }

      // 第五步：登录/自动恢复成功后，加载 API Keys（TTS、评测等）
      // 不阻塞导航，后台异步加载
      AppKeysService.loadFromRemote();

      // return const MainPage();
      return const MainPage();
    } catch (e) {
      // 如果验证失败，返回登录页
      return const LoginPage();
    }
  }

  /// 验证数据库 Schema，确保结构一致后才允许进入应用
  Future<bool> _verifyDatabaseSchema() async {
    try {
      // 等待数据库初始化完成后再检测
      await DatabaseService.database;
      final ok = await DatabaseService.verifySchemaOnStartup();
      return ok;
    } catch (e, st) {
      logger.error(
        'schema verification failed before entry',
        tag: 'INIT',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// 快速获取用户 Code，优先从内存或 SharedPreferences 读取
  Future<String?> _getQuickUserCode() async {
    try {
      // 先尝试从 SharedPreferences 快速读取（如果数据库还没准备好）
      final prefs = await SharedPreferences.getInstance();
      final quickCode = prefs.getString('current_user_code');
      if (quickCode != null && quickCode.isNotEmpty) {
        return quickCode;
      }
    } catch (_) {}

    // 如果 SharedPreferences 没有，再等待数据库初始化
    return await DatabaseService.getCurrentUserCode();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _target,
      builder: (context, snap) {
        // 第一次构建时立即显示登录页，避免长时间白屏
        if (!_resolved) {
          _resolved = true;
          return const LoginPage();
        }

        // 初始化未完成时显示启动页面
        if (snap.connectionState != ConnectionState.done) {
          return const SplashScreen();
        }
        if (snap.hasData) return snap.data!;
        return const LoginPage();
      },
    );
  }
}

/// 数据库结构检测失败错误页
///
/// 当启动时数据库 Schema 检测失败时显示，
/// 提示用户数据库初始化异常，建议重启应用或联系支持。
class _SchemaErrorPage extends StatelessWidget {
  const _SchemaErrorPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F2937),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Color(0xFFEF4444),
                size: 64,
              ),
              const SizedBox(height: 24),
              const Text(
                '数据库初始化异常',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '应用启动时检测到数据库结构不一致，自动修复失败。\n请尝试重启应用，或联系技术支持。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  DatabaseService.resetSchemaCheck();
                  // 尝试重新进入
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const _AppEntry()),
                  );
                },
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
