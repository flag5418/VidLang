/// UI 基础组件库
///
/// VidLang 统一组件规范，基于项目设计系统：
/// - [BaseCard] 基础卡片（支持 outlined/elevated/filled 三种变体）
/// - [TitledCard] 带标题的卡片
/// - [EmptyState] 空状态组件
/// - [Avatar] 头像组件（支持图片/文字/图标三种模式）
/// - [Badge] 徽章组件（含语义化子类）
///
/// 使用示例：
/// ```dart
/// import 'package:vidlang/components/ui/ui_components.dart';
///
/// // 卡片
/// BaseCard.outlined(
///   padding: EdgeInsets.all(16),
///   child: Text('内容'),
/// )
///
/// // 空状态
/// EmptyState(
///   icon: Icons.inbox,
///   title: '暂无数据',
///   description: '点击刷新试试',
/// )
///
/// // 头像
/// Avatar(
///   text: '张三',
///   size: AvatarSize.lg,
///   showEditBadge: true,
///   onTap: () {},
/// )
/// ```
library;

export 'base_card.dart';
export 'empty_state.dart';
export 'avatar.dart';
export 'badge.dart';
