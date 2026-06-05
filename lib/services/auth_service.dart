import 'package:supabase_flutter/supabase_flutter.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  SupabaseClient get _client => Supabase.instance.client;

  Stream<AuthState> get authStateChanges => Supabase.instance.client.auth.onAuthStateChange;

  User? get currentUser => _client.auth.currentUser;

  bool get isLoggedIn => currentUser != null;

  String? get currentEmail => currentUser?.email;

  /// 邮箱注册 —— 发送验证码到邮箱
  ///
  /// 注意：需要在 Supabase Dashboard → Authentication → Email Templates
  /// 中将 Confirm signup 模板里的 {{ .ConfirmationURL }} 改为 {{ .Token }}，
  /// 这样用户收到的邮件里就会是一个 6 位数字验证码。
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
      );

      if (response.user == null) {
        throw AuthException('注册请求失败，请稍后重试');
      }
    } on AuthException {
      rethrow;
    } on AuthApiException catch (e) {
      throw AuthException(_mapSupabaseError(e.message));
    } catch (e) {
      throw AuthException('网络异常，请检查网络后重试');
    }
  }

  /// 验证注册验证码
  Future<void> verifySignUpOtp({
    required String email,
    required String token,
  }) async {
    try {
      await _client.auth.verifyOTP(
        email: email.trim().toLowerCase(),
        token: token.trim(),
        type: OtpType.signup,
      );
    } on AuthException {
      rethrow;
    } on AuthApiException catch (e) {
      throw AuthException(_mapSupabaseError(e.message));
    } catch (e) {
      throw AuthException('验证失败，请检查验证码是否正确');
    }
  }

  /// 邮箱密码登录
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
    } on AuthException {
      rethrow;
    } on AuthApiException catch (e) {
      throw AuthException(_mapSupabaseError(e.message));
    } catch (e) {
      throw AuthException('网络异常，请检查网络后重试');
    }
  }

  /// 登出
  Future<void> signOut() async {
    await _client.auth.signOut();
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
