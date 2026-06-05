import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vidlang/services/auth_service.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/views/main/main_page.dart';

enum _AuthMode { login, register, verifyOtp }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  _AuthMode _mode = _AuthMode.login;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _otpFocus = FocusNode();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;
  Timer? _countdownTimer;
  int _countdownSeconds = 0;

  String? _pendingEmail;
  String? _pendingPassword;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _otpFocus.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownSeconds = 60;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_countdownSeconds > 0) {
          _countdownSeconds--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLogo(),
                const SizedBox(height: 40),
                _buildTitle(),
                const SizedBox(height: 8),
                _buildSubtitle(),
                const SizedBox(height: 32),
                if (_mode == _AuthMode.verifyOtp) _buildOtpForm() else _buildAuthForm(),
                const SizedBox(height: 24),
                _buildToggleMode(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(Icons.play_circle_fill_rounded, color: AppColors.primary, size: 40),
    );
  }

  Widget _buildTitle() {
    final titles = {
      _AuthMode.login: '欢迎回来',
      _AuthMode.register: '创建账号',
      _AuthMode.verifyOtp: '验证邮箱',
    };
    return Text(
      titles[_mode]!,
      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.onSurface),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildSubtitle() {
    final subtitles = {
      _AuthMode.login: '登录你的 VidLang 账号',
      _AuthMode.register: '注册一个新账号开始学习',
      _AuthMode.verifyOtp: '验证码已发送至 $_pendingEmail',
    };
    return Text(
      subtitles[_mode]!,
      style: const TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildAuthForm() {
    final isLogin = _mode == _AuthMode.login;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildEmailField(),
        const SizedBox(height: 16),
        _buildPasswordField(),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _buildError(),
        ],
        const SizedBox(height: 24),
        _buildPrimaryButton(isLogin ? '登录' : '发送验证码', _submitAuth),
        const SizedBox(height: 12),
        if (isLogin)
          GestureDetector(
            onTap: () {},
            child: const Center(
              child: Text('忘记密码？', style: TextStyle(fontSize: 13, color: AppColors.onSurfaceDisabled)),
            ),
          ),
      ],
    );
  }

  Widget _buildOtpForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildOtpField(),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _buildError(),
        ],
        const SizedBox(height: 24),
        _buildPrimaryButton('验证并完成注册', _verifyOtp),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _countdownSeconds > 0 ? '${_countdownSeconds}s 后可重新发送' : '没收到验证码？',
              style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceDisabled),
            ),
            GestureDetector(
              onTap: _countdownSeconds == 0 && !_loading ? _resendOtp : null,
              child: Text(
                ' 重新发送',
                style: TextStyle(
                  fontSize: 13,
                  color: _countdownSeconds == 0 ? AppColors.primary : AppColors.onSurfaceDisabled,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => setState(() => _mode = _AuthMode.register),
          child: const Center(
            child: Text('返回修改邮箱', style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant)),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return TextField(
      controller: _emailController,
      focusNode: _emailFocus,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      style: const TextStyle(color: AppColors.onSurface, fontSize: 15),
      decoration: _inputDecoration('邮箱地址', Icons.email_outlined),
      onSubmitted: (_) => _passwordFocus.requestFocus(),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      focusNode: _passwordFocus,
      obscureText: _obscurePassword,
      textInputAction: _mode == _AuthMode.login ? TextInputAction.done : TextInputAction.next,
      style: const TextStyle(color: AppColors.onSurface, fontSize: 15),
      decoration: _inputDecoration('密码', Icons.lock_outlined).copyWith(
        suffixIcon: IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.onSurfaceDisabled, size: 20),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      onSubmitted: _mode == _AuthMode.login ? (_) => _submitAuth() : null,
    );
  }

  Widget _buildOtpField() {
    return TextField(
      controller: _otpController,
      focusNode: _otpFocus,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      style: const TextStyle(color: AppColors.onSurface, fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.w600),
      textAlign: TextAlign.center,
      decoration: _inputDecoration('请输入验证码', null).copyWith(
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
      onSubmitted: (_) => _verifyOtp(),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData? icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.onSurfaceDisabled, fontSize: 14),
      prefixIcon: icon != null ? Icon(icon, color: AppColors.onSurfaceDisabled, size: 20) : null,
      filled: true,
      fillColor: AppColors.surfaceElevated,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.error, width: 1)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildPrimaryButton(String label, VoidCallback onPressed) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: _loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.primary.withAlpha(100),
          disabledForegroundColor: AppColors.onPrimary.withAlpha(150),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary))
            : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withAlpha(60)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleMode() {
    final isLogin = _mode == _AuthMode.login;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isLogin ? '没有账号？' : '已有账号？',
          style: const TextStyle(fontSize: 14, color: AppColors.onSurfaceDisabled),
        ),
        GestureDetector(
          onTap: () {
            setState(() {
              _error = null;
              _mode = isLogin ? _AuthMode.register : _AuthMode.login;
            });
          },
          child: Text(
            isLogin ? ' 立即注册' : ' 去登录',
            style: const TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Future<void> _submitAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      setState(() => _error = '请输入邮箱地址');
      return;
    }
    if (!_isValidEmail(email)) {
      setState(() => _error = '请输入正确的邮箱格式');
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = '请输入密码');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = '密码至少需要6位');
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      if (_mode == _AuthMode.login) {
        await AuthService.instance.signInWithEmail(email: email, password: password);
        if (!mounted) return;
        _navigateToMain();
      } else {
        await AuthService.instance.signUpWithEmail(email: email, password: password);
        if (!mounted) return;
        _pendingEmail = email;
        _pendingPassword = password;
        _otpController.clear();
        _startCountdown();
        setState(() {
          _mode = _AuthMode.verifyOtp;
          _error = null;
        });
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      await AuthService.instance.verifySignUpOtp(email: _pendingEmail!, token: otp);
      if (!mounted) return;
      _navigateToMain();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendOtp() async {
    if (_pendingEmail == null || _pendingPassword == null) return;
    setState(() => _loading = true);
    try {
      await AuthService.instance.signUpWithEmail(email: _pendingEmail!, password: _pendingPassword!);
      if (!mounted) return;
      _startCountdown();
      _otpController.clear();
      setState(() => _error = null);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _navigateToMain() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainPage()),
      (route) => false,
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }
}
