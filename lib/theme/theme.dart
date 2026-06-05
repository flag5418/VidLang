/// 主题系统导出文件
/// 
/// 统一导出所有主题相关的类和配置，方便其他模块导入使用。
/// 
/// 使用方式：
/// ```dart
/// // 导入所有主题配置
/// import 'package:vidlang/theme/theme.dart';
/// 
/// // 导入设计令牌
/// import 'package:vidlang/theme/theme.dart';
/// // 然后访问 DesignTokens.colors, DesignTokens.spacing 等
/// ```

library;

/// 颜色系统
export 'app_colors.dart';
/// 图标系统
export 'app_icons.dart';
/// 圆角系统
export 'app_radius.dart';
/// 阴影系统
export 'app_shadows.dart';
/// 间距系统
export 'app_spacing.dart';
/// 主题配置
export 'app_theme.dart';
/// 字体系统
export 'app_typography.dart';
/// 设计令牌
export 'design_tokens.dart';
