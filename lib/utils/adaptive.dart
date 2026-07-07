import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// ═══════════════════════════════════════════════════════════════
// 设备检测
// ═══════════════════════════════════════════════════════════════

/// 判断当前设备是否为 iPad（短边 >= 600pt）
bool isIPad(BuildContext context) =>
    MediaQuery.of(context).size.shortestSide >= 600;

// ═══════════════════════════════════════════════════════════════
// iPad 尺寸缩放规则表（枚举）
//
// 核心设计：
// - 所有值以 iPhone 的 pt 尺寸为基准（iPhone 下原值输出，不变）
// - iPad 下 = iPhone 基准值 × scale 系数 → 再经 ScreenUtil 映射
// - 修改系数即可全局调整 iPad 下的对应尺寸类别
// - 后续如需更精细化控制，可新增枚举成员
//
// 使用示例：
// ```dart
// Adaptive.sp(context, 16)   // 字体：iPhone=16, iPad=16×1.38≈22.1
// Adaptive.w(context, 24)    // 宽度：iPhone=24, iPad=24×1.30≈31.2
// Adaptive.r(context, 12)    // 圆角：iPhone=12, iPad=12×1.20≈14.4
// ```
// ═══════════════════════════════════════════════════════════════

/// iPad 尺寸缩放类型枚举
///
/// 每种类型对应一个独立的缩放系数，用于控制 iPad 下该类尺寸的放大比例。
/// 新增尺寸类型只需在此枚举中添加成员，并在 [DeviceScale._scales] 中注册系数。
enum ScaleType {
  /// 字体大小（fontSize）
  /// 用于：所有文本的 fontSize
  font,

  /// 水平方向尺寸（宽度、水平间距、水平 padding）
  /// 用于：Container 宽度、EdgeInsets.horizontal、SizedBox.width 等
  width,

  /// 垂直方向尺寸（高度、垂直间距、垂直 padding）
  /// 用于：Container 高度、EdgeInsets.vertical、SizedBox.height 等
  height,

  /// 圆角半径（borderRadius）
  /// 用于：BorderRadius.circular、Card 的 shape 等
  radius,

  /// 图标尺寸（icon size）
  /// 用于：Icon 的 size 参数
  icon,
}

/// iPad 统一比例系数表
///
/// 调参指南：
/// - 觉得 iPad 字体偏小？增大 [font] 系数
/// - 觉得 iPad 间距太松？减小 [width] / [height] 系数
/// - 想让图标更大？增大 [icon] 系数
/// - 想统一调整？修改 [base] 并让各类型引用它
class DeviceScale {
  DeviceScale._();

  /// 获取指定类型的缩放系数
  static double of(ScaleType type) => _scales[type] ?? base;

  // ─── 基础系数 ────────────────────────────────────────
  /// 全局基础缩放系数（各类型的默认 fallback 值）
  ///
  /// 推荐范围：1.25 ~ 1.50
  static const double base = 1.35;

  // ─── 各维度独立系数（可单独调参） ──────────────────
  /// 各类型对应的缩放系数表
  static const Map<ScaleType, double> _scales = {
    ScaleType.font:   1.38,  // 字体稍大一些，保证可读性
    ScaleType.width:  1.30,  // 水平尺寸适中放大
    ScaleType.height: 1.30,  // 垂直尺寸同水平
    ScaleType.radius: 1.20,  // 圆角微调即可
    ScaleType.icon:   1.28,  // 图标介于字体和间距之间
  };
}

// ═══════════════════════════════════════════════════════════════
// 自适应尺寸工具类
//
// 统一的尺寸适配入口：
// - iPhone 设备：输出原始 pt 值（不变）
// - iPad 设备：原始值 × [DeviceScale] 对应系数 → ScreenUtil 映射
// ═══════════════════════════════════════════════════════════════

class Adaptive {
  Adaptive._();

  /// 判断当前设备是否为 iPad
  static bool of(BuildContext context) => isIPad(context);

  // ─── 核心适配方法 ──────────────────────────────────

  /// 字体大小适配（ScaleType.font）
  ///
  /// iPhone: 返回原始值
  /// iPad:  value × font系数 → .sp (ScreenUtil)
  static double sp(BuildContext context, num value) =>
      _scale(context, value, ScaleType.font, (v) => v.sp);

  /// 水平尺寸适配（ScaleType.width）
  ///
  /// iPhone: 返回原始值
  /// iPad:  value × width系数 → .w (ScreenUtil)
  static double w(BuildContext context, num value) =>
      _scale(context, value, ScaleType.width, (v) => v.w);

  /// 垂直尺寸适配（ScaleType.height）
  ///
  /// iPhone: 返回原始值
  /// iPad:  value × height系数 → .h (ScreenUtil)
  static double h(BuildContext context, num value) =>
      _scale(context, value, ScaleType.height, (v) => v.h);

  /// 圆角半径适配（ScaleType.radius）
  ///
  /// iPhone: 返回原始值
  /// iPad:  value × radius系数 → .r (ScreenUtil)
  static double r(BuildContext context, num value) =>
      _scale(context, value, ScaleType.radius, (v) => v.r);

  /// 图标尺寸适配（ScaleType.icon）
  ///
  /// iPhone: 返回原始值
  /// iPad:  value × icon系数 → .sp (ScreenUtil，图标也用 sp 保证和字体协调)
  static double icon(BuildContext context, num value) =>
      _scale(context, value, ScaleType.icon, (v) => v.sp);

  // ─── 内部方法 ──────────────────────────────────────

  /// 统一的缩放逻辑
  ///
  /// [value]   基于 iPhone 设计稿的原始值
  /// [type]    缩放类型（决定使用哪个系数）
  /// [screenUtilFn]  ScreenUtil 的映射函数（.sp/.w/.h/.r）
  static double _scale(
    BuildContext context,
    num value,
    ScaleType type,
    double Function(num) screenUtilFn,
  ) {
    if (isIPad(context)) {
      final scaled = value.toDouble() * DeviceScale.of(type);
      return screenUtilFn(scaled);
    }
    return value.toDouble();
  }
}

// ═══════════════════════════════════════════════════════════════
// BuildContext 扩展 — 更简洁的调用方式
//
// 推荐新代码使用此 extension，写法更简洁：
//   context.ts(16)   替代 Adaptive.sp(context, 16)
//   context.s(24)    替代 Adaptive.w(context, 24)
//   context.rs(12)   替代 Adaptive.r(context, 12)
//   context.is_(24)  替代 Adaptive.icon(context, 24)
// ═══════════════════════════════════════════════════════════════

extension AdaptiveContext on BuildContext {
  /// 文字尺寸（font scale）— 等价于 [Adaptive.sp]
  double ts(num value) => Adaptive.sp(this, value);

  /// 通用尺寸（width/height scale）— 等价于 [Adaptive.w]
  double s(num value) => Adaptive.w(this, value);

  /// 圆角尺寸（radius scale）— 等价于 [Adaptive.r]
  double rs(num value) => Adaptive.r(this, value);

  /// 图标尺寸（icon scale）— 等价于 [Adaptive.icon]
  double is_(num value) => Adaptive.icon(this, value);

  /// 是否为 iPad 设备
  bool get ipad => isIPad(this);

  /// 是否为 iPhone 设备
  bool get iphone => !isIPad(this);
}
