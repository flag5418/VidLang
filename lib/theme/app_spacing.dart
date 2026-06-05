/// 间距系统
/// 
/// 基于8pt网格系统的间距规范，确保一致的间距体验。
/// 
/// 基础间距值（0-64）：
/// | 名称 | 值 | 计算 |
/// |------|-----|------|
/// | 0 | 0px | - |
/// | 1 | 4px | 4 × 1 |
/// | 2 | 8px | 4 × 2 |
/// | 3 | 12px | 4 × 3 |
/// | 4 | 16px | 4 × 4 |
/// | 5 | 20px | 4 × 5 |
/// | 6 | 24px | 4 × 6 |
/// | 7 | 28px | 4 × 7 |
/// | 8 | 32px | 4 × 8 |
/// | 9 | 36px | 4 × 9 |
/// | 10 | 40px | 4 × 10 |
/// | 11 | 44px | 4 × 11 |
/// | 12 | 48px | 4 × 12 |
/// | 14 | 56px | 4 × 14 |
/// | 16 | 64px | 4 × 16 |
/// 
/// 语义化间距：
/// | 名称 | 移动端 | 平板 | 桌面 |
/// |------|--------|------|------|
/// | xs | 4px | 4px | 4px |
/// | sm | 8px | 8px | 8px |
/// | md | 12px | 16px | 16px |
/// | lg | 16px | 24px | 24px |
/// | xl | 24px | 32px | 32px |
/// | xxl | 32px | 48px | 48px |
/// 
/// 使用方式：
/// ```dart
/// import 'package:vidlang/theme/design_tokens.dart';
/// 
/// // 使用语义化间距
/// Padding(padding: EdgeInsets.all(DesignTokens.spacing.large))
/// 
/// // 使用基础间距
/// SizedBox(height: DesignTokens.spacing.base)
/// ```
library;

/// 应用间距类
/// 
/// 包含所有间距令牌
class AppSpacing {
  AppSpacing();

  // ============================================================
  // 基础间距值（4px倍数）
  // ============================================================
  
  /// 0px
  static const double space0 = 0;
  
  /// 4px
  static const double space1 = 4;
  
  /// 8px
  static const double space2 = 8;
  
  /// 12px
  static const double space3 = 12;
  
  /// 16px
  static const double space4 = 16;
  
  /// 20px
  static const double space5 = 20;
  
  /// 24px
  static const double space6 = 24;
  
  /// 28px
  static const double space7 = 28;
  
  /// 32px
  static const double space8 = 32;
  
  /// 36px
  static const double space9 = 36;
  
  /// 40px
  static const double space10 = 40;
  
  /// 44px
  static const double space11 = 44;
  
  /// 48px
  static const double space12 = 48;
  
  /// 56px
  static const double space14 = 56;
  
  /// 64px
  static const double space16 = 64;
  
  /// 80px
  static const double space20 = 80;
  
  /// 96px
  static const double space24 = 96;

  // ============================================================
  // 语义化间距
  // ============================================================
  
  /// 超小间距 - 4px
  /// 
  /// 用于：紧凑元素间的间距
  static const double xs = 4;
  
  /// 小间距 - 8px
  /// 
  /// 用于：标签内间距、小组件间距
  static const double sm = 8;
  
  /// 中间距 - 12px/16px
  /// 
  /// 用于：卡片内间距、列表项间距
  static const double md = 16;
  
  /// 大间距 - 16px/24px
  /// 
  /// 用于：区块间间距、卡片间距
  static const double lg = 24;
  
  /// 超大间距 - 24px/32px
  /// 
  /// 用于：页面区块间间距
  static const double xl = 32;
  
  /// 2倍超大间距 - 32px/48px
  /// 
  /// 用于：页面间间距、大区块间距
  static const double xxl = 48;

  /// 获取语义化间距
  /// 
  /// 根据断点返回响应式间距值
  /// [size] 间距名称：xs, sm, md, lg, xl, xxl
  static double getSpacing(String size) {
    switch (size) {
      case 'xs':
        return xs;
      case 'sm':
        return sm;
      case 'md':
        return md;
      case 'lg':
        return lg;
      case 'xl':
        return xl;
      case 'xxl':
        return xxl;
      default:
        return md;
    }
  }

  // ============================================================
  // 页面内边距
  // ============================================================
  
  /// 页面水平内边距 - 移动端
  static const double pagePaddingHorizontalMobile = 16;
  
  /// 页面水平内边距 - 平板
  static const double pagePaddingHorizontalTablet = 24;
  
  /// 页面水平内边距 - 桌面
  static const double pagePaddingHorizontalDesktop = 32;
  
  /// 页面垂直内边距
  static const double pagePaddingVertical = 24;

  /// 获取页面水平内边距（根据屏幕宽度）
  static double getPagePaddingHorizontal(double screenWidth) {
    if (screenWidth < 640) {
      return pagePaddingHorizontalMobile;
    } else if (screenWidth < 1024) {
      return pagePaddingHorizontalTablet;
    } else {
      return pagePaddingHorizontalDesktop;
    }
  }

  // ============================================================
  // 组件间距
  // ============================================================
  
  /// 卡片内边距
  static const double cardPadding = 16;
  
  /// 按钮内边距（水平）
  static const double buttonPaddingHorizontal = 20;
  
  /// 按钮内边距（垂直）
  static const double buttonPaddingVertical = 12;
  
  /// 输入框内边距
  static const double inputPadding = 12;
  
  /// 列表项内边距
  static const double listItemPadding = 12;
  
  /// 列表项间距
  static const double listItemSpacing = 8;

  // ============================================================
  // Grid间距
  // ============================================================
  
  /// Grid列间距
  static const double gridColumnSpacing = 16;
  
  /// Grid行间距
  static const double gridRowSpacing = 16;
  
  /// Grid列数（移动端）
  static const int gridColumnsMobile = 2;
  
  /// Grid列数（平板）
  static const int gridColumnsTablet = 4;
  
  /// Grid列数（桌面）
  static const int gridColumnsDesktop = 6;

  /// 获取Grid列数
  static int getGridColumns(double screenWidth) {
    if (screenWidth < 640) {
      return gridColumnsMobile;
    } else if (screenWidth < 1024) {
      return gridColumnsTablet;
    } else {
      return gridColumnsDesktop;
    }
  }
}
