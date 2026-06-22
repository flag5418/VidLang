/// 间距系统
/// 
/// 基于8pt网格系统的间距规范，iPhone专用。
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
  
  /// 中间距 - 16px
  /// 
  /// 用于：卡片内间距、列表项间距
  static const double md = 16;
  
  /// 大间距 - 24px
  /// 
  /// 用于：区块间间距、卡片间距
  static const double lg = 24;
  
  /// 超大间距 - 32px
  /// 
  /// 用于：页面区块间间距
  static const double xl = 32;
  
  /// 2倍超大间距 - 48px
  /// 
  /// 用于：页面间间距、大区块间距
  static const double xxl = 48;

  /// 获取语义化间距
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
  
  /// 页面水平内边距 - iPhone
  static const double pagePaddingHorizontal = 16;
  
  /// 页面内边距（别名，等同于 pagePaddingHorizontal）
  static const double pagePadding = 16;
  
  /// 页面垂直内边距
  static const double pagePaddingVertical = 24;

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
  
  /// Grid间距
  static const double gridSpacing = 12;
  
  /// Grid列间距（别名）
  static const double gridColumnSpacing = 12;
  
  /// Grid行间距（别名）
  static const double gridRowSpacing = 12;
  
  /// Grid列数（iPhone）
  static const int gridColumnsPhone = 2;
}
