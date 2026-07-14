import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';
import 'package:vidlang/services/app_keys_service.dart';
import 'package:vidlang/models/base_entity.dart';
import 'package:vidlang/models/user.dart' as local;
import 'package:vidlang/services/database_service.dart';

class _SupabaseCredential {
  final String email;
  final String password;
  const _SupabaseCredential(this.email, this.password);
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

/// 排他性登录异常：当前会话已被其他设备顶替
class SessionHijackedException implements Exception {
  final String message;
  SessionHijackedException([this.message = '您的账号在其他设备上已登录，请重新登录']);

  @override
  String toString() => message;
}

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  static final _secureStorage = FlutterSecureStorage();
  static const _kSupabaseEmail = 'supabase_email';
  static const _kSupabasePassword = 'supabase_password';
  static const _kSupabaseCredKeyV1 = 'supabase_cred_key_v1';
  static const _kSupabaseCredBoxV1 = 'supabase_cred_box_v1';

  static const _uuid = Uuid();

  sb.SupabaseClient get _client => sb.Supabase.instance.client;

  Stream<sb.AuthState> get authStateChanges => sb.Supabase.instance.client.auth.onAuthStateChange;

  sb.User? get currentUser => _client.auth.currentUser;

  bool get isLoggedIn => currentUser != null;

  String? get currentEmail => currentUser?.email;

  // ==================== 排他性登录 ====================

  /// 当前设备本地生成的 session ID（登录后生成，登出时清除）
  String? _localSessionId;

  /// 从 Realtime 缓存的服务端最新活跃 session ID
  String? _cachedServerSessionId;

  /// Realtime 订阅通道
  sb.RealtimeChannel? _sessionChannel;

  /// 被顶号事件流（UI 层监听后弹出提示并跳转登录页）
  final StreamController<SessionHijackedException> _forceLogoutController =
      StreamController<SessionHijackedException>.broadcast();

  /// 被顶号事件流（供 UI 层订阅）
  Stream<SessionHijackedException> get forceLogoutStream => _forceLogoutController.stream;

  /// 注册当前设备的 session 并启动 Realtime 监听
  ///
  /// 必须在 Supabase 登录成功后调用。
  /// 生成新的本地 session ID → 调用 Edge Function UPSERT → 拉取最新 → 订阅 Realtime。
  Future<void> registerSessionAndWatch() async {
    // 1. 生成新的 session ID
    _localSessionId = _uuid.v4();

    // 2. 调用 register-session Edge Function（UPSERT 覆盖旧 session）
    try {
      await _client.functions.invoke(
        'register-session',
        body: {'session_id': _localSessionId},
      );
    } catch (e) {
      // 注册失败不阻塞登录流程，但排他性检测会降级
      // ignore: avoid_print
    }

    // 3. 拉取服务端最新 session（双重保险）
    await _fetchLatestSession();

    // 4. 启动 Realtime 订阅
    _startSessionWatch();
  }

  /// 拉取服务端最新活跃 session ID 到缓存
  Future<void> _fetchLatestSession() async {
    final userId = currentUser?.id;
    if (userId == null) return;

    try {
      final response = await _client
          .from('user_active_session')
          .select('session_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        _cachedServerSessionId = response['session_id'] as String?;
      }
    } catch (_) {}
  }

