/// 登录页面
///
/// 支持两种设备类型的独立 UI 设计：
/// - iPhone: 单列居中布局
/// - iPad: 左右分屏布局（左侧品牌区 + 右侧表单区）
library;

import 'dart:async';import 'package:vidlang/utils/adaptive.dart' as adaptive;


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
import 'package:vidlang/theme/app_colors.dart';

import 'package:vidlang/widgets/app_dialogs.dart';

enum _AuthMode { login, register, verifyOtp, resetPassword }

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
  final _resetOtpController = TextEditingController();
  final _resetPasswordController = TextEditingController();
  final _resetConfirmPasswordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _otpFocus = FocusNode();
  final _localUsernameFocus = FocusNode();
  final _localPasswordFocus = FocusNode();
  final _resetOtpFocus = FocusNode();
  final _resetPasswordFocus = FocusNode();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureLocalPassword = true;
  bool _obscureResetPassword = true;
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
    _resetOtpController.dispose();
    _resetPasswordController.dispose();
    _resetConfirmPasswordController.dispose();
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
    final cs = context.colors;

    if (_isIpad) {
      return _buildIpadLayout(cs);
    }
    return _buildIphoneLayout(cs);
  }

  // ============================================================
  // iPhone 布局 - 单列居中
  // ============================================================

  Widget _buildIphoneLayout(AppColorsData cs) {
    return Scaffold(
      backgroundColor: cs.surface,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: adaptive.Adaptive.w(context, 16),
            vertical: adaptive.Adaptive.h(context, 20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildLogo(),
              SizedBox(height: adaptive.Adaptive.h(context, 32)),
              if (!widget.requireSupabaseReauth) _buildTabSwitcher(),
              SizedBox(height: adaptive.Adaptive.h(context, 14)),
              if (_mode == _AuthMode.verifyOtp)
                _buildOtpForm()
              else if (_tab == _LoginTab.local)
                _buildLocalForm()
              else
                _buildAuthForm(),
              SizedBox(height: adaptive.Adaptive.h(context, 20)),
              if (!widget.requireSupabaseReauth && _mode != _AuthMode.verifyOtp)
                _buildToggleMode(),
              SizedBox(height: adaptive.Adaptive.h(context, 20)),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // iPad 布局 - 左右分屏
  // ============================================================

  Widget _buildIpadLayout(AppColorsData cs) {
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 左侧品牌区（沉浸式深蓝背景）
          Expanded(flex: 4, child: _buildBrandPanel(cs)),
          // 右侧表单区（白色背景，内容居中）
          Expanded(flex: 6, child: _buildIpadFormPanel(cs)),
        ],
      ),
    );
  }

  Widget _buildBrandPanel(AppColorsData cs) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF), Color(0xFF2563EB)],
        ),
      ),
      child: Stack(
        children: [
          // 装饰性圆点
          Positioned(
            top: adaptive.Adaptive.w(context, 50),
            right: adaptive.Adaptive.w(context, 30),
            child: Container(
              width: adaptive.Adaptive.w(context, 100),
              height: adaptive.Adaptive.w(context, 100),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: adaptive.Adaptive.w(context, 80),
            left: -adaptive.Adaptive.w(context, 24),
            child: Container(
              width: adaptive.Adaptive.w(context, 150),
              height: adaptive.Adaptive.w(context, 150),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.4,
            right: -adaptive.Adaptive.w(context, 50),
            child: Container(
              width: adaptive.Adaptive.w(context, 200),
              height: adaptive.Adaptive.w(context, 200),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.03),
              ),
            ),
          ),
          // 品牌内容
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: adaptive.Adaptive.w(context, 32),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    padding: EdgeInsets.all(adaptive.Adaptive.w(context, 18)),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      AppIcons.schoolFill,
                      color: Colors.white,
                      size: adaptive.Adaptive.w(context, 44),
                    ),
                  ),
                  SizedBox(height: adaptive.Adaptive.h(context, 24)),
                  // 品牌名
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'VidLang',
                      style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(context, 34),
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  SizedBox(height: adaptive.Adaptive.h(context, 14)),
                  // 分割线
                  Container(
                    width: adaptive.Adaptive.w(context, 36),
                    height: adaptive.Adaptive.h(context, 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(
                        adaptive.Adaptive.r(context, 2),
                      ),
                    ),
                  ),
                  SizedBox(height: adaptive.Adaptive.h(context, 18)),
                  // 标语
                  Text(
                    '看视频、听英语、读文章',
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(context, 15),
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.9),
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: adaptive.Adaptive.h(context, 5)),
                  Text(
                    '轻松学英语',
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(context, 15),
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

  Widget _buildIpadFormPanel(AppColorsData cs) {
    return Container(
      color: cs.surface,
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(vertical: adaptive.Adaptive.h(context, 36)),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: adaptive.Adaptive.w(context, 380)),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: adaptive.Adaptive.w(context, 24),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 欢迎标题
                  Text(
                    '欢迎回来',
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(context, 22),
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  SizedBox(height: adaptive.Adaptive.h(context, 6)),
                  Text(
                    '登录以继续使用 VidLang',
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(context, 13),
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: adaptive.Adaptive.h(context, 28)),
                  if (!widget.requireSupabaseReauth) _buildTabSwitcher(),
                  if (!widget.requireSupabaseReauth)
                    SizedBox(height: adaptive.Adaptive.h(context, 20)),
                  if (_mode == _AuthMode.verifyOtp)
                    _buildOtpForm()
                  else if (_mode == _AuthMode.resetPassword)
                    _buildResetPasswordForm()
                  else if (_tab == _LoginTab.local)
                    _buildLocalForm()
                  else
                    _buildAuthForm(),
                  SizedBox(height: adaptive.Adaptive.h(context, 20)),
                  if (!widget.requireSupabaseReauth &&
                      _mode != _AuthMode.verifyOtp &&
                      _mode != _AuthMode.resetPassword)
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
    final cs = context.colors;
    return Container(
      padding: EdgeInsets.only(
        top: adaptive.Adaptive.h(context, 40),
        bottom: adaptive.Adaptive.h(context, 32),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(adaptive.Adaptive.w(context, 16)),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              AppIcons.schoolFill,
              color: cs.primary,
              size: adaptive.Adaptive.w(context, 48),
            ),
          ),
          SizedBox(height: adaptive.Adaptive.h(context, 16)),
          Text(
            'VidLang',
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(context, 28),
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: adaptive.Adaptive.h(context, 8)),
          Text(
            '看视频、听英语、读文章、轻松学英语',
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(context, 13),
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthForm() {
    final cs = context.colors;
    final isLogin = _mode == _AuthMode.login;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildEmailField(),
        SizedBox(height: adaptive.Adaptive.h(context, 14)),
        _buildPasswordField(),
        if (_error != null) ...[
          SizedBox(height: adaptive.Adaptive.h(context, 10)),
          _buildError(),
        ],
        SizedBox(height: adaptive.Adaptive.h(context, 20)),
        _buildPrimaryButton(isLogin ? '登录' : '发送验证码', _submitAuth),
        SizedBox(height: adaptive.Adaptive.h(context, 10)),
        if (isLogin)
          GestureDetector(
            onTap: _handleForgotSupabasePassword,
            child: Center(
              child: Text(
                '忘记密码？',
                style: TextStyle(
                  fontSize: adaptive.Adaptive.sp(context, 13),
                  color: cs.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOtpForm() {
    final cs = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildOtpField(),
        if (_error != null) ...[
          SizedBox(height: adaptive.Adaptive.h(context, 10)),
          _buildError(),
        ],
        SizedBox(height: adaptive.Adaptive.h(context, 20)),
        _buildPrimaryButton('验证并完成注册', _verifyOtp),
        SizedBox(height: adaptive.Adaptive.h(context, 10)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _countdownSeconds > 0
                  ? '${_countdownSeconds}s 后可重新发送'
                  : '没收到验证码？',
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(context, 13),
                color: cs.onSurfaceVariant,
              ),
            ),
            GestureDetector(
              onTap: _countdownSeconds == 0 && !_loading ? _resendOtp : null,
              child: Text(
                ' 重新发送',
                style: TextStyle(
                  fontSize: adaptive.Adaptive.sp(context, 13),
                  color: _countdownSeconds == 0
                      ? cs.primary
                      : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: adaptive.Adaptive.h(context, 8)),
        GestureDetector(
          onTap: () => setState(() => _mode = _AuthMode.register),
          child: Center(
            child: Text(
              '返回修改邮箱',
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(context, 13),
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== 重置密码表单（OTP 模式） ====================

  Widget _buildResetPasswordForm() {
    final cs = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 邮箱提示
        Container(
          padding: EdgeInsets.all(adaptive.Adaptive.w(context, 12)),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          child: Text(
            '验证码已发送至：$_pendingEmail\n请在邮箱中查找来自 Supabase 的验证码',
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(context, 13),
              color: cs.primary,
            ),
          ),
        ),
        SizedBox(height: adaptive.Adaptive.h(context, 16)),

        // OTP 验证码输入框
        _buildResetOtpField(),
        if (_error != null) ...[
          SizedBox(height: adaptive.Adaptive.h(context, 10)),
          _buildError(),
        ],

        // 新密码输入框
        SizedBox(height: adaptive.Adaptive.h(context, 14)),
        _buildNewPasswordField(),

        // 确认新密码输入框
        SizedBox(height: adaptive.Adaptive.h(context, 14)),
        _buildConfirmNewPasswordField(),

        // 提交按钮
        SizedBox(height: adaptive.Adaptive.h(context, 20)),
        _buildPrimaryButton('重置密码', _submitResetPassword),

        // 倒计时 + 重发
        SizedBox(height: adaptive.Adaptive.h(context, 10)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _countdownSeconds > 0
                  ? '${_countdownSeconds}s 后可重新发送'
                  : '没收到验证码？',
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(context, 13),
                color: cs.onSurfaceVariant,
              ),
            ),
            GestureDetector(
              onTap: _countdownSeconds == 0 && !_loading ? _resendResetOtp : null,
              child: Text(
                ' 重新发送',
                style: TextStyle(
                  fontSize: adaptive.Adaptive.sp(context, 13),
                  color: _countdownSeconds == 0
                      ? cs.primary
                      : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),

        // 返回登录
        SizedBox(height: adaptive.Adaptive.h(context, 8)),
        GestureDetector(
          onTap: () => setState(() {
            _mode = _AuthMode.login;
            _resetOtpController.clear();
            _resetPasswordController.clear();
            _resetConfirmPasswordController.clear();
            _error = null;
            _countdownTimer?.cancel();
            _countdownSeconds = 0;
          }),
          child: Center(
            child: Text(
              '返回登录',
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(context, 13),
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 重置密码的 OTP 输入框（6位数字）
  Widget _buildResetOtpField() {
    final cs = context.colors;
    return TextField(
      controller: _resetOtpController,
      focusNode: _resetOtpFocus,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      style: TextStyle(
        color: cs.onSurface,
        fontSize: adaptive.Adaptive.sp(context, 22),
        letterSpacing: 8,
        fontWeight: FontWeight.w600,
      ),
      textAlign: TextAlign.center,
      decoration: _inputDecoration('请输入验证码', null).copyWith(
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
      onSubmitted: (_) => _resetPasswordFocus.requestFocus(),
      contextMenuBuilder: null,
    );
  }

  /// 新密码输入框
  Widget _buildNewPasswordField() {
    final cs = context.colors;
    return TextField(
      controller: _resetPasswordController,
      focusNode: _resetPasswordFocus,
      obscureText: _obscureResetPassword,
      textInputAction: TextInputAction.next,
      style: TextStyle(
        color: cs.onSurface,
        fontSize: adaptive.Adaptive.sp(context, 15),
      ),
      decoration: _inputDecoration('新密码', AppIcons.lock).copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            _obscureResetPassword ? AppIcons.visibilityOff : AppIcons.visibility,
            color: cs.onSurfaceVariant,
            size: adaptive.Adaptive.sp(context, 20),
          ),
          onPressed: () => setState(() => _obscureResetPassword = !_obscureResetPassword),
        ),
      ),
      contextMenuBuilder: null,
    );
  }

  /// 确认新密码输入框
  Widget _buildConfirmNewPasswordField() {
    final cs = context.colors;
    return TextField(
      controller: _resetConfirmPasswordController,
      obscureText: _obscureResetPassword,
      textInputAction: TextInputAction.done,
      style: TextStyle(
        color: cs.onSurface,
        fontSize: adaptive.Adaptive.sp(context, 15),
      ),
      decoration: _inputDecoration('确认新密码', AppIcons.lock),
      onSubmitted: (_) => _submitResetPassword(),
      contextMenuBuilder: null,
    );
  }

  Widget _buildEmailField() {
    final cs = context.colors;
    return TextField(
      controller: _emailController,
      focusNode: _emailFocus,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      style: TextStyle(
        color: cs.onSurface,
        fontSize: adaptive.Adaptive.sp(context, 15),
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
    final cs = context.colors;
    return TextField(
      controller: _passwordController,
      focusNode: _passwordFocus,
      obscureText: _obscurePassword,
      textInputAction: _mode == _AuthMode.login
          ? TextInputAction.done
          : TextInputAction.next,
      style: TextStyle(
        color: cs.onSurface,
        fontSize: adaptive.Adaptive.sp(context, 15),
      ),
      decoration: _inputDecoration('密码', AppIcons.lock).copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? AppIcons.visibilityOff : AppIcons.visibility,
            color: cs.onSurfaceVariant,
            size: adaptive.Adaptive.sp(context, 20),
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      onSubmitted: _mode == _AuthMode.login ? (_) => _submitAuth() : null,
      contextMenuBuilder: null,
    );
  }

  Widget _buildOtpField() {
    final cs = context.colors;
    return TextField(
      controller: _otpController,
      focusNode: _otpFocus,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      style: TextStyle(
        color: cs.onSurface,
        fontSize: adaptive.Adaptive.sp(context, 22),
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
    final cs = context.colors;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
        fontSize: adaptive.Adaptive.sp(context, 15),
      ),
      prefixIcon: icon != null
          ? Icon(
              icon,
              color: cs.onSurfaceVariant.withValues(alpha: 0.8),
              size: adaptive.Adaptive.sp(context, 22),
            )
          : null,
      filled: true,
      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
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
        borderSide: BorderSide(color: cs.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: cs.error, width: 1),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: adaptive.Adaptive.w(context, 20),
        vertical: adaptive.Adaptive.h(context, 16),
      ),
    );
  }

  Widget _buildPrimaryButton(String label, VoidCallback onPressed) {
    // ✅ TDesign 规范：使用 TDButton 替换 ElevatedButton，TDLoading 替换 CircularProgressIndicator
    return SizedBox(
      height: adaptive.Adaptive.h(context, 48),
      child: TDButton(
        text: _loading ? '' : label,
        onTap: _loading ? null : onPressed,
        type: TDButtonType.fill,
        theme: TDButtonTheme.primary,
        textStyle: TextStyle(
          fontSize: adaptive.Adaptive.sp(context, AppTypography.fontSizeBase),
          fontWeight: AppTypography.fontWeightSemiBold,
        ),
        style: TDButtonStyle(
          backgroundColor: AppColors.primary,
          textColor: AppColors.onPrimary,
        ),
      ),
    );
  }

  Widget _buildError() {
    final cs = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: adaptive.Adaptive.w(context, 10),
        vertical: adaptive.Adaptive.h(context, 8),
      ),
      decoration: BoxDecoration(
        color: cs.error.withAlpha(25),
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: cs.error.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(
            AppIcons.error,
            color: cs.error,
            size: adaptive.Adaptive.sp(context, 16),
          ),
          SizedBox(width: adaptive.Adaptive.w(context, 8)),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                color: cs.error,
                fontSize: adaptive.Adaptive.sp(context, 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleMode() {
    final cs = context.colors;
    final isLogin = _mode == _AuthMode.login;
    if (_tab == _LoginTab.local) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isLogin ? '没有账号？' : '已有账号？',
          style: TextStyle(
            fontSize: adaptive.Adaptive.sp(context, 14),
            color: cs.onSurfaceVariant,
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
              fontSize: adaptive.Adaptive.sp(context, 14),
              color: cs.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ==================== Tab 切换 ====================

  Widget _buildTabSwitcher() {
    final cs = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      padding: EdgeInsets.all(adaptive.Adaptive.w(context, 4)),
      child: Row(
        children: [
          _tabButton('账号登录', _LoginTab.supabase),
          _tabButton('本地登录', _LoginTab.local),
        ],
      ),
    );
  }

  Widget _tabButton(String label, _LoginTab tab) {
    final cs = context.colors;
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
          padding: EdgeInsets.symmetric(vertical: adaptive.Adaptive.h(context, 10)),
          decoration: BoxDecoration(
            color: isActive ? cs.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.xs),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.textPrimary.withValues(alpha: 0.05),
                      blurRadius: adaptive.Adaptive.w(context, 4),
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(context, 14),
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive
                  ? cs.onSurface
                  : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 本地用户登录表单 ====================

  Widget _buildLocalForm() {
    final cs = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLocalUsernameField(),
        SizedBox(height: adaptive.Adaptive.h(context, 14)),
        _buildLocalPasswordField(),
        if (_error != null) ...[
          SizedBox(height: adaptive.Adaptive.h(context, 10)),
          _buildError(),
        ],
        SizedBox(height: adaptive.Adaptive.h(context, 20)),
        _buildPrimaryButton('登录', _submitLocalLogin),
        SizedBox(height: adaptive.Adaptive.h(context, 10)),
        GestureDetector(
          onTap: _handleForgotLocalPassword,
          child: Center(
            child: Text(
              '忘记密码？',
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(context, 13),
                color: cs.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocalUsernameField() {
    final cs = context.colors;
    return TextField(
      controller: _localUsernameController,
      focusNode: _localUsernameFocus,
      textInputAction: TextInputAction.next,
      style: TextStyle(
        color: cs.onSurface,
        fontSize: adaptive.Adaptive.sp(context, 15),
      ),
      decoration: _inputDecoration('用户名', AppIcons.person),
      onSubmitted: (_) => _localPasswordFocus.requestFocus(),
    );
  }

  Widget _buildLocalPasswordField() {
    final cs = context.colors;
    return TextField(
      controller: _localPasswordController,
      focusNode: _localPasswordFocus,
      obscureText: _obscureLocalPassword,
      textInputAction: TextInputAction.done,
      style: TextStyle(
        color: cs.onSurface,
        fontSize: adaptive.Adaptive.sp(context, 15),
      ),
      decoration: _inputDecoration('密码', AppIcons.lock).copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            _obscureLocalPassword
                ? AppIcons.visibilityOff
                : AppIcons.visibility,
            color: cs.onSurfaceVariant,
            size: adaptive.Adaptive.sp(context, 20),
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

  // ==================== 忘记密码（OTP 模式） ====================

  /// Supabase 账号忘记密码 → 输入邮箱 → 发送 OTP → App 内重置
  ///
  /// 整个流程无需网页跳转，不依赖域名配置：
  /// 1. 用户输入注册邮箱
  /// 2. 调用 sendResetOtp() 发送 OTP 到邮箱
  /// 3. 切换到 resetPassword 模式，用户输入验证码 + 新密码
  /// 4. 验证 OTP → 更新密码 → 完成
  Future<void> _handleForgotSupabasePassword() async {
    final result = await AppInputDialog.show(
      context,
      title: '重置密码',
      hintText: '请输入注册邮箱',
      confirmText: '发送验证码',
      validator: (value) {
        if (value == null || value.trim().isEmpty) return '请输入邮箱地址';
        if (!_isValidEmail(value.trim())) return '请输入正确的邮箱格式';
        return null;
      },
    );

    if (result == null || result.toString().trim().isEmpty) return;
    if (!mounted) return;

    final email = result.toString().trim();
    _pendingEmail = email;

    // 发送 OTP
    setState(() => _loading = true);
    try {
      await AuthService.instance.sendResetOtp(email: email);
      if (!mounted) return;

      // 切换到重置密码表单
      _resetOtpController.clear();
      _resetPasswordController.clear();
      _resetConfirmPasswordController.clear();
      _startCountdown();
      setState(() {
        _mode = _AuthMode.resetPassword;
        _error = null;
        _loading = false;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 提交重置密码：验证 OTP → 更新密码 → 返回登录
  Future<void> _submitResetPassword() async {
    final otp = _resetOtpController.text.trim();
    final newPassword = _resetPasswordController.text.trim();
    final confirmPassword = _resetConfirmPasswordController.text.trim();

    // 校验
    if (otp.isEmpty) { setState(() => _error = '请输入验证码'); return; }
    if (newPassword.isEmpty) { setState(() => _error = '请输入新密码'); return; }
    if (confirmPassword.isEmpty) { setState(() => _error = '请确认新密码'); return; }
    if (newPassword != confirmPassword) { setState(() => _error = '两次密码输入不一致'); return; }
    if (newPassword.length < 6) { setState(() => _error = '密码至少需要6位'); return; }

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      // 步骤1: 验证 OTP
      await AuthService.instance.verifyResetOtp(
        email: _pendingEmail!,
        token: otp,
      );
      if (!mounted) return;

      // 步骤2: 更新密码
      await AuthService.instance.updateResetPassword(newPassword: newPassword);
      if (!mounted) return;

      // 步骤3: 密码已更新成功
      AppToast.show(context, '密码重置成功！请使用新密码登录');
      if (!mounted) return;

      // 返回登录页，自动填入邮箱
      setState(() {
        _mode = _AuthMode.login;
        _emailController.text = _pendingEmail!;
        _passwordController.clear();
        _pendingEmail = null;
        _loading = false;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 重发重置密码 OTP
  Future<void> _resendResetOtp() async {
    if (_pendingEmail == null) return;
    setState(() => _loading = true);
    try {
      await AuthService.instance.sendResetOtp(email: _pendingEmail!);
      if (!mounted) return;
      _startCountdown();
      _resetOtpController.clear();
      setState(() {
        _error = null;
        _loading = false;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 本地账号忘记密码 → 提示联系管理员
  Future<void> _handleForgotLocalPassword() async {
    final username = _localUsernameController.text.trim();

    if (username.isEmpty) {
      AppToast.show(context, '请先输入用户名');
      return;
    }

    setState(() => _loading = true);
    try {
      final user = await AuthService.instance.lookupLocalUser(
        username: username,
      );
      if (!mounted) return;

      if (user == null) {
        AppToast.show(context, '用户名不存在');
        return;
      }

      // 本地账号无法自动重置，需要管理员介入
      final nickname = user.nickname.isNotEmpty ? user.nickname : username;
      await AppAlertDialog.show(
        context,
        title: '无法自动重置',
        content: '本地账号「$nickname」的密码无法通过邮件重置。\n\n请联系管理员在「个人中心 → 用户管理」中为您重置密码。',
        buttonText: '我知道了',
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.message);
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
