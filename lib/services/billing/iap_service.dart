/// 苹果内购服务
///
/// 基于 `in_app_purchase` 插件实现 iOS StoreKit 内购流程。
///
/// ## 充值档位与产品 ID 映射
///
/// 所有产品需在 App Store Connect 中预先配置为 **Consumable（消耗型）**。
/// 产品 ID 命名规范：`com.yzh.vidlang.topup.{金额}`
///
/// | 档位 | 产品 ID | 面值 | 赠送 | 到账 |
/// |------|---------|------|------|------|
/// | 体验 | com.yzh.vidlang.topup.6 | ¥6 | - | ¥6 |
/// | 小充 | com.yzh.vidlang.topup.30 | ¥30 | - | ¥30 |
/// | 标准 | com.yzh.vidlang.topup.68 | ¥68 | ¥5 | ¥73 |
/// | 进阶 | com.yzh.vidlang.topup.128 | ¥128 | ¥15 | ¥143 |
/// | 大额 | com.yzh.vidlang.topup.328 | ¥328 | ¥50 | ¥378 |
/// | 至尊 | com.yzh.vidlang.topup.648 | ¥648 | ¥120 | ¥768 |
///
/// ## App Store Connect 配置步骤
///
/// 1. 登录 [App Store Connect](https://appstoreconnect.apple.com)
/// 2. 进入 **App > 功能 > App 内购买项目**
/// 3. 点击「+」添加消耗型项目
/// 4. 填写：
///    - 参考名称：如「充值68元」
///    - 产品 ID：`com.yzh.vidlang.topup.68`
///    - 价格等级：选择对应档位
/// 5. 提交审核（首次配置需添加截图和描述）
///
/// ## 技术实现要点
///
/// - 使用 `queryProductDetails()` 从 App Store 拉取产品信息
/// - 使用 `buyConsumable()` 发起购买（消耗型）
/// - 通过 `purchaseStream` 监听购买状态更新
/// - 购买成功后必须调用 `completePurchase()` 完成交易
/// - 服务端验证收据后调用 consume 标记已消耗
///
/// ## 注意事项
///
/// - 沙盒测试需使用 **沙盒测试员账号**，不能使用真实 Apple ID
/// - 测试时每次购买可能提示「您已购买此项目，将免费恢复」，这是沙盒正常行为
/// - 生产环境必须接入服务端收据验证（/verifyReceipt）
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

/// 内购产品 ID 常量
class IAPProductIds {
  IAPProductIds._();

  static const String topup5 = 'com.yzh.vidlang.topup.5';
  static const String topup10 = 'com.yzh.vidlang.topup.10';
  static const String topup20 = 'com.yzh.vidlang.topup.20';
  static const String topup50 = 'com.yzh.vidlang.topup.50';
  static const String topup100 = 'com.yzh.vidlang.topup.100';

  /// 所有产品 ID 集合
  static const Set<String> all = {
    topup5,
    topup10,
    topup20,
    topup50,
    topup100,
  };

  /// 根据产品 ID 获取充值金额（元）
  static double amountFromId(String productId) {
    switch (productId) {
      case topup5:
        return 5;
      case topup10:
        return 10;
      case topup20:
        return 20;
      case topup50:
        return 50;
      case topup100:
        return 100;
      default:
        return 0;
    }
  }
}

/// 内购服务状态
enum IAPServiceStatus {
  /// 未初始化
  uninitialized,

  /// 初始化中
  initializing,

  /// 可用（已连接商店）
  available,

  /// 不可用（设备不支持或商店连接失败）
  unavailable,
}

/// 苹果内购服务
///
/// 单例模式，在应用启动时初始化。
///
/// ```dart
/// // 初始化（main.dart 或启动流程中）
/// await IAPService.instance.initialize();
///
/// // 查询产品
/// final products = await IAPService.instance.queryProducts();
///
/// // 发起购买
/// final success = await IAPService.instance.purchase(productDetails);
/// ```
class IAPService {
  IAPService._();
  static final IAPService instance = IAPService._();

  final InAppPurchase _iap = InAppPurchase.instance;

  /// 当前状态
  IAPServiceStatus status = IAPServiceStatus.uninitialized;

  /// 已查询到的产品列表
  List<ProductDetails> products = [];