  /// 启动 Realtime 订阅，监听 user_active_session 表变更
  void _startSessionWatch() {
    _stopSessionWatch(); // 先清理旧的

    final userId = currentUser?.id;
    if (userId == null) return;

    _sessionChannel = _client.channel('user_active_session_watch');
    _sessionChannel!
        .onPostgresChanges(
          event: sb.PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_active_session',
          filter: sb.PostgresChangeFilter(
            type: sb.PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: _onSessionRealtimeEvent,
        )
        .subscribe();
  }

  /// 停止 Realtime 订阅
  void _stopSessionWatch() {
    if (_sessionChannel != null) {
      _client.removeChannel(_sessionChannel!);
      _sessionChannel = null;
    }
  }

  /// Realtime 事件回调：检测 session_id 是否被其他设备覆盖
  void _onSessionRealtimeEvent(sb.PostgresChangePayload payload) {
    final newRecord = payload.newRecord;
    final newSessionId = newRecord['session_id'] as String?;

    if (newSessionId != null &&
        newSessionId != _localSessionId &&
        _localSessionId != null) {
      // 只有当 server 缓存已确认不是本设备 session，且 Realtime 又推送了不同的 session，才视为被顶号
      // 首次注册后 _cachedServerSessionId 可能为 null（fetch 未完成）或等于 _localSessionId，此时不触发
      if (_cachedServerSessionId != null &&
          _cachedServerSessionId != _localSessionId) {
        _cachedServerSessionId = newSessionId;
        _triggerForceLogout();
      } else {
        // 首次注册或本设备事件回环，仅更新缓存
        _cachedServerSessionId = newSessionId;
      }
    } else if (newSessionId != null) {
      _cachedServerSessionId = newSessionId;
    }
  }

  /// 触发被顶号事件，通知 UI 层
  ///
  /// 同时清理本地 Supabase 凭据，防止自动重登。
  Future<void> _triggerForceLogout() async {
    if (_localSessionId == null) return; // 防止重复触发
    _localSessionId = null;
    _stopSessionWatch();
    // 清理 Supabase 凭据，防止下次启动自动重登
    try {
      await _secureStorage.delete(key: _kSupabaseCredBoxV1);
      await _secureStorage.delete(key: _kSupabaseCredKeyV1);
    } catch (_) {}
    _forceLogoutController.add(SessionHijackedException());
  }

  /// 主动校验：当前设备 session 是否仍是活跃 session
  ///
  /// 在每次调用 Supabase Edge Function 或表操作前调用。
  /// 不一致时抛出 [SessionHijackedException]。
  void ensureActiveSession() {
    // 本地用户（非 Supabase）不校验
    if (AppKeysService.currentUser?.authProvider != 'supabase') return;

    // 尚未注册 session（如刚刚登录还未完成注册）则跳过
    if (_localSessionId == null) return;

    // 缓存为空（还没拉到服务端数据）则跳过，等 Realtime 填充
    if (_cachedServerSessionId == null) return;

    if (_localSessionId != _cachedServerSessionId) {
      _triggerForceLogout();
      throw SessionHijackedException();
    }
  }

  // ==================== Supabase 认证 ====================

  Future<void> syncCurrentSessionToLocal() async {
    await _syncSupabaseSessionToLocal(setAsCurrent: true);
  }

  Future<bool> silentVerifySupabaseLogin({required bool setAsCurrent}) async {
    // ── 优先使用 Supabase SDK 自动恢复的 session ──
    // Supabase Flutter SDK 在 initialize 时会自动从 SharedPreferences
    // 恢复上次的 session，无需重新输入密码。
    final existingSession = _client.auth.currentSession;
    if (existingSession != null && !existingSession.isExpired) {
      // Session 有效，直接同步到本地
      await _syncSupabaseSessionToLocal(setAsCurrent: setAsCurrent);
      if (setAsCurrent) {
        await registerSessionAndWatch();
      }
      return true;
    }

    // ── SDK session 无效，尝试用保存的凭据重新登录 ──
    final credential = await _loadSupabaseCredential();
    if (credential == null) return false;
    try {
      await _client.auth.signInWithPassword(email: credential.email, password: credential.password);
      await _syncSupabaseSessionToLocal(password: credential.password, setAsCurrent: setAsCurrent);
      // 仅当前用户才注册排他性 session
      if (setAsCurrent) {
        await registerSessionAndWatch();
      }
      return true;
    } on sb.AuthApiException catch (_) {
      try {
        await _client.auth.signOut();
      } catch (_) {}
      return false;
    } catch (_) {
      return false;
    }
  }

  /// 邮箱注册 —— 发送验证码到邮箱
  Future<void> signUpWithEmail({required String email, required String password}) async {
    try {
      final response = await _client.auth.signUp(email: email.trim().toLowerCase(), password: password);
      if (response.user == null) {
        throw AuthException('注册请求失败，请稍后重试');
      }
    } on AuthException {
      rethrow;
    } on sb.AuthApiException catch (e) {
      throw AuthException(_mapSupabaseError(e.message));
    } on SocketException {
      throw AuthException('网络异常，请检查网络后重试');
    } catch (e) {
      throw AuthException('网络异常，请检查网络后重试');
    }
  }

  /// 验证注册验证码
  Future<void> verifySignUpOtp({required String email, required String token, String? password}) async {
    try {
      await _client.auth.verifyOTP(email: email.trim().toLowerCase(), token: token.trim(), type: sb.OtpType.signup);
      await _syncSupabaseSessionToLocal(password: password, setAsCurrent: true);
      if (password != null && password.isNotEmpty) {
        try {
          await _saveSupabaseCredential(email: email.trim().toLowerCase(), password: password);
        } catch (_) {}
      }
      // 排他性登录：注册 session 并启动监听
      await registerSessionAndWatch();
    } on AuthException {
      rethrow;
    } on sb.AuthApiException catch (e) {
      throw AuthException(_mapSupabaseError(e.message));
    } on SocketException {
      throw AuthException('网络异常，请检查网络后重试');
    } catch (e) {
      throw AuthException('验证失败，请检查验证码是否正确');
    }
  }

  /// 邮箱密码登录
  Future<void> signInWithEmail({required String email, required String password}) async {
    try {
      await _client.auth.signInWithPassword(email: email.trim().toLowerCase(), password: password);
      await _syncSupabaseSessionToLocal(password: password, setAsCurrent: true);
      try {
        await _saveSupabaseCredential(email: email.trim().toLowerCase(), password: password);
      } catch (_) {}
      // 排他性登录：注册 session 并启动监听
      await registerSessionAndWatch();
    } on AuthException {
      rethrow;
    } on sb.AuthApiException catch (e) {
      throw AuthException(_mapSupabaseError(e.message));
    } on SocketException {
      throw AuthException('网络异常，请检查网络后重试');
    } catch (e) {
      throw AuthException('网络异常，请检查网络后重试');
    }
  }

  /// Supabase 用户修改密码（调用 Supabase API）
  Future<void> changeSupabasePassword({required String newPassword}) async {
    // 排他性校验
    ensureActiveSession();

    try {
      await _client.auth.updateUser(sb.UserAttributes(password: newPassword));
      // 更新安全存储中的密码
      final credential = await _loadSupabaseCredential();
      if (credential != null) {
        await _saveSupabaseCredential(email: credential.email, password: newPassword);
      }
      // 更新本地用户表中的密码哈希
      final existingSupabaseAdmin = await BaseEntityExtension.findByCondition<local.User>(
        () => local.User(),
        where: 'auth_provider = ? AND is_deleted = 0',
        whereArgs: ['supabase'],
        limit: 1,
      );
      if (existingSupabaseAdmin.isNotEmpty) {
        final user = existingSupabaseAdmin.first;
        user.password = _hashPassword(newPassword);
        await DatabaseService.update(user);
        if (AppKeysService.currentUser?.code == user.code) {
          AppKeysService.currentUser = user;
        }
      }
    } on SessionHijackedException {
      rethrow;
    } on sb.AuthApiException catch (e) {
      throw AuthException(_mapSupabaseError(e.message));
    } on SocketException {
      throw AuthException('网络异常，请检查网络后重试');
    } catch (e) {
      throw AuthException('修改密码失败: $e');
    }
  }

  /// Supabase 发送密码重置 OTP（App 内闭环，无需网页跳转）
  ///
  /// 调用 Supabase Auth 的 resetPasswordForEmail API，
  /// 向用户邮箱发送用于密码恢复的 OTP 验证码。
  /// 用户在 App 内输入验证码后调用 [verifyResetOtp] 完成身份验证，
  /// 再调用 [updateResetPassword] 设置新密码。
  ///
  /// 整个流程无需配置 Site URL 或域名。
  Future<void> sendResetOtp({required String email}) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim().toLowerCase());
    } on sb.AuthApiException catch (e) {
      throw AuthException(_mapSupabaseError(e.message));
    } on SocketException {
      throw AuthException('网络异常，请检查网络后重试');
    } catch (e) {
      throw AuthException('发送验证码失败，请稍后重试');
    }
  }

  /// 验证密码重置 OTP
  ///
  /// 验证用户从邮箱收到的 6 位验证码，验证通过后获得一个临时 session，
  /// 随后可调用 [updateResetPassword] 更新密码。
  Future<void> verifyResetOtp({
    required String email,
    required String token,
  }) async {
    try {
      await _client.auth.verifyOTP(
        email: email.trim().toLowerCase(),
        token: token.trim(),
        type: sb.OtpType.recovery,
      );
    } on sb.AuthApiException catch (e) {
      throw AuthException(_mapSupabaseError(e.message));
    } on SocketException {
      throw AuthException('网络异常，请检查网络后重试');
    } catch (e) {
      throw AuthException('验证失败，请检查验证码是否正确');
    }
  }

  /// 在 OTP 验证通过后更新密码
  ///
  /// 必须先成功调用 [verifyResetOtp] 获得临时 session 后才能调用此方法。
  Future<void> updateResetPassword({required String newPassword}) async {
    try {
      await _client.auth.updateUser(sb.UserAttributes(password: newPassword));
    } on sb.AuthApiException catch (e) {
      throw AuthException(_mapSupabaseError(e.message));
    } on SocketException {
      throw AuthException('网络异常，请检查网络后重试');
    } catch (e) {
      throw AuthException('密码更新失败，请稍后重试');
    }
  }

  /// Supabase 发送密码重置邮件（旧方案：邮件链接跳转，需配置域名）
  ///
  /// ⚠️ 已废弃：推荐使用 [sendResetOtp] + [verifyResetOtp] + [updateResetPassword]
  /// 的 App 内 OTP 方案，无需配置域名。
  Future<void> resetSupabasePassword({
    required String email,
    String? redirectTo,
  }) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email.trim().toLowerCase(),
        redirectTo: redirectTo,
      );
    } on sb.AuthApiException catch (e) {
      throw AuthException(_mapSupabaseError(e.message));
    } on SocketException {
      throw AuthException('网络异常，请检查网络后重试');
    } catch (e) {
      throw AuthException('发送重置邮件失败，请稍后重试');
    }
  }

  /// 本地用户重置密码（需管理员操作）
  ///
  /// 本地账号没有邮箱绑定，无法自动重置密码。
  /// 此方法仅做校验，实际重置需要管理员介入：
  /// - 管理员可通过 profile 页面的用户管理功能调用 changeLocalPassword
  /// - 或通过 updateLocalPassword 直接设置新密码
  ///
  /// 返回本地用户信息（用于 UI 提示）
  Future<local.User?> lookupLocalUser({required String username}) async {
    final users = await BaseEntityExtension.findByCondition<local.User>(
      () => local.User(),
      where: 'username = ? AND auth_provider = ? AND is_deleted = 0',
      whereArgs: [username.trim(), 'local'],
      limit: 1,
    );
    if (users.isEmpty) return null;
    return users.first;
  }

  /// Supabase 完全登出（清除安全存储 + 本地当前用户 + 停止 Realtime）
  Future<void> signOut() async {
    _stopSessionWatch();
    _localSessionId = null;
    _cachedServerSessionId = null;
    await _client.auth.signOut();
    await _secureStorage.delete(key: _kSupabaseCredBoxV1);
    await _secureStorage.delete(key: _kSupabaseCredKeyV1);
    await _secureStorage.delete(key: _kSupabaseEmail);
    await _secureStorage.delete(key: _kSupabasePassword);
    await DatabaseService.clearCurrentUser();
    AppKeysService.currentUser = null;
  }

  // ==================== 本地用户认证 ====================

  /// 本地用户登录（用户名 + 密码）
  ///
  /// [username]: 本地用户名（不能是邮箱格式）
  /// [password]: 明文密码
  Future<local.User> signInLocal({required String username, required String password}) async {
    final users = await BaseEntityExtension.findByCondition<local.User>(
      () => local.User(),
      where: 'username = ? AND auth_provider = ? AND is_deleted = 0',
      whereArgs: [username.trim(), 'local'],
      limit: 1,
    );

    if (users.isEmpty) {
      throw AuthException('用户不存在');
    }

    final user = users.first;
    final hashedInput = _hashPassword(password);

    if (user.password != hashedInput) {
      throw AuthException('密码错误');
    }

    // 设置当前用户
    await DatabaseService.setCurrentUserCode(user.code);
    AppKeysService.currentUser = user;
    return user;
  }

  /// 创建本地子用户（由 Supabase 管理员操作）
  ///
  /// [username]: 用户名（不能是邮箱格式，不能重复）
  /// [password]: 明文密码
  /// [nickname]: 昵称
  Future<local.User> createLocalUser({
    required String username,
    required String password,
    String? nickname,
  }) async {
    // 排他性校验（创建子用户是 Supabase 管理员操作）
    ensureActiveSession();

    // 校验用户名不能是邮箱格式
    if (_isValidEmail(username)) {
      throw AuthException('本地用户名不能使用邮箱格式');
    }

    // 校验用户名唯一性
    final existing = await BaseEntityExtension.findByCondition<local.User>(
      () => local.User(),
      where: 'username = ? AND is_deleted = 0',
      whereArgs: [username.trim()],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw AuthException('用户名已存在');
    }

    final user = local.User(
      username: username.trim(),
      password: _hashPassword(password),
      nickname: (nickname != null && nickname.trim().isNotEmpty) ? nickname.trim() : username.trim(),
      role: 'user',
      authProvider: 'local',
      isPrimary: false,
    );
    await DatabaseService.insert(user);
    return user;
  }

  /// 本地用户修改密码
  ///
  /// [userCode]: 用户 code
  /// [oldPassword]: 旧密码（用于验证）
  /// [newPassword]: 新密码
  Future<void> changeLocalPassword({
    required String userCode,
    required String oldPassword,
    required String newPassword,
  }) async {
    final user = await BaseEntityExtension.findByCode<local.User>(userCode, () => local.User());
    if (user == null) {
      throw AuthException('用户不存在');
    }

    // 验证旧密码
    final hashedOld = _hashPassword(oldPassword);
    if (user.password != hashedOld) {
      throw AuthException('旧密码错误');
    }

    user.password = _hashPassword(newPassword);
    await DatabaseService.update(user);

    // 如果修改的是当前用户，更新内存
    if (AppKeysService.currentUser?.code == userCode) {
      AppKeysService.currentUser = user;
    }
  }

  /// 切换到指定本地用户
  Future<void> switchToLocalUser({required String userCode}) async {
    final user = await BaseEntityExtension.findByCode<local.User>(userCode, () => local.User());
    if (user == null) {
      throw AuthException('用户不存在');
    }
    await DatabaseService.setCurrentUserCode(user.code);
    AppKeysService.currentUser = user;
  }

  /// 退出当前用户（不删除用户数据，仅清除当前会话）
  Future<void> logoutCurrentUser() async {
    final currentUser = AppKeysService.currentUser;
    if (currentUser != null && currentUser.authProvider == 'supabase') {
      // Supabase 用户退出：清除 Supabase 会话 + 安全存储 + 停止 Realtime
      await signOut();
    } else {
      // 本地用户退出：仅清除当前用户标记
      await DatabaseService.clearCurrentUser();
      AppKeysService.currentUser = null;
    }
  }

  /// 获取所有本地用户列表（用于用户管理页面）
  Future<List<local.User>> getAllUsers() async {
    return await BaseEntityExtension.findByCondition<local.User>(
      () => local.User(),
      where: 'is_deleted = 0',
      orderBy: 'created_at ASC',
    );
  }

  /// 修改本地用户信息（昵称、密码）
  Future<void> updateLocalUser({
    required String userCode,
    String? nickname,
    String? newPassword,
  }) async {
    final user = await BaseEntityExtension.findByCode<local.User>(userCode, () => local.User());
    if (user == null) {
      throw AuthException('用户不存在');
    }
    if (user.authProvider == 'supabase') {
      throw AuthException('主账号不能通过此方法修改');
    }
    if (nickname != null && nickname.trim().isNotEmpty) {
      user.nickname = nickname.trim();
    }
    if (newPassword != null && newPassword.trim().isNotEmpty) {
      if (newPassword.length < 6) {
        throw AuthException('密码至少需要6位');
      }
      user.password = _hashPassword(newPassword);
    }
    await DatabaseService.update(user);
    if (AppKeysService.currentUser?.code == userCode) {
      AppKeysService.currentUser = user;
    }
  }

  /// 删除本地子用户
  Future<void> deleteLocalUser({required String userCode}) async {
    final user = await BaseEntityExtension.findByCode<local.User>(userCode, () => local.User());
    if (user == null) return;
    if (user.authProvider == 'supabase') {
      throw AuthException('不能删除主账号');
    }
    // 如果删除的是当前用户，先退出
    final currentUserCode = await DatabaseService.getCurrentUserCode();
    if (currentUserCode == userCode) {
      await DatabaseService.clearCurrentUser();
      AppKeysService.currentUser = null;
    }
    await DatabaseService.delete(user);
  }

  // ==================== 内部工具方法 ====================

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }

  Future<void> _saveSupabaseCredential({required String email, required String password}) async {
    final algorithm = AesGcm.with256bits();
    final secretKey = await _getOrCreateSupabaseCredentialKey(algorithm);
    final payload = jsonEncode({'email': email.trim().toLowerCase(), 'password': password});
    final secretBox = await algorithm.encrypt(utf8.encode(payload), secretKey: secretKey);

    final boxJson = jsonEncode({'n': base64Encode(secretBox.nonce), 'c': base64Encode(secretBox.cipherText), 'm': base64Encode(secretBox.mac.bytes)});
    await _secureStorage.write(key: _kSupabaseCredBoxV1, value: boxJson);

    await _secureStorage.delete(key: _kSupabaseEmail);
    await _secureStorage.delete(key: _kSupabasePassword);
  }

  Future<_SupabaseCredential?> _loadSupabaseCredential() async {
    final boxJson = await _secureStorage.read(key: _kSupabaseCredBoxV1);
    if (boxJson != null && boxJson.isNotEmpty) {
      try {
        final algorithm = AesGcm.with256bits();
        final secretKey = await _getOrCreateSupabaseCredentialKey(algorithm);
        final map = jsonDecode(boxJson) as Map<String, dynamic>;
        final nonce = base64Decode((map['n'] as String?) ?? '');
        final cipherText = base64Decode((map['c'] as String?) ?? '');
        final macBytes = base64Decode((map['m'] as String?) ?? '');
        final clearBytes = await algorithm.decrypt(
          SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
          secretKey: secretKey,
        );
        final payload = jsonDecode(utf8.decode(clearBytes)) as Map<String, dynamic>;
        final email = (payload['email'] as String? ?? '').trim().toLowerCase();
        final password = payload['password'] as String? ?? '';
        if (email.isEmpty || password.isEmpty) return null;
        return _SupabaseCredential(email, password);
      } catch (_) {
        return null;
      }
    }

    final legacyEmail = await _secureStorage.read(key: _kSupabaseEmail);
    final legacyPassword = await _secureStorage.read(key: _kSupabasePassword);
    if (legacyEmail == null || legacyEmail.trim().isEmpty || legacyPassword == null || legacyPassword.isEmpty) return null;
    await _saveSupabaseCredential(email: legacyEmail.trim().toLowerCase(), password: legacyPassword);
    return _SupabaseCredential(legacyEmail.trim().toLowerCase(), legacyPassword);
  }

  Future<SecretKey> _getOrCreateSupabaseCredentialKey(AesGcm algorithm) async {
    final existing = await _secureStorage.read(key: _kSupabaseCredKeyV1);
    if (existing != null && existing.isNotEmpty) {
      try {
        return SecretKey(base64Decode(existing));
      } catch (_) {}
    }

    final newKey = await algorithm.newSecretKey();
    final keyBytes = await newKey.extractBytes();
    await _secureStorage.write(key: _kSupabaseCredKeyV1, value: base64Encode(keyBytes));
    return newKey;
  }

  Future<void> _syncSupabaseSessionToLocal({String? password, required bool setAsCurrent}) async {
    final session = _client.auth.currentSession;
    final sbUser = _client.auth.currentUser;
    if (session == null || sbUser == null) return;

    final email = (sbUser.email ?? '').trim().toLowerCase();
    final userId = sbUser.id;

    local.User localUser;
    final existingSupabaseAdmin = await BaseEntityExtension.findByCondition<local.User>(
      () => local.User(),
      where: 'auth_provider = ? AND is_deleted = 0',
      whereArgs: ['supabase'],
      limit: 1,
    );

    if (existingSupabaseAdmin.isNotEmpty) {
      localUser = existingSupabaseAdmin.first;
      localUser.username = email.isNotEmpty ? email : localUser.username;
      localUser.email = email.isNotEmpty ? email : localUser.email;
      localUser.nickname = localUser.nickname.isNotEmpty ? localUser.nickname : (email.isNotEmpty ? email.split('@').first : '管理员');
      localUser.role = 'admin';
      localUser.isPrimary = true;
      localUser.authProvider = 'supabase';
      localUser.supabaseUserId = userId;
      localUser.token = session.accessToken;
      if (password != null && password.isNotEmpty) {
        localUser.password = _hashPassword(password);
      }
      await DatabaseService.update(localUser);
    } else {
      localUser = local.User(
        username: email.isNotEmpty ? email : 'admin',
        password: password != null && password.isNotEmpty ? _hashPassword(password) : '',
        nickname: email.isNotEmpty ? email.split('@').first : '管理员',
        email: email.isNotEmpty ? email : null,
        role: 'admin',
        isPrimary: true,
        token: session.accessToken,
        authProvider: 'supabase',
        supabaseUserId: userId,
      );
      await DatabaseService.insert(localUser);
    }

    if (setAsCurrent) {
      await DatabaseService.setCurrentUserCode(localUser.code);
      AppKeysService.currentUser = localUser;
    }
  }

  String _mapSupabaseError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login credentials') || lower.contains('invalid email or password')) {
      return '邮箱或密码错误';
    }
    if (lower.contains('email not confirmed')) {
      return '邮箱尚未验证，请先完成验证';
    }
    if (lower.contains('already registered') || lower.contains('already exists') || lower.contains('duplicate')) {
      return '该邮箱已注册，请直接登录';
    }
    if (lower.contains('rate limit') || lower.contains('too many requests')) {
      return '操作过于频繁，请稍后再试';
    }
    if (lower.contains('token has expired') || lower.contains('expired')) {
      return '验证码已过期，请重新获取';
    }
    if (lower.contains('token is invalid')) {
      return '验证码错误，请检查后重新输入';
    }
    if (lower.contains('password') && lower.contains('weak')) {
      return '密码强度不够，请使用更复杂的密码';
    }
    return message;
  }
}
