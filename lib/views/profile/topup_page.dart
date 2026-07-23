import 'package:flutter/material.dart';
import 'dart:async';

import 'package:vidlang/components/ui/ui_components.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:vidlang/models/topup_config.dart';
import 'package:vidlang/providers/subscription_provider.dart';
import 'package:vidlang/services/billing/topup_service.dart';
import 'package:vidlang/services/billing/iap_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/views/profile/topup_history_page.dart';
import 'package:vidlang/views/profile/billing_page.dart';

import 'package:vidlang/components/dialogs/app_dialogs.dart';

class TopupPage extends ConsumerStatefulWidget {
  const TopupPage({super.key});

  @override
  ConsumerState<TopupPage> createState() => _TopupPageState();
}

class _TopupPageState extends ConsumerState<TopupPage> {
  int _selectedIndex = -1;
  List<TopupConfig> _options = [];
  bool _isLoading = true;
  bool _agreedToTerms = true;

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
      if (configs.isNotEmpty) {
        _selectedIndex = _bestValueIndex(configs);
      }
    });
  }

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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final subState = ref.watch(subscriptionProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildAppBar(colorScheme),
              _buildBalanceCard(colorScheme, subState),
              _buildTopupSection(colorScheme),
              _buildTermsSection(colorScheme),
              SliverToBoxAdapter(
                child: SizedBox(height: adaptive.Adaptive.h(140)),
              ),
            ],
          ),
          if (!_isLoading && _options.isNotEmpty)
            _buildFixedBottomArea(colorScheme),
        ],
      ),
    );
  }

  // ============================================================
  // 顶部导航栏
  // ============================================================
  SliverToBoxAdapter _buildAppBar(ColorScheme colorScheme) {
    return SliverToBoxAdapter(
      child: Container(
        color: const Color(0xFFF7F7F7),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: adaptive.Adaptive.w(8),
              vertical: adaptive.Adaptive.h(4),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    AppIcons.arrowBack,
                    color: colorScheme.onSurface,
                    size: adaptive.Adaptive.sp(24),
                  ),
                ),
                Expanded(
                  child: Text(
                    '充值中心',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(17),
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                SizedBox(width: adaptive.Adaptive.w(48)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 余额卡片（蓝色渐变）
  // ============================================================
  SliverToBoxAdapter _buildBalanceCard(
    ColorScheme colorScheme,
    SubscriptionState subState,
  ) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primary,
                colorScheme.primary.withValues(alpha: 0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(adaptive.Adaptive.r(16)),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.all(adaptive.Adaptive.w(20)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '账户余额（元）',
                            style: TextStyle(
                              fontSize: adaptive.Adaptive.sp(13),
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                          SizedBox(height: adaptive.Adaptive.h(8)),
                          Text(
                            subState.balance.toStringAsFixed(2),
                            style: TextStyle(
                              fontSize: adaptive.Adaptive.sp(40),
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: adaptive.Adaptive.r(60),
                      height: adaptive.Adaptive.r(60),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          AppIcons.accountBalanceWallet,
                          size: adaptive.Adaptive.sp(28),
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 0.5,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TopupHistoryPage(),
                          ),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: adaptive.Adaptive.h(14),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              AppIcons.history,
                              size: adaptive.Adaptive.sp(14),
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                            SizedBox(width: adaptive.Adaptive.w(4)),
                            Text(
                              '充值记录',
                              style: TextStyle(
                                fontSize: adaptive.Adaptive.sp(13),
                                color: Colors.white.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 0.5,
                    height: adaptive.Adaptive.h(40),
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BillingPage(),
                          ),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: adaptive.Adaptive.h(14),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              AppIcons.receiptLong,
                              size: adaptive.Adaptive.sp(14),
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                            SizedBox(width: adaptive.Adaptive.w(4)),
                            Text(
                              '消费记录',
                              style: TextStyle(
                                fontSize: adaptive.Adaptive.sp(13),
                                color: Colors.white.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 充值金额区域
  // ============================================================
  SliverToBoxAdapter _buildTopupSection(ColorScheme colorScheme) {
    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(16)),
        padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: adaptive.Adaptive.w(4),
                  height: adaptive.Adaptive.h(18),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(adaptive.Adaptive.r(2)),
                  ),
                ),
                SizedBox(width: adaptive.Adaptive.w(8)),
                Text(
                  '充值金额',
                  style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(16),
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            SizedBox(height: adaptive.Adaptive.h(16)),
            if (_isLoading)
              _buildLoadingGrid(colorScheme)
            else if (_options.isEmpty)
              _buildEmptyState(colorScheme)
            else
              _buildTopupGrid(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingGrid(ColorScheme colorScheme) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: adaptive.Adaptive.h(12),
        crossAxisSpacing: adaptive.Adaptive.w(12),
        childAspectRatio: 1.25,
      ),
      itemCount: 4,
      itemBuilder: (_, _) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(12)),
          color: const Color(0xFFF5F5F5),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return EmptyState(icon: AppIcons.error, title: '暂无可用充值档位');
  }

  Widget _buildTopupGrid(ColorScheme colorScheme) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: adaptive.Adaptive.h(12),
        crossAxisSpacing: adaptive.Adaptive.w(12),
        childAspectRatio: 1.15,
      ),
      itemCount: _options.length,
      itemBuilder: (context, index) {
        final option = _options[index];
        final isSelected = _selectedIndex == index;
        final hasBonus = option.bonusAmount > 0;
        final isBest = option.label == '最划算';
        final totalAmount = option.originalAmount + option.bonusAmount;
        final isExperience = option.originalAmount <= 10;

        return GestureDetector(
          onTap: () => setState(() => _selectedIndex = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(adaptive.Adaptive.r(12)),
              color: isSelected
                  ? colorScheme.primary.withValues(alpha: 0.06)
                  : Colors.white,
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary
                    : (isBest
                          ? colorScheme.primary.withValues(alpha: 0.35)
                          : const Color(0xFFE8E8E8)),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Stack(
              children: [
                // 内容：居中布局
                Padding(
                  padding: EdgeInsets.all(adaptive.Adaptive.w(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Spacer(),
                      // 居中金额
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '¥',
                            style: TextStyle(
                              fontSize: adaptive.Adaptive.sp(16),
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            option.originalAmount.toStringAsFixed(0),
                            style: TextStyle(
                              fontSize: adaptive.Adaptive.sp(36),
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.onSurface,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: adaptive.Adaptive.h(6)),
                      // 原价（划线）
                      if (hasBonus)
                        Text(
                          '¥${totalAmount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: adaptive.Adaptive.sp(13),
                            color: const Color(0xFFAAAAAA),
                            decoration: TextDecoration.lineThrough,
                            decorationColor: const Color(0xFFCCCCCC),
                          ),
                        ),
                      const Spacer(),
                      // 底部信息
                      if (isExperience)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: adaptive.Adaptive.w(10),
                            vertical: adaptive.Adaptive.h(4),
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colorScheme.primary.withValues(alpha: 0.1)
                                : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(
                              adaptive.Adaptive.r(8),
                            ),
                          ),
                          child: Text(
                            '到账 ${totalAmount.toStringAsFixed(0)} 元',
                            style: TextStyle(
                              fontSize: adaptive.Adaptive.sp(12),
                              color: isSelected
                                  ? colorScheme.primary
                                  : const Color(0xFF666666),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      else if (hasBonus)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: adaptive.Adaptive.w(8),
                            vertical: adaptive.Adaptive.h(3),
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF22C55E,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              adaptive.Adaptive.r(6),
                            ),
                          ),
                          child: Text(
                            '送${option.bonusAmount.toStringAsFixed(0)}元',
                            style: TextStyle(
                              fontSize: adaptive.Adaptive.sp(11),
                              color: const Color(0xFF16A34A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // 最划算标签：右上角小标签，不遮挡内容
                if (isBest)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: adaptive.Adaptive.w(6),
                        vertical: adaptive.Adaptive.h(2),
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          adaptive.Adaptive.r(6),
                        ),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.25),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        '最划算',
                        style: TextStyle(
                          fontSize: adaptive.Adaptive.sp(10),
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                // 选中标记：右下角
                if (isSelected)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: adaptive.Adaptive.r(24),
                      height: adaptive.Adaptive.r(24),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(adaptive.Adaptive.r(10)),
                          bottomRight: Radius.circular(adaptive.Adaptive.r(10)),
                        ),
                      ),
                      child: Icon(
                        AppIcons.check,
                        size: adaptive.Adaptive.sp(14),
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // 充值说明
  // ============================================================
  SliverToBoxAdapter _buildTermsSection(ColorScheme colorScheme) {
    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.only(
          left: adaptive.Adaptive.w(16),
          right: adaptive.Adaptive.w(16),
          top: adaptive.Adaptive.h(16),
        ),
        padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: adaptive.Adaptive.w(4),
                  height: adaptive.Adaptive.h(18),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(adaptive.Adaptive.r(2)),
                  ),
                ),
                SizedBox(width: adaptive.Adaptive.w(8)),
                Text(
                  '充值说明',
                  style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(16),
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            SizedBox(height: adaptive.Adaptive.h(12)),
            _buildTermItem('充值金额将实时到账，可用于购买所有付费服务'),
            _buildTermItem('充值金额不支持提现，仅限在本应用内使用'),
            _buildTermItem('如遇充值异常，请联系客服处理'),
            _buildTermItem('充值前请确认已阅读并同意用户服务协议'),
          ],
        ),
      ),
    );
  }

  Widget _buildTermItem(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: adaptive.Adaptive.h(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: adaptive.Adaptive.h(6)),
            width: adaptive.Adaptive.r(5),
            height: adaptive.Adaptive.r(5),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: adaptive.Adaptive.w(8)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(12),
                color: const Color(0xFF666666),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 底部固定按钮 + 协议
  // ============================================================
  Widget _buildFixedBottomArea(ColorScheme colorScheme) {
    final selectedOption = _options[_selectedIndex];
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _agreedToTerms
                    ? () => _showTopupConfirmDialog(selectedOption, colorScheme)
                    : null,
                child: Container(
                  width: double.infinity,
                  height: adaptive.Adaptive.h(50),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _agreedToTerms
                          ? [
                              colorScheme.primary,
                              colorScheme.primary.withValues(alpha: 0.85),
                            ]
                          : [
                              Colors.grey.withValues(alpha: 0.4),
                              Colors.grey.withValues(alpha: 0.3),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(
                      adaptive.Adaptive.r(25),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '确认充值 ¥${selectedOption.originalAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(16),
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: adaptive.Adaptive.h(10)),
              GestureDetector(
                onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: adaptive.Adaptive.r(16),
                      height: adaptive.Adaptive.r(16),
                      decoration: BoxDecoration(
                        color: _agreedToTerms
                            ? colorScheme.primary
                            : Colors.transparent,
                        border: Border.all(
                          color: _agreedToTerms
                              ? colorScheme.primary
                              : Colors.grey.withValues(alpha: 0.4),
                        ),
                        borderRadius: BorderRadius.circular(
                          adaptive.Adaptive.r(4),
                        ),
                      ),
                      child: _agreedToTerms
                          ? Icon(
                              AppIcons.check,
                              size: adaptive.Adaptive.sp(12),
                              color: Colors.white,
                            )
                          : null,
                    ),
                    SizedBox(width: adaptive.Adaptive.w(6)),
                    Text(
                      '阅读并同意',
                      style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(12),
                        color: const Color(0xFF999999),
                      ),
                    ),
                    Text(
                      '《用户服务协议》',
                      style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(12),
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 充值确认弹窗
  // ============================================================
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
              borderRadius: BorderRadius.circular(adaptive.Adaptive.r(12)),
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
                    '→ 到账 ¥${(option.originalAmount + option.bonusAmount).toStringAsFixed(0)}',
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

    if (confirmed == true && mounted) {
      await _startIAPPurchase(option);
    }
  }

  // ============================================================
  // 苹果内购流程
  // ============================================================
  Future<void> _startIAPPurchase(TopupConfig option) async {
    if (IAPService.instance.status != IAPServiceStatus.available) {
      await IAPService.instance.initialize();
    }

    if (IAPService.instance.status != IAPServiceStatus.available) {
      if (mounted) {
        TDToast.showFail('内购服务暂不可用', context: context);
      }
      return;
    }

    final products = await IAPService.instance.queryProducts();
    final productId = _productIdForAmount(option.originalAmount);
    final product = products.where((p) => p.id == productId).firstOrNull;

    if (product == null) {
      if (mounted) {
        TDToast.showFail('未找到对应商品，请稍后重试', context: context);
      }
      return;
    }

    if (mounted) {
      TDToast.showLoading(context: context, text: '正在拉起支付...');
    }

    final success = await IAPService.instance.purchase(product);

    if (!success && mounted) {
      TDToast.dismissLoading();
      TDToast.showFail('支付请求失败', context: context);
      return;
    }

    late StreamSubscription<PurchaseDetails> sub;
    sub = IAPService.instance.purchaseStream.listen(
      (purchase) async {
        if (purchase.productID != productId) return;

        switch (purchase.status) {
          case PurchaseStatus.purchased:
            TDToast.dismissLoading();
            TDToast.showSuccess('充值成功', context: context);
            await sub.cancel();
            break;
          case PurchaseStatus.error:
            TDToast.dismissLoading();
            TDToast.showFail(
              purchase.error?.message ?? '支付失败',
              context: context,
            );
            await sub.cancel();
            break;
          case PurchaseStatus.canceled:
            TDToast.dismissLoading();
            await sub.cancel();
            break;
          default:
            break;
        }
      },
      onError: (e) {
        TDToast.dismissLoading();
        TDToast.showFail('支付异常', context: context);
        sub.cancel();
      },
    );
  }

  String _productIdForAmount(double amount) {
    switch (amount.toInt()) {
      case 5:
        return IAPProductIds.topup5;
      case 10:
        return IAPProductIds.topup10;
      case 20:
        return IAPProductIds.topup20;
      case 50:
        return IAPProductIds.topup50;
      case 100:
        return IAPProductIds.topup100;
      default:
        return IAPProductIds.topup5;
    }
  }
}
