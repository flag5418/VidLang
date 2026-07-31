import 'package:flutter/material.dart';
import 'package:vidlang/models/word_book_query_models.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';

/// 我的收藏导航面板（二级导航设计）
///
/// 导航层级：
///   生词 / 已掌握  →  全部 / 标签分组  →  单词列表（外部渲染）
///
/// V2.0 变更：
/// - 移除智能筛选区域（需复习/从未测试/错误率高）
/// - 简化为纯粹的导航组件
///
/// 设计风格：朴素严谨，以主题色为主
class WordBookNavPanel extends StatelessWidget {
  /// 当前选中的状态：learning / mastered
  final String selectedStatus;
  /// 当前选中的标签 code，null 表示"全部"
  final String? selectedTagCode;
  /// 生词下的导航项（包含"全部" + 各标签分组）
  final List<WordBookNavItem> learningItems;
  /// 已掌握下的导航项
  final List<WordBookNavItem> masteredItems;
  /// 选中导航项回调
  final ValueChanged<WordBookNavItem> onSelect;

  const WordBookNavPanel({
    super.key,
    required this.selectedStatus,
    required this.selectedTagCode,
    required this.learningItems,
    required this.masteredItems,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;

    return Container(
      padding: EdgeInsets.all(Adaptive.r(12)),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Adaptive.r(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ═══ 一级导航：生词 / 已掌握 ═══
          _buildStatusTabs(context),

          SizedBox(height: Adaptive.h(12)),

          // ═══ 二级导航：标签分组列表 ═══
          _buildTagGroupList(context),
        ],
      ),
    );
  }

  /// 一级导航：生词 / 已掌握 切换 Tab
  Widget _buildStatusTabs(BuildContext context) {
    final cs = context.colors;

    return Container(
      padding: EdgeInsets.all(Adaptive.r(4)),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(Adaptive.r(12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatusChip(
              context,
              label: '生词',
              status: 'learning',
              icon: AppIcons.school,
            ),
          ),
          Expanded(
            child: _buildStatusChip(
              context,
              label: '已掌握',
              status: 'mastered',
              icon: AppIcons.star,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(
    BuildContext context, {
    required String label,
    required String status,
    required IconData icon,
  }) {
    final cs = context.colors;
    final isSelected = selectedStatus == status;
    final items = status == 'learning' ? learningItems : masteredItems;
    // 计算该状态下的总数（第一个 item 是"全部"，其 count 即为总数）
    final totalCount = items.isNotEmpty ? items.first.count : 0;

    return GestureDetector(
      onTap: () {
        // 点击切换一级导航时，默认选中"全部"
        if (items.isNotEmpty) {
          onSelect(items.first);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: Adaptive.h(9)),
        decoration: BoxDecoration(
          color: isSelected ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(Adaptive.r(10)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: Adaptive.sp(15),
              color: isSelected ? AppColors.onPrimary : cs.onSurfaceVariant,
            ),
            SizedBox(width: Adaptive.w(5)),
            Text(
              label,
              style: TextStyle(
                fontSize: Adaptive.sp(13),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.onPrimary : cs.onSurface,
              ),
            ),
            if (totalCount > 0) ...[
              SizedBox(width: Adaptive.w(4)),
              Text(
                '$totalCount',
                style: TextStyle(
                  fontSize: Adaptive.sp(11),
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? AppColors.onPrimary.withValues(alpha: 0.8)
                      : cs.outline,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 二级导航：标签分组列表
  Widget _buildTagGroupList(BuildContext context) {
    final cs = context.colors;
    final items = selectedStatus == 'learning' ? learningItems : masteredItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分组标题
        Padding(
          padding: EdgeInsets.only(left: Adaptive.w(4), bottom: Adaptive.h(8)),
          child: Text(
            '标签分组',
            style: TextStyle(
              fontSize: Adaptive.sp(11),
              fontWeight: FontWeight.w600,
              color: cs.outline,
              letterSpacing: 0.5,
            ),
          ),
        ),

        // 标签列表
        ...items.map((item) {
          final isAll = item.tagCode == null;
          final selected =
              item.status == selectedStatus && item.tagCode == selectedTagCode;

          return Padding(
            padding: EdgeInsets.only(bottom: Adaptive.h(5)),
            child: InkWell(
              onTap: () => onSelect(item),
              borderRadius: BorderRadius.circular(Adaptive.r(10)),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: Adaptive.w(12),
                  vertical: Adaptive.h(10),
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? cs.primary.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(Adaptive.r(10)),
                  border: selected
                      ? Border.all(color: cs.primary.withValues(alpha: 0.3), width: 1)
                      : null,
                ),
                child: Row(
                  children: [
                    // 左侧图标/标识
                    if (isAll)
                      Icon(
                        AppIcons.viewModule,
                        size: Adaptive.sp(15),
                        color: selected ? cs.primary : cs.onSurfaceVariant.withValues(alpha: 0.6),
                      )
                    else
                      Container(
                        width: Adaptive.w(8),
                        height: Adaptive.w(8),
                        decoration: BoxDecoration(
                          color: selected ? cs.primary : cs.outlineVariant.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                      ),
                    SizedBox(width: Adaptive.w(10)),

                    // 标签名
                    Expanded(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: Adaptive.sp(13),
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                          color: selected ? cs.primary : cs.onSurface,
                        ),
                      ),
                    ),

                    // 数量 Badge
                    if (item.count > 0)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: Adaptive.w(7),
                          vertical: Adaptive.h(2),
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? cs.primary.withValues(alpha: 0.15)
                              : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(Adaptive.r(10)),
                        ),
                        child: Text(
                          '${item.count}',
                          style: TextStyle(
                            fontSize: Adaptive.sp(11),
                            fontWeight: FontWeight.w600,
                            color: selected ? cs.primary : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
