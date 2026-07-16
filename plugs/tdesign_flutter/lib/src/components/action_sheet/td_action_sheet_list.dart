import 'package:flutter/material.dart';
import '../../theme/td_colors.dart';
import '../../theme/td_fonts.dart';
import '../../theme/td_radius.dart';
import '../../theme/td_spacers.dart';
import '../../theme/td_theme.dart';
import '../../util/context_extension.dart';
import '../../util/adaptive_extension.dart';
import '../badge/td_badge.dart';
import '../text/td_text.dart';
import 'td_action_sheet.dart';
import 'td_action_sheet_item_widget.dart';

class TDActionSheetList extends StatelessWidget {
  final List<TDActionSheetItem> items;
  final TDActionSheetAlign align;
  final String? cancelText;
  final String? description;
  final bool showCancel;
  final VoidCallback? onCancel;
  final TDActionSheetItemCallback? onSelected;
  final bool useSafeArea;

  const TDActionSheetList({
    super.key,
    required this.items,
    this.align = TDActionSheetAlign.center,
    this.cancelText,
    this.description,
    this.showCancel = true,
    this.onCancel,
    this.onSelected,
    this.useSafeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = Radius.circular(TDTheme.of(context).radiusExtraLarge);
    // iPad 下限制最大宽度，保持合适的视觉比例
    final maxWidth = isIPad() ? Adaptive.w(540) : double.infinity;
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.only(topLeft: borderRadius, topRight: borderRadius),
        color: TDTheme.of(context).bgColorPage,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (description != null) _buildDescription(context),
          _buildOptionsList(context),
          if (showCancel) _buildCancelButton(context),
        ],
      ),
    );
  }

  /// 构建描述文本
  Widget _buildDescription(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: Adaptive.w(TDTheme.of(context).spacer16),
        vertical: Adaptive.h(TDTheme.of(context).spacer12),
      ),
      decoration: BoxDecoration(
        color: TDTheme.of(context).bgColorContainer,
        border: Border(
          bottom: BorderSide(
            color: TDTheme.of(context).componentStrokeColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: getMainAxisAlignment(align),
        children: [
          TDText(
            description!,
            font: TDTheme.of(context).fontBodyMedium,
            textColor: TDTheme.of(context).textColorSecondary,
          ),
        ],
      ),
    );
  }

  /// 构建选项列表
  Widget _buildOptionsList(BuildContext context) {
    // 自适应行高：无描述 56pt / 有描述 78pt
    final singleLineHeight = Adaptive.h(56);
    final doubleLineHeight = Adaptive.h(78);
    final horizontalPadding = Adaptive.w(TDTheme.of(context).spacer16);
    final iconGap = Adaptive.w(TDTheme.of(context).spacer8);
    final descGap = Adaptive.h(TDTheme.of(context).spacer4);
    final badgeGap = Adaptive.w(TDTheme.of(context).spacer8);
    // 默认图标大小 24pt，iPad 下自适应
    final defaultIconSize = Adaptive.icon(24);

    return Container(
      color: TDTheme.of(context).bgColorContainer,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        padding: EdgeInsets.zero,
        itemBuilder: (context, index) {
          final item = items[index];
          final hasDesc = item.description != null && item.description!.isNotEmpty;
          return GestureDetector(
            onTap: item.disabled
                ? null
                : () {
                    onSelected?.call(item, index);
                    Navigator.maybePop(context);
                  },
            child: Container(
              height: hasDesc ? doubleLineHeight : singleLineHeight,
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: TDTheme.of(context).componentStrokeColor,
                    width: 0.5,
                  ),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: getMainAxisAlignment(align),
                    children: [
                      if (item.icon != null) ...[
                        IconTheme(
                          data: IconThemeData(
                            color: item.disabled
                                ? TDTheme.of(context).textDisabledColor
                                : (item.textStyle?.color ??
                                    TDTheme.of(context).textColorPrimary),
                            size: item.textStyle?.fontSize ?? defaultIconSize,
                          ),
                          child: SizedBox(
                            width: item.iconSize ?? defaultIconSize,
                            height: item.iconSize ?? defaultIconSize,
                            child: item.icon!,
                          ),
                        ),
                        SizedBox(width: iconGap),
                      ],
                      TDText(
                        item.label,
                        font: TDTheme.of(context).fontBodyLarge,
                        textColor: item.disabled
                            ? TDTheme.of(context).textDisabledColor
                            : TDTheme.of(context).textColorPrimary,
                        style: item.textStyle,
                      ),
                      if (item.badge != null) ...[
                        SizedBox(width: badgeGap),
                        item.badge!,
                      ],
                    ],
                  ),
                  if (hasDesc) ...[
                    SizedBox(height: descGap),
                    Row(
                      mainAxisAlignment: getMainAxisAlignment(align),
                      children: [
                        Flexible(
                          child: TDText(
                            item.description!,
                            font: TDTheme.of(context).fontBodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textColor: TDTheme.of(context).textDisabledColor,
                          ),
                        ),
                      ],
                    ),
                  ]
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 构建取消按钮
  Widget _buildCancelButton(BuildContext context) {
    final cancelHeight = Adaptive.h(48);
    final cancelTopMargin = Adaptive.h(TDTheme.of(context).spacer8);

    return GestureDetector(
        onTap: () {
          onCancel?.call();
          Navigator.maybePop(context);
        },
        child: Column(
          children: [
            Container(
              color: TDTheme.of(context).bgColorContainer,
              height: cancelHeight,
              margin: EdgeInsets.only(top: cancelTopMargin),
              child: Center(
                child: TDText(
                  cancelText ?? context.resource.cancel,
                  font: TDTheme.of(context).fontBodyLarge,
                  textColor: TDTheme.of(context).textColorPrimary,
                ),
              ),
            ),
            useSafeArea
                ? Container(
                    color: TDTheme.of(context).bgColorContainer,
                    height: MediaQuery.of(context).padding.bottom,
                  )
                : const SizedBox.shrink(),
          ],
        ));
  }
}
