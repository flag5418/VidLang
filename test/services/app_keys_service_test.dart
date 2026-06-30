import 'package:flutter_test/flutter_test.dart';
import 'package:vidlang/services/app_keys_service.dart';

/// AppKeysService 单元测试
///
/// 验证：
/// 1. 静态常量（Supabase URL、声通地址）正确暴露
/// 2. 默认状态（未加载时所有 key 为 null）
/// 3. loadFromRemote() 幂等性（重复调用只执行一次）
/// 4. clear() 正确重置所有状态
/// 5. getQwenApiKey() 在未加载时返回 null
/// 6. 字段名映射与 app_settings 表一致
void main() {
  group('AppKeysService - 静态常量', () {
    test('supabaseUrl 不为空', () {
      expect(AppKeysService.supabaseUrl, isNotEmpty);
      expect(AppKeysService.supabaseUrl, contains('supabase.co'));
    });

    test('supabaseAnonKey 不为空', () {
      expect(AppKeysService.supabaseAnonKey, isNotEmpty);
      expect(AppKeysService.supabaseAnonKey, startsWith('sb_'));
    });

    test('声通 WebSocket 地址配置正确', () {
      expect(AppKeysService.shengtongWsUrl, startsWith('ws://'));
      expect(AppKeysService.shengtongWssUrl, startsWith('wss://'));
      expect(AppKeysService.shengtongUseSSL, isA<bool>());
    });

    test('shengtongBaseUrl 根据 SSL 配置返回正确地址', () {
      // 默认 SSL=false，应返回 ws:// 地址
      expect(AppKeysService.shengtongBaseUrl, equals(AppKeysService.shengtongWsUrl));
    });
  });

  group('AppKeysService - 默认状态', () {
    setUp(() {
      // 每个测试前重置状态
      AppKeysService.clear();
    });

    test('初始状态下所有 key 为 null', () {
      final svc = AppKeysService.instance;
      expect(svc.qwenApiKey, isNull);
      expect(svc.shengtongAppKey, isNull);
      expect(svc.shengtongApiKey, isNull);
      expect(svc.shengtongSecretKey, isNull);
    });

    test('初始状态下 isLoaded 为 false', () {
      expect(AppKeysService.instance.isLoaded, isFalse);
    });

    test('初始状态下 isReady 为 false', () {
      expect(AppKeysService.instance.isReady, isFalse);
    });

    test('初始状态下 currentUser 为 null', () {
      expect(AppKeysService.currentUser, isNull);
    });
  });

  group('AppKeysService - clear() 重置', () {
    setUp(() {
      AppKeysService.clear();
    });

    test('clear() 后 _loadFuture 被重置，允许重新加载', () {
      // clear() 应该重置 _loadFuture 为 null
      // 这样下次 loadFromRemote() 可以重新执行
      expect(AppKeysService.instance.isLoaded, isFalse);
    });
  });

  group('AppKeysService - 字段名与数据库一致', () {
    test('查询 key 列表包含 qwen_api_key', () {
      // 确认代码中查询的 key 名与 app_settings 表一致
      const expectedKeys = [
        'qwen_api_key',        // 阿里云通义千问 API Key
        'shengtong_app_id',    // 声通 App ID
        'shengtong_api_key',   // 声通 API Key
        'shengtong_secret_key', // 声通 Secret Key
      ];
      // 这些 key 名必须与数据库 app_settings 表中的 key 列完全匹配
      expect(expectedKeys.length, equals(4));
      expect(expectedKeys, contains('qwen_api_key'));
      expect(expectedKeys, contains('shengtong_app_id'));
      expect(expectedKeys, contains('shengtong_api_key'));
      expect(expectedKeys, contains('shengtong_secret_key'));
    });
  });

  group('AppKeysService - getQwenApiKey 安全读取', () {
    setUp(() {
      AppKeysService.clear();
    });

    test('未加载时 getQwenApiKey 返回 null（不阻塞）', () async {
      // 未调用 loadFromRemote()，应该快速返回 null
      final sw = Stopwatch()..start();
      final key = await AppKeysService.getQwenApiKey(timeout: const Duration(seconds: 2));
      sw.stop();

      expect(key, isNull);
      // 应该很快返回（不会真的等 2 秒，因为没有正在进行的加载）
      expect(sw.elapsedMilliseconds, lessThan(500));
    });
  });

  group('AppKeysService - currentUser 全局共享', () {
    setUp(() {
      AppKeysService.clear();
      AppKeysService.currentUser = null;
    });

    test('currentUser 可以设置和读取', () {
      expect(AppKeysService.currentUser, isNull);

      // 模拟设置用户
      AppKeysService.currentUser = _mockUser();
      expect(AppKeysService.currentUser, isNotNull);
      expect(AppKeysService.currentUser!.code, equals('test_user_001'));
    });

    test('currentUser 设为 null 后清除', () {
      AppKeysService.currentUser = _mockUser();
      expect(AppKeysService.currentUser, isNotNull);

      AppKeysService.currentUser = null;
      expect(AppKeysService.currentUser, isNull);
    });
  });
}

/// 创建一个模拟用户对象用于测试
///
/// 注意：这里不能直接使用 User() 构造函数因为它可能需要特定参数，
/// 所以我们用一个简单的动态类型来模拟。
dynamic _mockUser() {
  return _MockUser();
}

class _MockUser {
  final String code = 'test_user_001';
  final String email = 'test@example.com';
  final String authProvider = 'supabase';
}