  /// 购买状态流控制器
  final StreamController<PurchaseDetails> _purchaseController =
      StreamController<PurchaseDetails>.broadcast();
  Stream<PurchaseDetails> get purchaseStream => _purchaseController.stream;

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// 初始化内购服务
  ///
  /// 应在应用启动时调用一次。
  /// 自动检测平台：iOS 启用 StoreKit，Android 启用 Google Play。
  Future<void> initialize() async {
    if (status != IAPServiceStatus.uninitialized) return;

    status = IAPServiceStatus.initializing;

    final bool available = await _iap.isAvailable();
    if (!available) {
      status = IAPServiceStatus.unavailable;
      return;
    }

    // 监听购买状态更新
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (error) {
        debugPrint('IAP purchase stream error: $error');
      },
    );

    // iOS 特定：设置交易完成后的 finish 回调
    if (Platform.isIOS) {
      final storeKit = _iap
          .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      await storeKit.setDelegate(ExamplePaymentQueueDelegate());
    }

    status = IAPServiceStatus.available;
  }

  /// 查询产品详情
  ///
  /// 从 App Store / Google Play 拉取产品信息（价格、描述等）。
  /// 返回成功匹配的产品列表，未匹配的产品 ID 在 `notFoundIDs` 中。
  Future<List<ProductDetails>> queryProducts() async {
    if (status != IAPServiceStatus.available) {
      throw StateError('IAP service not available. Call initialize() first.');
    }

    final ProductDetailsResponse response =
        await _iap.queryProductDetails(IAPProductIds.all);

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('IAP products not found: ${response.notFoundIDs}');
    }

    products = response.productDetails;

    // 按金额排序
    products.sort((a, b) {
      final amountA = IAPProductIds.amountFromId(a.id);
      final amountB = IAPProductIds.amountFromId(b.id);
      return amountA.compareTo(amountB);
    });

    return products;
  }

  /// 发起购买
  ///
  /// [productDetails] 从 `queryProducts()` 获取的产品详情。
  /// 返回 `true` 表示购买请求已成功发送，实际结果通过 `purchaseStream` 监听。
  Future<bool> purchase(ProductDetails productDetails) async {
    if (status != IAPServiceStatus.available) {
      throw StateError('IAP service not available');
    }

    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: productDetails,
    );

    return _iap.buyConsumable(purchaseParam: purchaseParam);
  }

  /// 完成购买（消耗交易）
  ///
  /// **必须在服务端验证收据成功后调用**，否则用户会被重复扣款。
  /// 调用后该交易标记为已完成，用户可再次购买同一产品。
  Future<void> completePurchase(PurchaseDetails purchaseDetails) async {
    if (purchaseDetails.pendingCompletePurchase) {
      await _iap.completePurchase(purchaseDetails);
    }
  }

  /// 恢复购买（用于非消耗型/订阅型，消耗型通常不需要）
  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  /// 购买状态更新处理
  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      _purchaseController.add(purchase);

      switch (purchase.status) {
        case PurchaseStatus.pending:
          debugPrint('IAP: purchase pending - ${purchase.productID}');
          break;
        case PurchaseStatus.purchased:
          debugPrint('IAP: purchase success - ${purchase.productID}');
          // 注意：不要在这里直接 completePurchase，
          // 应等待服务端验证收据后再完成
          break;
        case PurchaseStatus.error:
          debugPrint('IAP: purchase error - ${purchase.error?.message}');
          break;
        case PurchaseStatus.restored:
          debugPrint('IAP: purchase restored - ${purchase.productID}');
          break;
        case PurchaseStatus.canceled:
          debugPrint('IAP: purchase canceled - ${purchase.productID}');
          break;
      }
    }
  }

  /// 释放资源
  void dispose() {
    _subscription?.cancel();
    _purchaseController.close();
  }
}

/// iOS StoreKit 支付队列代理
///
/// 用于处理交易更新、推广订单等 StoreKit 特定事件。
class ExamplePaymentQueueDelegate implements SKPaymentQueueDelegateWrapper {
  @override
  bool shouldContinueTransaction(
    SKPaymentTransactionWrapper transaction,
    SKStorefrontWrapper storefront,
  ) {
    return true;
  }

  @override
  bool shouldShowPriceConsent() {
    return false;
  }
}
