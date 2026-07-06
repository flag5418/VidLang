/// 间距系统 — VidLang 设计升级 v3.0
///
/// 基于 iPhone 390pt 宽度的基准间距，iPad 下通过 Adaptive 缩放。
library;

class AppSpacing {
  AppSpacing();

  // ─── 新设计令牌 ──────────────────────────────────
  /// 段落之间
  static const double sectionGap = 32.0;
  /// 标题与内容
  static const double titleGap   = 14.0;
  /// 同类内容之间
  static const double itemGap    = 12.0;
  /// iPhone 页面水平边距
  static const double pageH      = 16.0;
  /// iPad 页面水平边距
  static const double pageHiPad  = 24.0;
  /// 卡片内边距
  static const double cardInner  = 16.0;

  // ─── 基础间距值（保留向后兼容） ────────────────
  static const double space0  = 0;
  static const double space1  = 4;
  static const double space2  = 8;
  static const double space3  = 12;
  static const double space4  = 16;
  static const double space5  = 20;
  static const double space6  = 24;
  static const double space7  = 28;
  static const double space8  = 32;
  static const double space9  = 36;
  static const double space10 = 40;
  static const double space11 = 44;
  static const double space12 = 48;
  static const double space14 = 56;
  static const double space16 = 64;
  static const double space20 = 80;
  static const double space24 = 96;

  // ─── 语义化间距（保留向后兼容）─────────────────
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  static double getSpacing(String size) {
    switch (size) {
      case 'xs': return xs;
      case 'sm': return sm;
      case 'md': return md;
      case 'lg': return lg;
      case 'xl': return xl;
      case 'xxl': return xxl;
      default:   return md;
    }
  }

  // ─── 页面内边距（保留向后兼容）─────────────────
  static const double pagePaddingHorizontal = 16;
  static const double pagePadding = 16;
  static const double pagePaddingVertical = 24;

  // ─── 组件间距（保留向后兼容）───────────────────
  static const double cardPadding = 16;
  static const double buttonPaddingHorizontal = 20;
  static const double buttonPaddingVertical = 12;
  static const double inputPadding = 12;
  static const double listItemPadding = 12;
  static const double listItemSpacing = 8;

  // ─── Grid 间距（保留向后兼容）───────────────────
  static const double gridSpacing = 12;
  static const double gridColumnSpacing = 12;
  static const double gridRowSpacing = 12;
  static const int    gridColumnsPhone = 2;
}
