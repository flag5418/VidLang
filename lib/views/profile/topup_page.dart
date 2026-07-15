import 'package:flutter/material.dart';
import 'package:vidlang/components/ui/ui_components.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/models/topup_config.dart';
import 'package:vidlang/providers/subscription_provider.dart';
import 'package:vidlang/services/billing/topup_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/views/profile/topup_history_page.dart';
import 'package:vidlang/views/profile/billing_rules_page.dart';

import 'package:vidlang/widgets/app_dialogs.dart';

class TopupPage extends ConsumerStatefulWidget {
  const TopupPage({super.key});

  @override
  ConsumerState<TopupPage> createState() => _TopupPageState();
}

class _TopupPageState extends ConsumerState<TopupPage> {
  int _selectedIndex = -1; // 默认不选中，等数据加载后选中最佳档位
  List<TopupConfig> _options = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  Future<void> _loadConfigs() async {
    final configs = await TopupService.getConfigs();
    if (!mounted) return;
    setState(() {
      _options = configs;
      _isLoading = false;
      // 默认选中实际到账最多的档位（性价比最高）
      if (configs.isNotEmpty) {
        _selectedIndex = _bestValueIndex(configs);
      }
    });
  }

  /// 找出实际到账金额最高的档位（性价比最高）
  int _bestValueIndex(List<TopupConfig> configs) {
    int bestIdx = 0;
    double bestValue = 0;
    for (int i = 0; i < configs.length; i++) {
      final value = configs[i].actualAmount;
      if (value > bestValue) {
        bestValue = value;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  Color _panelColor(ColorScheme colorScheme) {
    return colorScheme.brightness == Brightness.dark
        ? AppColors.surfaceElevated
        : AppColors.lightSurface;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final subState = ref.watch(subscriptionProvider);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          '充值',
          style: TextStyle(fontSize: adaptive.Adaptive.sp(16)),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
        children: [
          // 当前余额
          _buildBalanceCard(colorScheme, subState),
          SizedBox(height: adaptive.Adaptive.h(20)),

          // 充值档位选择
          _buildSectionTitle('选择充值金额', colorScheme),
          SizedBox(height: adaptive.Adaptive.h(12)),

          if (_isLoading)
            ...List.generate(3, (_) => _buildLoadingOption(colorScheme))
          else if (_options.isEmpty)
            _buildEmptyState(colorScheme)
          else
            ...List.generate(_options.length, (index) {
              return _buildTopupOption(colorScheme, index, _options[index]);
            }),

          SizedBox(height: adaptive.Adaptive.h(24)),

          // 确认充值按钮
          if (!_isLoading && _options.isNotEmpty)
            _buildConfirmButton(colorScheme),
          SizedBox(height: adaptive.Adaptive.h(24)),

          // 底部入口
          _buildBottomEntries(colorScheme),
        ],
      ),
    );
  }

  Widget _buildLoadingOption(ColorScheme colorScheme) {
    return Container(
      margin: EdgeInsets.only(bottom: adaptive.Adaptive.h(12)),
      padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(12)),
        color: _panelColor(colorScheme),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 20,
                  decoration: BoxDecoration(
                    color: colorScheme.outline.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      adaptive.Adaptive.r(4),
                    ),
                  ),
                ),
                SizedBox(height: adaptive.Adaptive.h(8)),
                Container(
                  width: 80,
                  height: 14,
                  decoration: BoxDecoration(
                    color: colorScheme.outline.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      adaptive.Adaptive.r(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

Widget _buildEmptyState(ColorScheme colorScheme) {
  return EmptyState(
    icon: AppIcons.error,
    title: '暂无可用充值档位',
  );
}

  Widget _buildBalanceCard(
    ColorScheme colorScheme,
    SubscriptionState subState,
  ) {
    return Container(
      padding: EdgeInsets.all(adaptive.Adaptive.w(20)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(16)),
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '当前余额',
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(14),
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          SizedBox(height: adaptive.Adaptive.h(8)),
          Text(
            '¥${subState.balance.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(32),
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, ColorScheme colorScheme) {
    return Text(
      title,
      style: TextStyle(
        fontSize: adaptive.Adaptive.sp(15),
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
    );
  }

  Widget _buildTopupOption(
    ColorScheme colorScheme,
    int index,
    TopupConfig option,
  ) {
    final isSelected = _selectedIndex == index;
    final hasBonus = option.bonusAmount > 0;
    final displayText = hasBonus
        ? '得 ¥${option.actualAmount.toStringAsFixed(0)}（送 ¥${option.bonusAmount.toStringAsFixed(0)}）'
        : (option.discountLabel ??
              (option.actualAmount != option.originalAmount
                  ? '实付 ¥${option.actualAmount.toStringAsFixed(0)}'
                  : null));

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        margin: EdgeInsets.only(bottom: adaptive.Adaptive.h(12)),
        padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(12)),
          color: _panelColor(colorScheme),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // 金额
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '¥${option.originalAmount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: adaptive.Adaptive.sp(20),
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                        ),
                      ),
                      if (option.label != null) ...[
                        SizedBox(width: adaptive.Adaptive.w(8)),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: adaptive.Adaptive.w(8),
                            vertical: adaptive.Adaptive.h(2),
                          ),
                          decoration: BoxDecoration(
                            color: _labelColor(
                              option.label,
                              colorScheme,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(
                              adaptive.Adaptive.r(4),
                            ),
                          ),
                          child: Text(
                            option.label!,
                            style: TextStyle(
                              fontSize: adaptive.Adaptive.sp(11),
                              color: _labelColor(option.label, colorScheme),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (displayText != null) ...[
                    SizedBox(height: adaptive.Adaptive.h(4)),
                    Text(
                      displayText,
                      style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(12),
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // 选中指示器
            Container(
              width: adaptive.Adaptive.r(20),
              height: adaptive.Adaptive.r(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.outline.withValues(alpha: 0.5),
                  width: 2,
                ),
                color: isSelected ? colorScheme.primary : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(
                      AppIcons.check,
                      size: adaptive.Adaptive.sp(12),
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Color _labelColor(String? label, ColorScheme colorScheme) {
    switch (label) {
      case '热门':
        return AppColors.warning;
      case '最划算':
        return AppColors.success;
      default:
        return colorScheme.primary;
    }
  }

  Widget _buildConfirmButton(ColorScheme colorScheme) {
    final selectedOption = _options[_selectedIndex];
    return SizedBox(
      width: double.infinity,
      height: adaptive.Adaptive.h(48),
      child: FilledButton(
        onPressed: () => _showTopupConfirmDialog(selectedOption, colorScheme),
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              adaptive.Adaptive.r(12),
            ),
          ),
        ),
        child: Text(
          '确认充值 ¥${selectedOption.actualAmount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: adaptive.Adaptive.sp(16),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// 充值确认弹窗 — 使用 AppConfirmDialog (TDesign 规范)
  Future<void> _showTopupConfirmDialog(
    TopupConfig option,
    ColorScheme colorScheme,
  ) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: '确认充值',
      content: '您即将充值以下金额：',
      confirmText: '确认支付',
      cancelText: '取消',
      contentWidget: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: adaptive.Adaptive.h(12)),
          Container(
            padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(
                adaptive.Adaptive.r(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '¥${option.originalAmount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(24),
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
                if (option.bonusAmount > 0) ...[
                  SizedBox(width: adaptive.Adaptive.w(8)),
                  Text(
                    '→ 到账 ¥${option.actualAmount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(14),
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (option.bonusAmount > 0) ...[
            SizedBox(height: adaptive.Adaptive.h(8)),
            Center(
              child: Text(
                '赠送 ¥${option.bonusAmount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: adaptive.Adaptive.sp(13),
                  color: AppColors.success,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    // 用户确认后执行充值
    if (confirmed == true && mounted) {
      // ✅ TDesign 规范：使用 TDToast 替代 SnackBar
      TDToast.showText('充值功能即将上线，敬请期待', context: context);
    }
  }

  Widget _buildBottomEntries(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: _panelColor(colorScheme),
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(12)),
      ),
      child: Column(
        children: [
          _buildEntryItem(
            colorScheme,
            icon: AppIcons.receiptLong,
            title: '充值明细',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TopupHistoryPage()),
              );
            },
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: colorScheme.outline.withValues(alpha: 0.3),
            indent: adaptive.Adaptive.w(48),
          ),
          _buildEntryItem(
            colorScheme,
            icon: AppIcons.rule,
            title: '计费规则',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BillingRulesPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEntryItem(
    ColorScheme colorScheme, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: adaptive.Adaptive.w(16),
          vertical: adaptive.Adaptive.h(14),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: adaptive.Adaptive.sp(20),
              color: colorScheme.onSurfaceVariant,
            ),
            SizedBox(width: adaptive.Adaptive.w(12)),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: adaptive.Adaptive.sp(14),
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            Icon(
              AppIcons.chevronRight,
              size: adaptive.Adaptive.sp(18),
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
