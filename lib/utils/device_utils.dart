/// 设备信息工具类（iPhone 专用）
///
/// 集中管理网格列数、间距等固定值。
/// 仅支持 iPhone portrait 布局。
library;


class DeviceUtils {
  DeviceUtils._();

  /// 初始化（空操作，仅为向后兼容）
  static Future<void> initialize() async {}

  /// 网格列数（iPhone 固定 2 列）
  static const int gridColumns = 2;

  /// 网格间距
  static const double gridSpacing = 12.0;

  /// 页面水平内边距
  static const double pagePadding = 16.0;
}
