import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vidlang/providers/subscription_provider.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/views/profile/topup_history_page.dart';
import 'package:vidlang/views/profile/billing_rules_page.dart';

/// 充值档位配置
class TopupOption {
  final double amount;
  final double actualAmount;
  final String? label;
  final String? discountLabel;

  const TopupOption({
    required this.amount,
    required this.actualAmount,
    this.label,
    this.discountLabel,
  });
}

class TopupPage extends ConsumerStatefulWidget {
  const TopupPage({super.key});

  @override
  ConsumerState<TopupPage> createState() => _TopupPageState();
}

class _TopupPageState extends ConsumerState<TopupPage> {
  int _selectedIndex = 1; // 默认选中 ¥50（热门）

  // 充值档位配置（后续可从配置表读取）
  final List<TopupOption> _options = const [
    TopupOption(amount: 10, actualAmount: 10, label: '体验'),
    TopupOption(amount: 50, actualAmount: 50, label: '热门'),
    TopupOption(amount: 100, actualAmount: 95, label: '最划算', discountLabel: '打 9.5 折'),
  ];

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
        title: Text('充值', style: TextStyle(fontSize: 16.sp)),
      ),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          // 当前余额
          _buildBalanceCard(colorScheme, subState),
          SizedBox(height: 20.h),

          // 充值档位选择
          _buildSectionTitle('选择充值金额', colorScheme),
          SizedBox(height: 12.h),
          ...List.generate(_options.length, (index) {
            return _buildTopupOption(colorScheme, index, _options[index]);
          }),
          SizedBox(height: 24.h),

          // 确认充值按钮
          _buildConfirmButton(colorScheme),
          SizedBox(height: 24.h),

          // 底部入口
          _buildBottomEntries(colorScheme),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(ColorScheme colorScheme, SubscriptionState subState) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
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
              fontSize: 14.sp,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '¥${subState.balance.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 32.sp,
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
        fontSize: 15.sp,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
    );
  }

  Widget _buildTopupOption(ColorScheme colorScheme, int index, TopupOption option) {
    final isSelected = _selectedIndex == index;
    final displayAmount = option.actualAmount < option.amount
        ? '实付 ¥${option.actualAmount.toStringAsFixed(0)}'
        : null;

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
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
                        '¥${option.amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                        ),
                      ),
                      if (option.label != null) ...[
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: option.label == '热门'
                                ? Colors.orange.withValues(alpha: 0.15)
                                : option.label == '最划算'
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            option.label!,
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: option.label == '热门'
                                  ? Colors.orange
                                  : option.label == '最划算'
                                      ? Colors.green
                                      : colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (displayAmount != null || option.discountLabel != null) ...[
                    SizedBox(height: 4.h),
                    Text(
                      displayAmount ?? option.discountLabel ?? '',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // 选中指示器
            Container(
              width: 20.r,
              height: 20.r,
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
                  ? Icon(Icons.check, size: 12.sp, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmButton(ColorScheme colorScheme) {
    final selectedOption = _options[_selectedIndex];
    return SizedBox(
      width: double.infinity,
      height: 48.h,
      child: FilledButton(
        onPressed: () {
          // TODO: 后续对接 IAP 支付
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('充值功能即将上线，敬请期待'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        child: Text(
          '确认充值 ¥${selectedOption.actualAmount.toStringAsFixed(0)}',
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildBottomEntries(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: _panelColor(colorScheme),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          _buildEntryItem(
            colorScheme,
            icon: Icons.receipt_long_outlined,
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
            indent: 48.w,
          ),
          _buildEntryItem(
            colorScheme,
            icon: Icons.rule_outlined,
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
          horizontal: 16.w,
          vertical: 14.h,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20.sp, color: colorScheme.onSurfaceVariant),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18.sp,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
