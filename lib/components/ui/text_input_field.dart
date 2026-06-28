import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

/// 文本输入框组件
/// 
/// 基于 Pencil UI Design Skill 的输入框规范：
/// - 白色背景
/// - 12px 圆角
/// - 边框颜色: #E4E4E7（默认）、#4ADE80（聚焦）
/// - 占位符颜色: #9CA3AF（textTertiary）
/// - Focus 状态: 边框变为 2px 主色调
class TextInputField extends StatefulWidget {
  /// 标签文字
  final String? label;
  
  /// 提示文字
  final String? hint;
  
  /// 控制器
  final TextEditingController? controller;
  
  /// 是否密码输入
  final bool obscureText;
  
  /// 前缀图标
  final IconData? prefixIcon;
  
  /// 后缀图标
  final IconData? suffixIcon;
  
  /// 后缀图标点击事件
  final VoidCallback? onSuffixTap;
  
  /// 最大行数
  final int maxLines;
  
  /// 输入变化回调
  final ValueChanged<String>? onChanged;
  
  /// 提交回调
  final ValueChanged<String>? onSubmitted;
  
  /// 验证器
  final FormFieldValidator<String>? validator;
  
  /// 初始值
  final String? initialValue;
  
  /// 是否只读
  final bool readOnly;

  const TextInputField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.initialValue,
    this.readOnly = false,
  });

  @override
  State<TextInputField> createState() => _TextInputFieldState();
}

class _TextInputFieldState extends State<TextInputField> {
  bool _isFocused = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 标签
        if (widget.label != null)
          Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              widget.label!,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        
        // 输入框
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          obscureText: widget.obscureText,
          maxLines: widget.maxLines,
          readOnly: widget.readOnly,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          style: TextStyle(
            fontSize: 16.sp,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(
              fontSize: 16.sp,
              color: AppColors.textTertiary,
            ),
            prefixIcon: widget.prefixIcon != null
              ? Icon(widget.prefixIcon, size: 22.w, color: AppColors.textTertiary)
              : null,
            suffixIcon: widget.suffixIcon != null
              ? IconButton(
                  icon: Icon(widget.suffixIcon, size: 22.w, color: AppColors.textTertiary),
                  onPressed: widget.onSuffixTap,
                )
              : null,
            
            // Pencil Skill: 背景和边框样式
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            
            // 默认边框
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide(color: AppColors.borderLight),
            ),
            
            // Focus 状态：主色调边框，2px 宽度
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide(
                color: AppColors.primaryBrand,
                width: 2.0, // Pencil Skill: focus 时加粗边框
              ),
            ),
            
            // 错误状态
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide(color: AppColors.error),
            ),
            
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide(color: AppColors.error, width: 2),
            ),
            
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppSpacing.inputPadding.w,
              vertical: (widget.maxLines > 1 ? AppSpacing.md : AppSpacing.inputPadding).h,
            ),
          ),
          // 键盘类型优化
          textInputAction: widget.maxLines == 1 ? TextInputAction.next : TextInputAction.newline,
          
          // 输入格式化（可选）
          inputFormatters: _getInputFormatters(),
        ),
      ],
    );
  }

  List<TextInputFormatter>? _getInputFormatters() {
    // 可以根据需要添加输入格式化器
    return null;
  }
}
