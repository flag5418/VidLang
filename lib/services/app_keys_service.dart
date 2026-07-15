import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:vidlang/models/user.dart';
import 'package:vidlang/utils/app_globals.dart';

/// 应用配置与密钥统一管理中心
///
/// 原本分散在 config.dart（硬编码）和各服务中的配置，
/// 统一收敛到此类：
///   - Supabase 连接信息
///   - 当前登录用户
///   - 阿里云通义千问 API Key（登录时从 app_settings 动态加载）
///   - 声通语音评测 AppId/ApiKey（登录时从 app_settings 动态加载）
///   - 声通 WebSocket 地址等基础配置
///
/// 使用方式：
///   - 静态常量（Supabase URL、声通地址）：AppKeysService.supabaseUrl
///   - 动态密钥（qwen、shengtong）：AppKeysService.instance.qwenApiKey
///   - 当前用户：AppKeysService.currentUser / AppKeysService.currentUser = user
class AppKeysService {
  AppKeysService._();

  static final AppKeysService instance = AppKeysService._();

  // ════════════════════════════════════════════
  // ① 静态常量 —— 基础连接信息（原 config.dart）
  // ════════════════════════════════════════════

  /// Supabase 项目 URL
  static const String supabaseUrl = 'https://tqehcadjuwodbmgmxzmf.supabase.co';

  /// Supabase 匿名 Key
  static const String supabaseAnonKey =
      'sb_publishable_aKICDtmL2aisDtOpNh88jQ_IZ3m_fuB';

  // ════════════════════════════════════════════
  // ② 声通语音评测 —— 基础配置（原 config.dart）
  // ════════════════════════════════════════════

  /// 声通 WebSocket 地址（ws 协议）
  static const String shengtongWsUrl = 'ws://api.stkouyu.com:8080';

  /// 声通 WebSocket 地址（wss 协议）
  static const String shengtongWssUrl = 'wss://api.stkouyu.com:8443';

  /// 是否使用 SSL 连接声通
  static const bool shengtongUseSSL = false;

  /// 根据 SSL 配置返回对应的声通 WebSocket 地址
  static String get shengtongBaseUrl =>
      shengtongUseSSL ? shengtongWssUrl : shengtongWsUrl;

  // ════════════════════════════════════════════
  // ③ 运行时状态 —— 当前用户（原 config.dart 静态字段）
  // ════════════════════════════════════════════

  /// 当前登录用户（全局共享）
  ///
  /// ⚠️ 已迁移至 AppGlobals.user，此处保留为兼容别名。
  /// 新代码请使用 AppGlobals.user / AppGlobals.updateUser()。
  static User? get currentUser => AppGlobals.user;
  static set currentUser(User? user) { AppGlobals.updateUser(user); }

  // ════════════════════════════════════════════
  // ④ 动态密钥 —— 从服务端 app_settings 表加载
  // ════════════════════════════════════════════

  /// 通义千问 API Key（用于 DashScope TTS 直连）
  String? _qwenApiKey;

  /// 声通 App Key / App ID（从服务端 app_settings 表的 shengtong_app_id 加载）
  String? _shengtongAppKey;

  /// 声通 API Key（从服务端 app_settings 表的 shengtong_api_key 加载）
  String? _shengtongApiKey;

  /// 声通 Secret Key（从服务端 app_settings 表的 shengtong_secret_key 加载）
  String? _shengtongSecretKey;

  /// 是否已尝试从远程加载
  bool _loaded = false;

  /// 加载完成的 Future（用于外部 await 等待加载完成）
  static Future<void>? _loadFuture;

  // ─── 公开访问器 ──────────────────────────────

  /// 通义千问 API Key（TTS 使用）
  String? get qwenApiKey => _qwenApiKey;

  /// 声通 App Key / App ID（评测使用）—— 从 app_settings 表的 shengtong_app_id 加载
  String? get shengtongAppKey => _shengtongAppKey;

  /// 声通 API Key（评测使用）—— 从 app_settings 表的 shengtong_api_key 加载
  String? get shengtongApiKey => _shengtongApiKey;

  /// 声通 Secret Key（评测使用）—— 从 app_settings 表的 shengtong_secret_key 加载
  String? get shengtongSecretKey => _shengtongSecretKey;

  /// 是否已成功加载密钥
  bool get isLoaded => _loaded;

  /// 所有 AI 密钥是否都已就绪（qwen + shengtong 全部 3 个）
  bool get isReady =>
    _loaded &&
        _qwenApiKey != null &&
        _qwenApiKey!.isNotEmpty &&
        _shengtongAppKey != null &&
        _shengtongAppKey!.isNotEmpty &&
        _shengtongApiKey != null &&
        _shengtongApiKey!.isNotEmpty &&
        _shengtongSecretKey != null &&
        _shengtongSecretKey!.isNotEmpty;

  // ─── 核心方法 ────────────────────────────────

