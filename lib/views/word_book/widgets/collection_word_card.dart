import 'package:flutter/material.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/models/word_tag.dart';
import 'package:vidlang/services/word_book/word_book_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';

/// 简化的生词本卡片（iPad 模式）
///
/// V3.0 变更：
/// - 移除 checkbox，纯展示模式
/// - 显示测试篮状态图标
/// - 点击进入详情页复习
///
/// 显示：单词 + 简要释义 + 标签 + 测试篮状态 + 更多按钮
class CollectionWordCard extends StatelessWidget {
  final WordBook word;
  final List<WordTag> tags;
  /// 是否已在测试篮中
  final bool isInBasket;
  final VoidCallback onTap;
  final VoidCallback onTagTap;

  const CollectionWordCard({
    super.key,
    required this.word,
    required this.tags,
    this.isInBasket = false,
    required this.onTap,
    required this.onTagTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cs = context.colors;
    final meaning = WordBookService.firstMeaning(word.definitionsJson) ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Adaptive.r(16)),
        child: Container(
          padding: EdgeInsets.all(Adaptive.r(14)),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(Adaptive.r(16)),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── 中间内容区 ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 第一行：单词/短句 + 来源图标
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            word.word,
                            style: TextStyle(
                              fontSize: Adaptive.sp(17),
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: Adaptive.w(8)),
                        Icon(_sourceIcon(word.sourceType), size: Adaptive.sp(16), color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                        // 测试篮状态图标
                        if (isInBasket)
                          Padding(
                            padding: EdgeInsets.only(left: Adaptive.w(4)),
                            child: Icon(
                              AppIcons.shoppingCart,
                              size: Adaptive.sp(14),
                              color: colorScheme.primary,
                            ),
                          ),
                        if (word.reviewCount > 0) ...[
                          SizedBox(width: Adaptive.w(4)),
                          Text(
                            '复习${word.reviewCount}',
                            style: TextStyle(
                              fontSize: Adaptive.sp(11),
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    // 第二行：简要释义
                    if (meaning.isNotEmpty) ...[
                      SizedBox(height: Adaptive.h(6)),
                      Text(
                        meaning,
                        style: TextStyle(
                          fontSize: Adaptive.sp(13),
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    // 第三行：标签
                    if (tags.isNotEmpty) ...[
                      SizedBox(height: Adaptive.h(8)),
                      Wrap(
                        spacing: Adaptive.w(6),
                        runSpacing: Adaptive.h(6),
                        children: tags.map((tag) {
                          return InkWell(
                            onTap: onTagTap,
                            borderRadius: BorderRadius.circular(Adaptive.r(999)),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: Adaptive.w(8), vertical: Adaptive.h(4)),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(Adaptive.r(999)),
                              ),
                              child: Text(
                                tag.name,
                                style: TextStyle(fontSize: Adaptive.sp(12), color: colorScheme.primary),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),

               // ── 右侧更多按钮 ──
               _buildMoreButton(cs),
            ],
          ),
        ),
      ),
    );
  }

  /// 右侧更多操作按钮
  Widget _buildMoreButton(AppColorsData cs) {
    return IconButton(
      onPressed: () {
        // TODO: 展开更多操作菜单（加入测试、删除等）
      },
      icon: Icon(
        AppIcons.moreVert,
        size: Adaptive.sp(18),
        color: cs.onSurfaceVariant,
      ),
      constraints: BoxConstraints(
        minWidth: Adaptive.w(32),
        minHeight: Adaptive.w(32),
      ),
      padding: EdgeInsets.zero,
      tooltip: '更多操作',
    );
  }

  IconData _sourceIcon(String type) {
    switch (type) {
      case 'video': return AppIcons.movie;
      case 'article': return AppIcons.article;
      case 'music': return AppIcons.musicNote;
      default: return AppIcons.book;
    }
  }
}
