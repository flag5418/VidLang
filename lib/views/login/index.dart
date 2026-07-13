/// 登录页面
///
/// 支持两种设备类型的独立 UI 设计：
/// - iPhone: 单列居中布局
/// - iPad: 左右分屏布局（左侧品牌区 + 右侧表单区）
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidlang/models/device_type.dart';
import 'package:vidlang/providers/device_type_provider.dart';
import 'package:vidlang/models/base_entity.dart';
import 'package:vidlang/models/user.dart';
import 'package:vidlang/services/auth_service.dart';
import 'package:vidlang/services/app_keys_service.dart';
import 'package:vidlang/views/main/main_page.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';
import 'package:vidlang/widgets/app_dialogs.dart';

enum _AuthMode { login, register, verifyOtp }

enum _LoginTab { supabase, local }

class LoginPage extends ConsumerStatefulWidget {
  final bool requireSupabaseReauth;
  final String? initialEmail;

  const LoginPage({
    super.key,
    this.requireSupabaseReauth = false,
    this.initialEmail,
  });

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  _AuthMode _mode = _AuthMode.login;
  _LoginTab _tab = _LoginTab.supabase;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
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

  AppDeviceType get _deviceType => ref.read(deviceTypeProvider);

  bool get _isIpad => _deviceType.isTablet;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isIpad) {
      return _buildIpadLayout(colorScheme);
    }
    return _buildIphoneLayout(colorScheme);
  }

  // ============================================================
  // iPhone 布局 - 单列居中
  // ============================================================

  Widget _buildIphoneLayout(ColorScheme colorScheme) {
    return Scaffold(
      backgroundColor: colorScheme.surface,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: Adaptive.w(context, 16),
            vertical: Adaptive.h(context, 20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildLogo(),
              SizedBox(height: Adaptive.h(context, 32)),
              if (!widget.requireSupabaseReauth) _buildTabSwitcher(),
              SizedBox(height: Adaptive.h(context, 14)),
              if (_mode == _AuthMode.verifyOtp)
                _buildOtpForm()
              else if (_tab == _LoginTab.local)
                _buildLocalForm()
              else
                _buildAuthForm(),
              SizedBox(height: Adaptive.h(context, 20)),
              if (!widget.requireSupabaseReauth && _mode != _AuthMode.verifyOtp)
                _buildToggleMode(),
              SizedBox(height: Adaptive.h(context, 20)),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // iPad 布局 - 左右分屏
  // ============================================================

  Widget _buildIpadLayout(ColorScheme colorScheme) {
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 左侧品牌区（沉浸式深蓝背景）
          Expanded(
            flex: 4,
            child: _buildBrandPanel(colorScheme),
          ),
          // 右侧表单区（白色背景，内容居中）
          Expanded(
            flex: 6,
            child: _buildIpadFormPanel(colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandPanel(ColorScheme colorScheme) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E3A8A),
            Color(0xFF1E40AF),
            Color(0xFF2563EB),
          ],
        ),
      ),
      child: Stack(
        children: [
          // 装饰性圆点
          Positioned(
            top: Adaptive.w(context, 50),
            right: Adaptive.w(context, 30),
            child: Container(
              width: Adaptive.w(context, 100),
              height: Adaptive.w(context, 100),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: Adaptive.w(context, 80),
            left: -Adaptive.w(context, 24),
            child: Container(
              width: Adaptive.w(context, 150),
              height: Adaptive.w(context, 150),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.4,
            right: -Adaptive.w(context, 50),
            child: Container(
              width: Adaptive.w(context, 200),
              height: Adaptive.w(context, 200),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.03),
              ),
            ),
          ),
          // 品牌内容
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: Adaptive.w(context, 32)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    padding: EdgeInsets.all(Adaptive.w(context, 18)),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      AppIcons.schoolFill,
                      color: Colors.white,
                      size: Adaptive.w(context, 44),
                    ),
                  ),
                  SizedBox(height: Adaptive.h(context, 24)),
                  // 品牌名
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'VidLang',
                      style: TextStyle(
                        fontSize: Adaptive.sp(context, 34),
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  SizedBox(height: Adaptive.h(context, 14)),
                  // 分割线
                  Container(
                    width: Adaptive.w(context, 36),
                    height: Adaptive.h(context, 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(Adaptive.r(context, 2)),
                    ),
                  ),
                  SizedBox(height: Adaptive.h(context, 18)),
                  // 标语
                  Text(
                    '看视频、听英语、读文章',
                    style: TextStyle(
                      fontSize: Adaptive.sp(context, 15),
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.9),
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: Adaptive.h(context, 5)),
                  Text(
                    '轻松学英语',
                    style: TextStyle(
                      fontSize: Adaptive.sp(context, 15),
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.9),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIpadFormPanel(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surface,
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(vertical: Adaptive.h(context, 36)),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Adaptive.w(context, 380)),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: Adaptive.w(context, 24)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 欢迎标题
                  Text(
                    '欢迎回来',
                    style: TextStyle(
                      fontSize: Adaptive.sp(context, 22),
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: Adaptive.h(context, 6)),
                  Text(
                    '登录以继续使用 VidLang',
                    style: TextStyle(
                      fontSize: Adaptive.sp(context, 13),
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: Adaptive.h(context, 28)),
                  if (!widget.requireSupabaseReauth) _buildTabSwitcher(),
                  if (!widget.requireSupabaseReauth)
                    SizedBox(height: Adaptive.h(context, 20)),
                  if (_mode == _AuthMode.verifyOtp)
                    _buildOtpForm()
                  else if (_tab == _LoginTab.local)
                    _buildLocalForm()
                  else
                    _buildAuthForm(),
                  SizedBox(height: Adaptive.h(context, 20)),
                  if (!widget.requireSupabaseReauth &&
                      _mode != _AuthMode.verifyOtp)
                    _buildToggleMode(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 通用组件 - iPhone/iPad 共享
  // ============================================================

  Widget _buildLogo() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.only(
        top: Adaptive.h(context, 40),
        bottom: Adaptive.h(context, 32),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(Adaptive.w(context, 16)),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              AppIcons.schoolFill,
              color: colorScheme.primary,
              size: Adaptive.w(context, 48),
            ),
          ),
          SizedBox(height: Adaptive.h(context, 16)),
          Text(
            'VidLang',
            style: TextStyle(
              fontSize: Adaptive.sp(context, 28),
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: Adaptive.h(context, 8)),
          Text(
            '看视频、听英语、读文章、轻松学英语',
            style: TextStyle(
              fontSize: Adaptive.sp(context, 13),
              fontWeight: FontWeight.w400,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthForm() {
    final colorScheme = Theme.of(context).colorScheme;
    final isLogin = _mode == _AuthMode.login;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildEmailField(),
        SizedBox(height: Adaptive.h(context, 14)),
        _buildPasswordField(),
        if (_error != null) ...[SizedBox(height: Adaptive.h(context, 10)), _buildError()],
        SizedBox(height: Adaptive.h(context, 20)),
        _buildPrimaryButton(isLogin ? '登录' : '发送验证码', _submitAuth),
        SizedBox(height: Adaptive.h(context, 10)),
        if (isLogin)
          GestureDetector(
            onTap: () {},
            child: Center(
              child: Text(
                '忘记密码？',
                style: TextStyle(
                  fontSize: Adaptive.sp(context, 13),
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
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
        if (_error != null) ...[SizedBox(height: Adaptive.h(context, 10)), _buildError()],
        SizedBox(height: Adaptive.h(context, 20)),
        _buildPrimaryButton('验证并完成注册', _verifyOtp),
        SizedBox(height: Adaptive.h(context, 10)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _countdownSeconds > 0
                  ? '${_countdownSeconds}s 后可重新发送'
                  : '没收到验证码？',
              style: TextStyle(
                fontSize: Adaptive.sp(context, 13),
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            GestureDetector(
              onTap: _countdownSeconds == 0 && !_loading ? _resendOtp : null,
              child: Text(
                ' 重新发送',
                style: TextStyle(
                  fontSize: Adaptive.sp(context, 13),
                  color: _countdownSeconds == 0
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: Adaptive.h(context, 8)),
        GestureDetector(
          onTap: () => setState(() => _mode = _AuthMode.register),
          child: Center(
            child: Text(
              '返回修改邮箱',
              style: TextStyle(
                fontSize: Adaptive.sp(context, 13),
                color: colorScheme.onSurfaceVariant,
              ),
            ),
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
      style: TextStyle(
        color: colorScheme.onSurface,
        fontSize: Adaptive.sp(context, 15),
      ),
      decoration: _inputDecoration('邮箱地址', AppIcons.email),
      readOnly:
          widget.requireSupabaseReauth &&
          widget.initialEmail != null &&
          widget.initialEmail!.trim().isNotEmpty,
      onSubmitted: (_) => _passwordFocus.requestFocus(),
      contextMenuBuilder: null,
    );
  }

  Widget _buildPasswordField() {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _passwordController,
      focusNode: _passwordFocus,
      obscureText: _obscurePassword,
      textInputAction: _mode == _AuthMode.login
          ? TextInputAction.done
          : TextInputAction.next,
      style: TextStyle(
        color: colorScheme.onSurface,
        fontSize: Adaptive.sp(context, 15),
      ),
      decoration: _inputDecoration('密码', AppIcons.lock).copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? AppIcons.visibilityOff : AppIcons.visibility,
            color: colorScheme.onSurfaceVariant,
            size: Adaptive.sp(context, 20),
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      onSubmitted: _mode == _AuthMode.login ? (_) => _submitAuth() : null,
      contextMenuBuilder: null,
    );
  }

  Widget _buildOtpField() {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _otpController,
      focusNode: _otpFocus,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      style: TextStyle(
        color: colorScheme.onSurface,
        fontSize: Adaptive.sp(context, 22),
        letterSpacing: 8,
        fontWeight: FontWeight.w600,
      ),
      textAlign: TextAlign.center,
      decoration: _inputDecoration('请输入验证码', null).copyWith(
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
      onSubmitted: (_) => _verifyOtp(),
      contextMenuBuilder: null,
    );
  }

  InputDecoration _inputDecoration(String hint, IconData? icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        fontSize: Adaptive.sp(context, 15),
      ),
      prefixIcon: icon != null
          ? Icon(
              icon,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              size: Adaptive.sp(context, 22),
            )
          : null,
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: colorScheme.error, width: 1),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: Adaptive.w(context, 20),
        vertical: Adaptive.h(context, 16),
      ),
    );
  }

  Widget _buildPrimaryButton(String label, VoidCallback onPressed) {
    // ✅ TDesign 规范：使用 TDButton 替换 ElevatedButton，TDLoading 替换 CircularProgressIndicator
    return SizedBox(
      height: Adaptive.h(context, 48),
      child: TDButton(
        text: _loading ? '' : label,
        onTap: _loading ? null : onPressed,
        type: TDButtonType.fill,
        theme: TDButtonTheme.primary,
        style: TDButtonStyle(
          backgroundColor: AppColors.primary,
          textColor: AppColors.onPrimary,
        ),
      ),
    );
  }

  Widget _buildError() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Adaptive.w(context, 10),
        vertical: Adaptive.h(context, 8),
      ),
      decoration: BoxDecoration(
        color: colorScheme.error.withAlpha(25),
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: colorScheme.error.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(
            AppIcons.error,
            color: colorScheme.error,
            size: Adaptive.sp(context, 16),
          ),
          SizedBox(width: Adaptive.w(context, 8)),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                color: colorScheme.error,
                fontSize: Adaptive.sp(context, 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleMode() {
    final colorScheme = Theme.of(context).colorScheme;
    final isLogin = _mode == _AuthMode.login;
    if (_tab == _LoginTab.local) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isLogin ? '没有账号？' : '已有账号？',
          style: TextStyle(
            fontSize: Adaptive.sp(context, 14),
            color: colorScheme.onSurfaceVariant,
          ),
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
            style: TextStyle(
              fontSize: Adaptive.sp(context, 14),
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
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
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.sm),
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
          padding: EdgeInsets.symmetric(vertical: Adaptive.h(context, 10)),
          decoration: BoxDecoration(
            color: isActive ? colorScheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.xs),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.textPrimary.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: Adaptive.sp(context, 14),
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive
                  ? colorScheme.onSurface
                  : colorScheme.onSurfaceVariant,
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
        SizedBox(height: Adaptive.h(context, 14)),
        _buildLocalPasswordField(),
        if (_error != null) ...[SizedBox(height: Adaptive.h(context, 10)), _buildError()],
        SizedBox(height: Adaptive.h(context, 20)),
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
      style: TextStyle(
        color: colorScheme.onSurface,
        fontSize: Adaptive.sp(context, 15),
      ),
      decoration: _inputDecoration('用户名', AppIcons.person),
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
      style: TextStyle(
        color: colorScheme.onSurface,
        fontSize: Adaptive.sp(context, 15),
      ),
      decoration: _inputDecoration('密码', AppIcons.lock).copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            _obscureLocalPassword
                ? AppIcons.visibilityOff
                : AppIcons.visibility,
            color: colorScheme.onSurfaceVariant,
            size: Adaptive.sp(context, 20),
          ),
          onPressed: () =>
              setState(() => _obscureLocalPassword = !_obscureLocalPassword),
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
      await AuthService.instance.signInLocal(
        username: username,
        password: password,
      );
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
          email.trim().toLowerCase() !=
              widget.initialEmail!.trim().toLowerCase()) {
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
            final existingEmail =
                (existing.first.email ?? existing.first.username)
                    .trim()
                    .toLowerCase();
            final inputEmail = email.trim().toLowerCase();
            if (existingEmail.isNotEmpty && existingEmail != inputEmail) {
              final ok = await _confirmSwitchSupabase(
                existingEmail,
                inputEmail,
              );
              if (!ok) return;
            }
          }
        }
        await AuthService.instance.signInWithEmail(
          email: email,
          password: password,
        );
        if (!mounted) return;
        _navigateToMain();
      } else {
        if (widget.requireSupabaseReauth) {
          setState(() => _error = '请先验证主账号后再继续');
          return;
        }
        await AuthService.instance.signUpWithEmail(
          email: email,
          password: password,
        );
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
    final r = await AppConfirmDialog.show(
      context,
      title: '切换主账号',
      content: '已存在主账号：$oldEmail\n即将切换为：$newEmail\n切换后计费体系将以新主账号为准，本地子用户不会删除。',
      confirmText: '继续',
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
      await AuthService.instance.verifySignUpOtp(
        email: _pendingEmail!,
        token: otp,
        password: _pendingPassword,
      );
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
      await AuthService.instance.signUpWithEmail(
        email: _pendingEmail!,
        password: _pendingPassword!,
      );
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
    AppKeysService.loadFromRemote();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainPage()),
      (route) => false,
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email);
  }
}
