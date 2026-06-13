import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidlang/models/base_entity.dart';
import 'package:vidlang/models/user.dart';
import 'package:vidlang/services/auth_service.dart';
import 'package:vidlang/views/main/main_page.dart';

enum _AuthMode { login, register, verifyOtp }
enum _LoginTab { supabase, local }

class LoginPage extends StatefulWidget {
  final bool requireSupabaseReauth;
  final String? initialEmail;

  const LoginPage({super.key, this.requireSupabaseReauth = false, this.initialEmail});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  _AuthMode _mode = _AuthMode.login;
  _LoginTab _tab = _LoginTab.supabase;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  // 本地用户登录
  final _localUsernameController = TextEditingController();
  final _localPasswordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _otpFocus = FocusNode();
  final _localUsernameFocus = FocusNode();
  final _localPasswordFocus = FocusNode();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureLocalPassword = true;
  String? _error;
  Timer? _countdownTimer;
  int _countdownSeconds = 0;

  String? _pendingEmail;
  String? _pendingPassword;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.trim().isNotEmpty) {
      _emailController.text = widget.initialEmail!.trim();
    } else {
      _loadLastLogin();
    }
    if (widget.requireSupabaseReauth) {
      _mode = _AuthMode.login;
    }
  }

  /// 从本地缓存加载上次登录名
  Future<void> _loadLastLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('last_login_name') ?? '';
    final tab = prefs.getString('last_login_tab') ?? 'supabase';
    if (!mounted) return;
    if (name.isNotEmpty) {
      if (tab == 'local') {
        _localUsernameController.text = name;
        setState(() => _tab = _LoginTab.local);
      } else {
        _emailController.text = name;
        setState(() => _tab = _LoginTab.supabase);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _localUsernameController.dispose();
    _localPasswordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _otpFocus.dispose();
    _localUsernameFocus.dispose();
    _localPasswordFocus.dispose();
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
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLogo(),
                const SizedBox(height: 40),
                // _buildTitle(),
                // const SizedBox(height: 8),
                // _buildSubtitle(),
                // const SizedBox(height: 24),
                if (!widget.requireSupabaseReauth) _buildTabSwitcher(),
                const SizedBox(height: 16),
                if (_mode == _AuthMode.verifyOtp)
                  _buildOtpForm()
                else if (_tab == _LoginTab.local)
                  _buildLocalForm()
                else
                  _buildAuthForm(),
                const SizedBox(height: 24),
                if (!widget.requireSupabaseReauth && _mode != _AuthMode.verifyOtp) _buildToggleMode(),
              ],
            ),
          
        ),
      ),
    );
  }

  Widget _buildLogo() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
       padding: EdgeInsets.only(
        top: 20,
        bottom: 20,
       ),
      child:
      Column(
children: [
  Icon(Icons.school, color: colorScheme.primary, size: 22.w * 1.8),
  Text('VidLang', style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
  Text('看视频、听英语、读文章、轻松学英语', style: TextStyle(fontSize:12.sp, fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant)),
  
],
      )
       
    );
  }

  Widget _buildTitle() {
    final colorScheme = Theme.of(context).colorScheme;
    if (_tab == _LoginTab.local && _mode != _AuthMode.verifyOtp) {
      return Text(
        '本地登录',
        style: TextStyle(fontSize: 26.sp, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
        textAlign: TextAlign.center,
      );
    }
    final titles = widget.requireSupabaseReauth
        ? {_AuthMode.login: '验证主账号', _AuthMode.register: '创建账号', _AuthMode.verifyOtp: '验证邮箱'}
        : {_AuthMode.login: '欢迎回来', _AuthMode.register: '创建账号', _AuthMode.verifyOtp: '验证邮箱'};
    return Text(
      titles[_mode]!,
      style: TextStyle(fontSize: 26.sp, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildSubtitle() {
    final colorScheme = Theme.of(context).colorScheme;
    if (_tab == _LoginTab.local && _mode != _AuthMode.verifyOtp) {
      return Text(
        '使用本地账号登录',
        style: TextStyle(fontSize: 14.sp, color: colorScheme.onSurfaceVariant),
        textAlign: TextAlign.center,
      );
    }
    final subtitles = widget.requireSupabaseReauth
        ? {_AuthMode.login: '请输入主账号密码以继续使用', _AuthMode.register: '注册一个新账号开始学习', _AuthMode.verifyOtp: '验证码已发送至 $_pendingEmail'}
        : {_AuthMode.login: '登录你的 VidLang 账号', _AuthMode.register: '注册一个新账号开始学习', _AuthMode.verifyOtp: '验证码已发送至 $_pendingEmail'};
    return Text(
      subtitles[_mode]!,
      style: TextStyle(fontSize: 14.sp, color: colorScheme.onSurfaceVariant),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildAuthForm() {
    final colorScheme = Theme.of(context).colorScheme;
    final isLogin = _mode == _AuthMode.login;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildEmailField(),
        const SizedBox(height: 16),
        _buildPasswordField(),
        if (_error != null) ...[const SizedBox(height: 12), _buildError()],
        const SizedBox(height: 24),
        _buildPrimaryButton(isLogin ? '登录' : '发送验证码', _submitAuth),
        const SizedBox(height: 12),
        if (isLogin)
          GestureDetector(
            onTap: () {},
            child: Center(
              child: Text('忘记密码？', style: TextStyle(fontSize: 13.sp, color: colorScheme.onSurfaceVariant)),
            ),
          ),
      ],
    );
  }

  Widget _buildOtpForm() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildOtpField(),
        if (_error != null) ...[const SizedBox(height: 12), _buildError()],
        const SizedBox(height: 24),
        _buildPrimaryButton('验证并完成注册', _verifyOtp),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _countdownSeconds > 0 ? '${_countdownSeconds}s 后可重新发送' : '没收到验证码？',
              style: TextStyle(fontSize: 13.sp, color: colorScheme.onSurfaceVariant),
            ),
            GestureDetector(
              onTap: _countdownSeconds == 0 && !_loading ? _resendOtp : null,
              child: Text(
                ' 重新发送',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: _countdownSeconds == 0 ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => setState(() => _mode = _AuthMode.register),
          child: Center(
            child: Text('返回修改邮箱', style: TextStyle(fontSize: 13.sp, color: colorScheme.onSurfaceVariant)),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _emailController,
      focusNode: _emailFocus,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      style: TextStyle(color: colorScheme.onSurface, fontSize: 15.sp),
      decoration: _inputDecoration('邮箱地址', Icons.email_outlined),
      readOnly: widget.requireSupabaseReauth && widget.initialEmail != null && widget.initialEmail!.trim().isNotEmpty,
      onSubmitted: (_) => _passwordFocus.requestFocus(),
    );
  }

  Widget _buildPasswordField() {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _passwordController,
      focusNode: _passwordFocus,
      obscureText: _obscurePassword,
      textInputAction: _mode == _AuthMode.login ? TextInputAction.done : TextInputAction.next,
      style: TextStyle(color: colorScheme.onSurface, fontSize: 15.sp),
      decoration: _inputDecoration('密码', Icons.lock_outlined).copyWith(
        suffixIcon: IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: colorScheme.onSurfaceVariant, size: 20.sp),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      onSubmitted: _mode == _AuthMode.login ? (_) => _submitAuth() : null,
    );
  }

  Widget _buildOtpField() {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _otpController,
      focusNode: _otpFocus,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      style: TextStyle(color: colorScheme.onSurface, fontSize: 22.sp, letterSpacing: 8, fontWeight: FontWeight.w600),
      textAlign: TextAlign.center,
      decoration: _inputDecoration('请输入验证码', null).copyWith(counterText: '', contentPadding: const EdgeInsets.symmetric(vertical: 16)),
      onSubmitted: (_) => _verifyOtp(),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData? icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14.sp),
      prefixIcon: icon != null ? Icon(icon, color: colorScheme.onSurfaceVariant, size: 20.sp) : null,
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.error, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildPrimaryButton(String label, VoidCallback onPressed) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 34.h * 1.47,
      child: ElevatedButton(
        onPressed: _loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: colorScheme.primary.withAlpha(100),
          disabledForegroundColor: colorScheme.onPrimary.withAlpha(150),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(label, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildError() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.error.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.error.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.error, size: 18.sp),
          SizedBox(width: 8),
          Expanded(
            child: Text(_error!, style: TextStyle(color: colorScheme.error, fontSize: 13.sp)),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleMode() {
    final colorScheme = Theme.of(context).colorScheme;
    final isLogin = _mode == _AuthMode.login;
    // 本地用户模式下不显示注册/登录切换
    if (_tab == _LoginTab.local) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(isLogin ? '没有账号？' : '已有账号？', style: TextStyle(fontSize: 14.sp, color: colorScheme.onSurfaceVariant)),
        GestureDetector(
          onTap: () {
            setState(() {
              _error = null;
              _mode = isLogin ? _AuthMode.register : _AuthMode.login;
            });
          },
          child: Text(
            isLogin ? ' 立即注册' : ' 去登录',
            style: TextStyle(fontSize: 14.sp, color: colorScheme.primary, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  // ==================== Tab 切换 ====================

  Widget _buildTabSwitcher() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _tabButton('账号登录', _LoginTab.supabase),
          _tabButton('本地登录', _LoginTab.local),
        ],
      ),
    );
  }

  Widget _tabButton(String label, _LoginTab tab) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = _tab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _tab = tab;
            _error = null;
            _mode = _AuthMode.login;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: isActive ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 本地用户登录表单 ====================

  Widget _buildLocalForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLocalUsernameField(),
        const SizedBox(height: 16),
        _buildLocalPasswordField(),
        if (_error != null) ...[const SizedBox(height: 12), _buildError()],
        const SizedBox(height: 24),
        _buildPrimaryButton('登录', _submitLocalLogin),
      ],
    );
  }

  Widget _buildLocalUsernameField() {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _localUsernameController,
      focusNode: _localUsernameFocus,
      textInputAction: TextInputAction.next,
      style: TextStyle(color: colorScheme.onSurface, fontSize: 15.sp),
      decoration: _inputDecoration('用户名', Icons.person_outlined),
      onSubmitted: (_) => _localPasswordFocus.requestFocus(),
    );
  }

  Widget _buildLocalPasswordField() {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _localPasswordController,
      focusNode: _localPasswordFocus,
      obscureText: _obscureLocalPassword,
      textInputAction: TextInputAction.done,
      style: TextStyle(color: colorScheme.onSurface, fontSize: 15.sp),
      decoration: _inputDecoration('密码', Icons.lock_outlined).copyWith(
        suffixIcon: IconButton(
          icon: Icon(_obscureLocalPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: colorScheme.onSurfaceVariant, size: 20.sp),
          onPressed: () => setState(() => _obscureLocalPassword = !_obscureLocalPassword),
        ),
      ),
      onSubmitted: (_) => _submitLocalLogin(),
    );
  }

  Future<void> _submitLocalLogin() async {
    final username = _localUsernameController.text.trim();
    final password = _localPasswordController.text;

    if (username.isEmpty) {
      setState(() => _error = '请输入用户名');
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = '请输入密码');
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      await AuthService.instance.signInLocal(username: username, password: password);
      if (!mounted) return;
      _navigateToMain();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ==================== Supabase 认证 ====================

  Future<void> _submitAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (widget.requireSupabaseReauth) {
      if (widget.initialEmail != null &&
          widget.initialEmail!.trim().isNotEmpty &&
          email.trim().toLowerCase() != widget.initialEmail!.trim().toLowerCase()) {
        setState(() => _error = '请使用当前主账号邮箱验证');
        return;
      }
    }

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
        if (!widget.requireSupabaseReauth) {
          final existing = await BaseEntityExtension.findByCondition<User>(
            () => User(),
            where: 'auth_provider = ? AND is_deleted = 0',
            whereArgs: ['supabase'],
            limit: 1,
          );
          if (existing.isNotEmpty) {
            final existingEmail = (existing.first.email ?? existing.first.username).trim().toLowerCase();
            final inputEmail = email.trim().toLowerCase();
            if (existingEmail.isNotEmpty && existingEmail != inputEmail) {
              final ok = await _confirmSwitchSupabase(existingEmail, inputEmail);
              if (!ok) return;
            }
          }
        }
        await AuthService.instance.signInWithEmail(email: email, password: password);
        if (!mounted) return;
        _navigateToMain();
      } else {
        if (widget.requireSupabaseReauth) {
          setState(() => _error = '请先验证主账号后再继续');
          return;
        }
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

  Future<bool> _confirmSwitchSupabase(String oldEmail, String newEmail) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          title: Text(
            '切换主账号',
            style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600),
          ),
          content: Text('已存在主账号：$oldEmail\n即将切换为：$newEmail\n切换后计费体系将以新主账号为准，本地子用户不会删除。', style: TextStyle(color: cs.onSurfaceVariant)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('继续')),
          ],
        );
      },
    );
    return r ?? false;
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      await AuthService.instance.verifySignUpOtp(email: _pendingEmail!, token: otp, password: _pendingPassword);
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
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const MainPage()), (route) => false);
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }
}