  /// 从 Supabase app_settings 表加载所有 API Key
  ///
  /// 应在登录成功后调用一次。如果加载失败不会抛异常，
  /// 而是记录日志并保留空值（需要 key 的功能会优雅降级）。
  ///
  /// 幂等：重复调用只会执行一次加载，后续调用直接返回已完成的 Future。
  static Future<void> loadFromRemote() async {
    // 幂等：已在加载中或已完成，直接返回
    if (_loadFuture != null) return _loadFuture!;

    _loadFuture = _doLoad();
    return _loadFuture!;
  }

  /// 实际加载逻辑（私有）
  static Future<void> _doLoad() async {
    final self = instance;
    try {
      final client = sb.Supabase.instance.client;

      // 批量查询所有需要的 key（与 app_settings 表中的 key 名完全一致）
      final keys = ['qwen_api_key', 'shengtong_app_id', 'shengtong_api_key', 'shengtong_secret_key'];
      final List<Map<String, dynamic>> allRows = [];

      for (final k in keys) {
        final res = await client
            .from('app_settings')
            .select('key, value')
            .eq('key', k)
            .maybeSingle();
        if (res != null) {
          allRows.add(res);
        } else {
          print('🔑 [AppKeys] ℹ️ key="$k" 在 app_settings 中未找到（可能尚未配置）');
        }
      }

      print('🔑 [AppKeys] 📊 查询完成，共获取 ${allRows.length}/${keys.length} 条记录');

      for (final row in allRows) {
        final key = row['key'] as String?;
        final value = row['value'] as String?;
        if (key == null || value == null || value.isEmpty) continue;

        switch (key) {
          case 'qwen_api_key':
            self._qwenApiKey = value;
            break;
          case 'shengtong_app_id':
            self._shengtongAppKey = value;
            break;
          case 'shengtong_api_key':
            self._shengtongApiKey = value;
            break;
          case 'shengtong_secret_key':
            self._shengtongSecretKey = value;
            break;
        }
      }

      self._loaded = true;

      // 日志输出（脱敏显示）
      final qwenMask = self._qwenApiKey?.isNotEmpty == true ? '${self._qwenApiKey!.substring(0, 8)}...' : '未配置';
      final stAppIdMask = self._shengtongAppKey?.isNotEmpty == true ? '${self._shengtongAppKey!.substring(0, 8)}...' : '未配置';
      final stApiKeyMask = self._shengtongApiKey?.isNotEmpty == true ? '${self._shengtongApiKey!.substring(0, 6)}...' : '未配置';
      final stSecretMask = self._shengtongSecretKey?.isNotEmpty == true ? '${self._shengtongSecretKey!.substring(0, 6)}...' : '未配置';

      if (self.isReady) {
        print('🔑 [AppKeys] ✅ 所有密钥已就绪 | qwen=$qwenMask | st_app_id=$stAppIdMask | st_api_key=$stApiKeyMask | st_secret=$stSecretMask');
      } else {
        print('🔑 [AppKeys] ⚠️ 部分密钥缺失 | qwen=$qwenMask | st_app_id=$stAppIdMask | st_api_key=$stApiKeyMask | st_secret=$stSecretMask');
      }
    } catch (e) {
      self._loaded = true; // 标记已尝试加载，避免重复请求
      print('🔑 [AppKeys] ❌ 加载失败: $e');
    }
  }

  /// 等待密钥加载完成（如果正在加载中则阻塞，否则立即返回）
  ///
  /// 使用场景：TTS/评测等服务在需要 key 时调用，确保登录后的异步加载已完成。
  /// 带超时保护，默认最多等待 10 秒。
  static Future<void> ensureLoaded({Duration timeout = const Duration(seconds: 10)}) async {
    if (instance._loaded) return;
    if (_loadFuture != null) {
      await _loadFuture!.timeout(timeout, onTimeout: () {
        print('🔑 [AppKeys] ⏰ 等待密钥加载超时 (${timeout.inSeconds}s)');
      });
    }
  }

  /// 获取 qwenApiKey，如果尚未加载则先等待加载完成
  ///
  /// 这是 TTS 等服务推荐的安全读取方式。
  static Future<String?> getQwenApiKey({Duration timeout = const Duration(seconds: 10)}) async {
    await ensureLoaded(timeout: timeout);
    return instance.qwenApiKey;
  }

  /// 清除所有缓存的密钥（登出时调用）
  static void clear() {
    final self = instance;
    self._qwenApiKey = null;
    self._shengtongAppKey = null;
    self._shengtongApiKey = null;
    self._shengtongSecretKey = null;
    self._loaded = false;
    _loadFuture = null; // 允许下次登录后重新加载
    print('🔑 [AppKeys] 🗑️ 已清除所有缓存的密钥');
  }

  /// 强制重新加载（用于测试或设置更新后刷新）
  static Future<void> reload() async {
    clear();
    await loadFromRemote();
  }
}
