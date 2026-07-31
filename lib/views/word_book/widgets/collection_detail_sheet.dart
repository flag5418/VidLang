import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/models/word_tag.dart';
import 'package:vidlang/providers/test_basket_provider.dart';
import 'package:vidlang/services/tts/tts_service.dart';
import 'package:vidlang/services/word_book/word_book_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';

/// iPad 模式下的单词详情弹窗
///
/// V3.1 变更：
/// - 使用 ConsumerWidget 实现实时状态更新
/// - "加入测试"按钮状态实时响应
/// - 图标和文案改为测试基调（非购物车）
class CollectionDetailSheet extends ConsumerWidget {
  final WordBook word;
  final List<WordTag> tags;
  final VoidCallback onClose;
  /// 认识回调
  final VoidCallback? onRecognized;
  /// 不认识回调
  final VoidCallback? onUnrecognized;
  /// 删除回调（仅已掌握状态显示）
  final VoidCallback? onDelete;

  const CollectionDetailSheet({
    super.key,
    required this.word,
    this.tags = const <WordTag>[],
    required this.onClose,
    this.onRecognized,
    this.onUnrecognized,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colors;
    final colorScheme = Theme.of(context).colorScheme;
    final definitions = WordBookService.parseDefinitions(word.definitionsJson);
    final morphology = WordBookService.parseMorphology(word.morphologyJson);
    final accuracy = word.reviewCount == 0 ? 0 : (word.correctCount * 100 ~/ word.reviewCount);

    // 实时监听测试篮状态
    final basketState = ref.watch(testBasketProvider);
    final isInBasket = basketState.isSelected(word.code ?? '');

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(maxHeight: Adaptive.h(580)),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(Adaptive.r(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: Adaptive.w(20),
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ═══ 标题栏 ═══
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Adaptive.w(16), vertical: Adaptive.h(14)),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '详情',
                      style: TextStyle(
                        fontSize: Adaptive.sp(12),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  // 加入测试按钮（实时状态）
                  _buildTestButton(cs, colorScheme, isInBasket, ref),
                  SizedBox(width: Adaptive.w(8)),
                  // 删除按钮
                  if (onDelete != null)
                    IconButton(
                      onPressed: onDelete,
                      icon: Icon(AppIcons.delete, size: Adaptive.icon(18), color: cs.error),
                      constraints: BoxConstraints(minWidth: Adaptive.w(32), minHeight: Adaptive.w(32)),
                      padding: EdgeInsets.zero,
                      tooltip: '删除',
                    ),
                  SizedBox(width: Adaptive.w(4)),
                  GestureDetector(
                    onTap: onClose,
                    child: Container(
                      width: Adaptive.w(24),
                      height: Adaptive.h(24),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(Adaptive.r(12)),
                      ),
                      child: Icon(AppIcons.close, size: Adaptive.icon(12), color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),

            // ═══ 内容区 ═══
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(Adaptive.w(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 单词 + 音频
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            word.word,
                            style: TextStyle(fontSize: Adaptive.sp(24), fontWeight: FontWeight.w700, color: cs.onSurface),
                          ),
                        ),
                        SizedBox(width: Adaptive.w(8)),
                        GestureDetector(
                          onTap: () => TtsService().speakWord(word.word),
                          child: Icon(AppIcons.volumeUp, size: Adaptive.sp(18), color: cs.primary),
                        ),
                      ],
                    ),
                    if ((word.phoneticUk ?? word.phoneticUs)?.isNotEmpty ?? false)
                      Padding(
                        padding: EdgeInsets.only(top: Adaptive.h(4)),
                        child: Text(
                          '/${word.phoneticUk ?? word.phoneticUs}/',
                          style: TextStyle(fontSize: Adaptive.sp(15), color: cs.onSurfaceVariant),
                        ),
                      ),

                    // 释义
                    if (definitions.isNotEmpty) ...[
                      SizedBox(height: Adaptive.h(16)),
                      Text('释义', style: TextStyle(fontSize: Adaptive.sp(14), fontWeight: FontWeight.w700, color: cs.onSurface)),
                      ...definitions.map((d) => Padding(
                        padding: EdgeInsets.only(bottom: Adaptive.h(6)),
                        child: Text('${d.partOfSpeech != null ? '${d.partOfSpeech}. ' : ''}${d.meaning}', style: TextStyle(fontSize: Adaptive.sp(14), color: cs.onSurface)),
                      )),
                    ],

                    // 例句
                    if (definitions.any((d) => d.example != null && d.example!.isNotEmpty)) ...[
                      SizedBox(height: Adaptive.h(12)),
                      Text('例句', style: TextStyle(fontSize: Adaptive.sp(13), fontWeight: FontWeight.w600, color: cs.primary)),
                      ...definitions.where((d) => d.example != null && d.example!.isNotEmpty).map(
                        (d) => Padding(
                          padding: EdgeInsets.only(bottom: Adaptive.h(4)),
                          child: Text('• ${d.example}', style: TextStyle(fontSize: Adaptive.sp(13), color: cs.onSurfaceVariant)),
                        ),
                      ),
                    ],

                    // 词形变化
                    if (morphology.isNotEmpty) ...[
                      SizedBox(height: Adaptive.h(12)),
                      Text('词形变化', style: TextStyle(fontSize: Adaptive.sp(13), fontWeight: FontWeight.w600, color: cs.primary)),
                      ...morphology.entries.map((e) => Padding(
                        padding: EdgeInsets.only(bottom: Adaptive.h(4)),
                        child: Text('${_morphologyLabel(e.key)}: ${e.value}', style: TextStyle(fontSize: Adaptive.sp(13), color: cs.onSurface)),
                      )),
                    ],

                    // 助记
                    if (word.mnemonic?.isNotEmpty ?? false) ...[
                      SizedBox(height: Adaptive.h(12)),
                      Text('助记', style: TextStyle(fontSize: Adaptive.sp(13), fontWeight: FontWeight.w600, color: cs.primary)),
                      Text(word.mnemonic!, style: TextStyle(fontSize: Adaptive.sp(13), color: cs.onSurface)),
                    ],

                    // 来源
                    if ((word.sourceTitle ?? '').isNotEmpty) ...[
                      SizedBox(height: Adaptive.h(12)),
                      Text('来源', style: TextStyle(fontSize: Adaptive.sp(14), fontWeight: FontWeight.w700, color: cs.onSurface)),
                      Container(
                        padding: EdgeInsets.all(Adaptive.w(12)),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(Adaptive.r(10)),
                          border: Border.all(color: cs.primary.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          children: [
                            Icon(_sourceIcon(word.sourceType), size: Adaptive.sp(16), color: cs.primary),
                            SizedBox(width: Adaptive.w(8)),
                            Expanded(
                              child: Text(
                                '${_sourceLabel(word.sourceType)} · ${word.sourceTitle}',
                                style: TextStyle(fontSize: Adaptive.sp(13), color: cs.onSurface),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // 上下文
                    if (word.contextSentence?.isNotEmpty ?? false) ...[
                      SizedBox(height: Adaptive.h(12)),
                      Text('上下文', style: TextStyle(fontSize: Adaptive.sp(14), fontWeight: FontWeight.w700, color: cs.onSurface)),
                      Text(word.contextSentence!, style: TextStyle(fontSize: Adaptive.sp(13), color: cs.onSurfaceVariant, fontStyle: FontStyle.italic)),
                    ],

                    // 学习记录
                    if (word.reviewCount > 0) ...[
                      SizedBox(height: Adaptive.h(12)),
                      Text('学习记录', style: TextStyle(fontSize: Adaptive.sp(14), fontWeight: FontWeight.w700, color: cs.onSurface)),
                      Text('复习 ${word.reviewCount} 次 · 正确率 $accuracy%', style: TextStyle(fontSize: Adaptive.sp(13), color: cs.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
            ),

            // ═══ 底部操作栏：认识 / 不认识 ═══
            if (onRecognized != null || onUnrecognized != null) ...[
              Container(height: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),
              Padding(
                padding: EdgeInsets.fromLTRB(Adaptive.w(16), Adaptive.h(12), Adaptive.w(16), Adaptive.h(16)),
                child: Row(
                  children: [
                    if (onUnrecognized != null)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onUnrecognized,
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: Adaptive.h(10)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Adaptive.r(10))),
                          ),
                          child: Text('不认识', style: TextStyle(fontSize: Adaptive.sp(14))),
                        ),
                      ),
                    if (onRecognized != null && onUnrecognized != null)
                      SizedBox(width: Adaptive.w(12)),
                    if (onRecognized != null)
                      Expanded(
                        child: FilledButton(
                          onPressed: onRecognized,
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: Adaptive.h(10)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Adaptive.r(10))),
                          ),
                          child: Text('认识', style: TextStyle(fontSize: Adaptive.sp(14))),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建测试按钮（测试基调，非购物车）
  Widget _buildTestButton(AppColorsData cs, ColorScheme colorScheme, bool isInBasket, WidgetRef ref) {
    return Material(
      elevation: 0,
      borderRadius: BorderRadius.circular(Adaptive.r(16)),
      child: InkWell(
        onTap: () {
          ref.read(testBasketProvider.notifier).toggle(word);
        },
        borderRadius: BorderRadius.circular(Adaptive.r(16)),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: Adaptive.w(10), vertical: Adaptive.h(5)),
          decoration: BoxDecoration(
            color: isInBasket ? colorScheme.primary.withValues(alpha: 0.15) : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(Adaptive.r(16)),
            border: Border.all(
              color: isInBasket ? colorScheme.primary : cs.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isInBasket ? AppIcons.checkCircle : AppIcons.addCircleOutline,
                size: Adaptive.sp(13),
                color: isInBasket ? colorScheme.primary : cs.onSurfaceVariant,
              ),
              SizedBox(width: Adaptive.w(3)),
              Text(
                isInBasket ? '待测' : '加测',
                style: TextStyle(
                  fontSize: Adaptive.sp(11),
                  fontWeight: FontWeight.w600,
                  color: isInBasket ? colorScheme.primary : cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _morphologyLabel(String key) {
    switch (key) {
      case 'comparative': return '比较级';
      case 'superlative': return '最高级';
      case 'plural': return '复数';
      case 'pastTense': case 'past_tense': return '过去式';
      case 'pastParticiple': case 'past_participle': return '过去分词';
      case 'presentParticiple': case 'present_participle': return '现在分词';
      case 'thirdPerson': case 'third_person': return '第三人称单数';
      default: return key;
    }
  }

  String _sourceLabel(String type) {
    switch (type) {
      case 'video': return '视频';
      case 'article': return '文章';
      case 'music': return '音频';
      default: return '资源';
    }
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
