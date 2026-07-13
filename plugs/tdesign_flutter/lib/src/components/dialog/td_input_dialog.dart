/*
 * Created by haozhicao@tencent.com on 6/20/22.
 * td_input_dialog.dart
 * 
 */

import 'package:flutter/material.dart';

import '../../../tdesign_flutter.dart';
import '../../util/context_extension.dart';
import '../../util/adaptive_extension.dart';
import 'td_dialog_widget.dart';

/// 带有输入框的弹窗
class TDInputDialog extends StatelessWidget {
  const TDInputDialog({
    Key? key,
    required this.textEditingController,
    this.backgroundColor,
    this.radius = 12.0,
    this.title,
    this.titleColor,
    this.titleAlignment,
    this.contentWidget,
    this.content,
    this.hintText = '',
    this.contentColor,
    this.leftBtn,
    this.rightBtn,
    this.showCloseButton,
    this.padding,
    this.buttonWidget,
    this.customInputWidget,
  })  : assert((title != null || content != null || contentWidget != null)),
        super(key: key);

  /// 背景颜色
  final Color? backgroundColor;

  /// 圆角
  final double radius;

  /// 标题
  final String? title;

  /// 标题颜色
  final Color? titleColor;

  /// 标题对齐模式
  final AlignmentGeometry? titleAlignment;

  /// 内容Widget
  final Widget? contentWidget;

  /// 内容
  final String? content;

  /// 输入提示
  final String? hintText;

  /// 内容颜色
  final Color? contentColor;

  /// 输入controller
  final TextEditingController textEditingController;

  /// 左侧按钮配置
  final TDDialogButtonOptions? leftBtn;

  /// 右侧按钮配置
  final TDDialogButtonOptions? rightBtn;

  /// 显示右上角关闭按钮
  final bool? showCloseButton;

  /// 内容内边距
  final EdgeInsets? padding;

  /// 自定义按钮
  final Widget? buttonWidget;

  /// 自定义输入框
  final Widget? customInputWidget;

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ?? EdgeInsets.fromLTRB(
      context.s(24),
      context.s(32),
      context.s(24),
      0,
    );
    
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: TDDialogScaffold(
          showCloseButton: showCloseButton,
          backgroundColor: backgroundColor,
          radius: radius,
          body: Column(mainAxisSize: MainAxisSize.min, children: [
            TDDialogInfoWidget(
              title: title,
              titleColor: titleColor,
              titleAlignment: titleAlignment,
              contentWidget: contentWidget,
              content: content,
              contentColor: contentColor,
              padding: effectivePadding,
            ),
            customInputWidget != null
                ? customInputWidget!
                : Container(
                    margin: EdgeInsets.fromLTRB(context.s(24), context.s(16), context.s(24), context.s(24)),
                    child: TextField(
                      controller: textEditingController,
                      autofocus: true,
                      decoration: InputDecoration(
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: context.s(16)),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                                TDTheme.of(context).radiusDefault),
                            borderSide: BorderSide.none),
                        hintText: hintText,
                        hintStyle: TextStyle(
                            color: TDTheme.of(context).textColorPlaceholder),
                        fillColor: TDTheme.of(context).bgColorComponent,
                        filled: true,
                      ),
                    ),
                  ),
            _horizontalButtons(context),
          ])),
    );
  }

  Widget _horizontalButtons(BuildContext context) {
    if (buttonWidget != null) {
      return buttonWidget!;
    }
    final buttonHeight = context.s(56);
    final left = leftBtn ??
        TDDialogButtonOptions(
            title: context.resource.cancel,
            titleColor: TDTheme.of(context).textColorPrimary,
            fontWeight: FontWeight.normal,
            action: null,
            height: buttonHeight);
    final right = rightBtn ??
        TDDialogButtonOptions(
            title: context.resource.confirm,
            action: null,
            fontWeight: FontWeight.w600,
            height: buttonHeight);
    return HorizontalTextButtons(
      leftBtn: left,
      rightBtn: right,
    );
  }
}
