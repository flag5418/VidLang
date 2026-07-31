import 'package:flutter/material.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/services/tts/tts_service.dart';
import 'package:vidlang/services/word_book/word_book_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';

/// 复习卡片（单词详情展示）
///
/// 参考文档：docs/modules/wordbook-design.md 第六节「单词详情页」
///
/// 展示内容：
/// - 单词 + 音标 + 发音按钮
/// - 释义（词性 + 中文释义）
/// - 例句
/// - 词形变化
/// - 助记
class ReviewCard extends StatefulWidget {
  final WordBook word;
  /// 是否翻转（true 显示详情面，false 显示正面）
  final bool isFlipped;
  /// 外部翻转回调（可选）
  final VoidCallback? onFlip;

  const ReviewCard({
    super.key,
    required this.word,
    this.isFlipped = false,
    this.onFlip,
  });

  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard> {
  void _speakWord() {
    TtsService().speakWord(widget.word.word);
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;

    // 根据 isFlipped 决定显示正面还是背面
    // 复习页面传入 isFlipped=true 始终显示详情
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: widget.isFlipped ? _buildDetailCard(cs) : _buildFrontCard(cs),
    );
  }

  /// 正面：单词 + 音标 + 发音按钮 + 翻转提示
  Widget _buildFrontCard(AppColorsData cs) {
    final brightness = Theme.of(context).brightness;
    return Container(
      key: const ValueKey('front'),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(Adaptive.r(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: brightness == Brightness.dark ? 0.3 : 0.08,
            ),
            blurRadius: Adaptive.w(16),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: widget.onFlip ?? () => setState(() {}),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: EdgeInsets.all(Adaptive.r(24)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.word.word,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Adaptive.sp(28),
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              SizedBox(height: Adaptive.h(8)),
              if ((widget.word.phoneticUk ?? widget.word.phoneticUs)?.isNotEmpty ?? false)
                Text(
                  '/${widget.word.phoneticUk ?? widget.word.phoneticUs}/',
                  style: TextStyle(
                    fontSize: Adaptive.sp(16),
                    color: cs.onSurfaceVariant,
                  ),
                ),
              SizedBox(height: Adaptive.h(20)),
              GestureDetector(
                onTap: _speakWord,
                child: Icon(
                  AppIcons.volumeUp,
                  size: Adaptive.sp(32),
                  color: cs.primary,
                ),
              ),
              SizedBox(height: Adaptive.h(24)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: Adaptive.w(24),
                  vertical: Adaptive.h(12),
                ),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(Adaptive.r(12)),
                ),
                child: Text(
                  '点击显示释义',
                  style: TextStyle(
                    fontSize: Adaptive.sp(14),
                    color: cs.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 背面/详情：完整单词信息（释义、例句、词形变化、助记）
  ///
  /// 对应文档第六节「单词详情页」的布局
  Widget _buildDetailCard(AppColorsData cs) {
    final brightness = Theme.of(context).brightness;
    final definitions =
        WordBookService.parseDefinitions(widget.word.definitionsJson);
    final morphology =
        WordBookService.parseMorphology(widget.word.morphologyJson);

    return Container(
      key: const ValueKey('detail'),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(Adaptive.r(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: brightness == Brightness.dark ? 0.3 : 0.08,
            ),
            blurRadius: Adaptive.w(16),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(Adaptive.r(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 单词标题行 ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.word.word,
                        style: TextStyle(
                          fontSize: Adaptive.sp(24),
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      if ((widget.word.phoneticUk ?? widget.word.phoneticUs)
                              ?.isNotEmpty ??
                          false)
                        Padding(
                          padding: EdgeInsets.only(top: Adaptive.h(4)),
                          child: Text(
                            '/${widget.word.phoneticUk ?? widget.word.phoneticUs}/',
                            style: TextStyle(
                              fontSize: Adaptive.sp(14),
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(width: Adaptive.w(8)),
                GestureDetector(
                  onTap: _speakWord,
                  child: Container(
                    padding: EdgeInsets.all(Adaptive.r(8)),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      AppIcons.volumeUp,
                      size: Adaptive.sp(18),
                      color: cs.primary,
                    ),
                  ),
                ),
              ],
            ),

            // ── 分割线 ──
            Padding(
              padding: EdgeInsets.symmetric(vertical: Adaptive.h(14)),
              child: Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.3),
              ),
            ),

            // ── 释义 ──
            if (definitions.isNotEmpty) ...[
              const _SectionTitle(title: '释义'),
              ...definitions.map(
                (d) => Padding(
                  padding: EdgeInsets.only(bottom: Adaptive.h(6)),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: Adaptive.sp(15),
                        color: cs.onSurface,
                        height: 1.5,
                      ),
                      children: [
                        if (d.partOfSpeech != null)
                          TextSpan(
                            text: '${d.partOfSpeech}. ',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: cs.primary,
                            ),
                          ),
                        TextSpan(text: d.meaning),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // ── 例句 ──
            if (definitions.any(
                (d) => d.example != null && d.example!.isNotEmpty,
            )) ...[
              SizedBox(height: Adaptive.h(12)),
              const _SectionTitle(title: '例句'),
              ...definitions
                  .where((d) => d.example != null && d.example!.isNotEmpty)
                  .map(
                    (d) => Padding(
                      padding: EdgeInsets.only(bottom: Adaptive.h(6)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '• ',
                            style: TextStyle(
                              fontSize: Adaptive.sp(14),
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              d.example!,
                              style: TextStyle(
                                fontSize: Adaptive.sp(14),
                                color: cs.onSurface,
                                fontStyle: FontStyle.italic,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],

            // ── 词形变化 ──
            if (morphology.isNotEmpty) ...[
              SizedBox(height: Adaptive.h(12)),
              const _SectionTitle(title: '词形变化'),
              Wrap(
                spacing: Adaptive.w(8),
                runSpacing: Adaptive.h(6),
                children:
                    morphology.entries.map((e) {
                  return Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Adaptive.w(10),
                      vertical: Adaptive.h(5),
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius:
                          BorderRadius.circular(AppRadius.tag),
                    ),
                    child: Text(
                      '${_morphologyLabel(e.key)}: ${e.value}',
                      style: TextStyle(
                        fontSize: Adaptive.sp(13),
                        color: cs.onSurface,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            // ── 助记 ──
            if ((widget.word.mnemonic ?? '').isNotEmpty) ...[
              SizedBox(height: Adaptive.h(12)),
              const _SectionTitle(title: '助记'),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(Adaptive.r(12)),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.3),
                  borderRadius:
                      BorderRadius.circular(AppRadius.input),
                ),
                child: Text(
                  widget.word.mnemonic!,
                  style: TextStyle(
                    fontSize: Adaptive.sp(14),
                    color: cs.onSurface,
                    height: 1.5,
                  ),
                ),
              ),
            ],

            // ── 来源信息 ──
            if ((widget.word.sourceTitle ?? '').isNotEmpty) ...[
              SizedBox(height: Adaptive.h(12)),
              const _SectionTitle(title: '来源'),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(Adaptive.r(10)),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius:
                      BorderRadius.circular(AppRadius.input),
                ),
                child: Row(
                  children: [
                    Icon(
                      _sourceIcon(widget.word.sourceType),
                      size: Adaptive.sp(14),
                      color: cs.primary,
                    ),
                    SizedBox(width: Adaptive.w(8)),
                    Expanded(
                      child: Text(
                        '${_sourceLabel(widget.word.sourceType)} · ${widget.word.sourceTitle}',
                        style: TextStyle(
                          fontSize: Adaptive.sp(13),
                          color: cs.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── 学习记录 ──
            if (widget.word.reviewCount > 0) ...[
              SizedBox(height: Adaptive.h(12)),
              const _SectionTitle(title: '学习记录'),
              Text(
                '复习 ${widget.word.reviewCount} 次 · 正确率 ${widget.word.reviewCount > 0 ? (widget.word.correctCount * 100 ~/ widget.word.reviewCount) : 0}%',
                style: TextStyle(
                  fontSize: Adaptive.sp(13),
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _morphologyLabel(String key) {
    switch (key) {
      case 'comparative':
        return '比较级';
      case 'superlative':
        return '最高级';
      case 'plural':
        return '复数';
      case 'pastTense':
      case 'past_tense':
        return '过去式';
      case 'pastParticiple':
      case 'past_participle':
        return '过去分词';
      case 'presentParticiple':
      case 'present_participle':
        return '现在分词';
      case 'thirdPerson':
      case 'third_person':
        return '第三人称单数';
      default:
        return key;
    }
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

  IconData _sourceIcon(String type) {
    switch (type) {
      case 'video':
        return AppIcons.movie;
      case 'article':
        return AppIcons.article;
      case 'music':
        return AppIcons.musicNote;
      default:
        return AppIcons.book;
    }
  }
}

/// 区块标题组件
class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: Adaptive.h(8)),
      child: Text(
        title,
        style: TextStyle(
          fontSize: Adaptive.sp(13),
          fontWeight: FontWeight.w600,
          color: cs.primary,
        ),
      ),
    );
  }
}
