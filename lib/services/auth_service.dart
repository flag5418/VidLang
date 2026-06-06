import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:vidlang/config.dart';
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

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  static final _secureStorage = FlutterSecureStorage();
  static const _kSupabaseEmail = 'supabase_email';
  static const _kSupabasePassword = 'supabase_password';
  static const _kSupabaseCredKeyV1 = 'supabase_cred_key_v1';
  static const _kSupabaseCredBoxV1 = 'supabase_cred_box_v1';

  sb.SupabaseClient get _client => sb.Supabase.instance.client;

  Stream<sb.AuthState> get authStateChanges => sb.Supabase.instance.client.auth.onAuthStateChange;

  sb.User? get currentUser => _client.auth.currentUser;

  bool get isLoggedIn => currentUser != null;

  String? get currentEmail => currentUser?.email;

  Future<void> syncCurrentSessionToLocal() async {
    await _syncSupabaseSessionToLocal(setAsCurrent: true);
  }

  Future<bool> silentVerifySupabaseLogin({required bool setAsCurrent}) async {
    final credential = await _loadSupabaseCredential();
    if (credential == null) return false;
    try {
      await _client.auth.signInWithPassword(email: credential.email, password: credential.password);
      await _syncSupabaseSessionToLocal(password: credential.password, setAsCurrent: setAsCurrent);
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
  ///
  /// 注意：需要在 Supabase Dashboard → Authentication → Email Templates
  /// 中将 Confirm signup 模板里的 {{ .ConfirmationURL }} 改为 {{ .Token }}，
  /// 这样用户收到的邮件里就会是一个 6 位数字验证码。
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

  /// 登出
  Future<void> signOut() async {
    await _client.auth.signOut();
    await _secureStorage.delete(key: _kSupabaseCredBoxV1);
    await _secureStorage.delete(key: _kSupabaseCredKeyV1);
    await _secureStorage.delete(key: _kSupabaseEmail);
    await _secureStorage.delete(key: _kSupabasePassword);
    await DatabaseService.clearCurrentUser();
    AppConfig.currentUser = null;
  }

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
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
      AppConfig.currentUser = localUser;
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
    return message;
  }
}
