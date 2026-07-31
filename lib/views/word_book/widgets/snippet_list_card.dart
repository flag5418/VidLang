import 'package:flutter/material.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/models/word_tag.dart';
import 'package:vidlang/services/tts/tts_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';

/// 短语列表卡片
///
/// V3.0 变更：
/// - 移除 checkbox，纯展示模式
/// - 显示测试篮状态图标
/// - 点击进入详情页复习
class SnippetListCard extends StatelessWidget {
  final WordBook snippet;
  final List<WordTag> tags;
  /// 是否已在测试篮中
  final bool isInBasket;
  final VoidCallback onTap;
  final VoidCallback onTagTap;

  const SnippetListCard({
    super.key,
    required this.snippet,
    required this.tags,
    this.isInBasket = false,
    required this.onTap,
    required this.onTagTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cs = context.colors;
    final sourceText = snippet.sourceText ?? snippet.word;
    final sourceTitle = snippet.sourceTitle ?? '';

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 中间内容区 ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            sourceText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: Adaptive.sp(14),
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                              height: 1.4,
                            ),
                          ),
                        ),
                        SizedBox(width: Adaptive.w(8)),
                        GestureDetector(
                          onTap: () => TtsService().speakSubtitle(sourceText),
                          child: Icon(
                            AppIcons.volumeUp,
                            size: Adaptive.sp(20),
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    if (sourceTitle.isNotEmpty) ...[
                      SizedBox(height: Adaptive.h(6)),
                      Row(
                        children: [
                          Text(
                            _sourceLabel(snippet.sourceType),
                            style: TextStyle(fontSize: Adaptive.sp(13)),
                          ),
                          SizedBox(width: Adaptive.w(6)),
                          Expanded(
                            child: Text(
                              sourceTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: Adaptive.sp(12),
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          // 测试篮状态图标
                          if (isInBasket)
                            Padding(
                              padding: EdgeInsets.only(right: Adaptive.w(4)),
                              child: Icon(
                                AppIcons.shoppingCart,
                                size: Adaptive.sp(14),
                                color: colorScheme.primary,
                              ),
                            ),
                          Text(
                            '复习${snippet.reviewCount}',
                            style: TextStyle(
                              fontSize: Adaptive.sp(13),
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
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
                                style: TextStyle(
                                  fontSize: Adaptive.sp(13),
                                  color: colorScheme.primary,
                                ),
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

  String _sourceLabel(String type) {
    switch (type) {
      case 'video':
        return '视频';
      case 'article':
        return '文章';
      case 'music':
        return '音频';
      default:
        return '资源';
    }
  }
}
