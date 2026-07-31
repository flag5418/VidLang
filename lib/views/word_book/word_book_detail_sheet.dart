import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/models/word_tag.dart';
import 'package:vidlang/providers/test_basket_provider.dart';
import 'package:vidlang/services/word_book/word_book_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';

/// 手机模式下的单词详情弹窗（BottomSheet）
///
/// V3.1 变更：
/// - 使用 ConsumerWidget 实现实时状态更新
/// - 图标和文案改为测试基调
class WordBookDetailSheet extends ConsumerWidget {
  final WordBook word;
  final List<WordTag> tags;
  final VoidCallback onRecognized;
  final VoidCallback onUnrecognized;
  final VoidCallback? onDelete;

  const WordBookDetailSheet({
    super.key,
    required this.word,
    required this.tags,
    required this.onRecognized,
    required this.onUnrecognized,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final definitions = WordBookService.parseDefinitions(word.definitionsJson);
    final morphology = WordBookService.parseMorphology(word.morphologyJson);
    final accuracy = word.reviewCount == 0 ? 0 : (word.correctCount * 100 ~/ word.reviewCount);

    // 实时监听测试篮状态
    final basketState = ref.watch(testBasketProvider);
    final isInBasket = basketState.isSelected(word.code ?? '');

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(Adaptive.w(16), Adaptive.h(12), Adaptive.w(16), Adaptive.h(16)),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: Adaptive.w(40),
                  height: Adaptive.h(4),
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(Adaptive.r(999)),
                  ),
                ),
              ),
              SizedBox(height: Adaptive.h(16)),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      word.word,
                      style: TextStyle(
                        fontSize: Adaptive.sp(26),
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  // 加入测试按钮（实时状态）
                  _buildTestButton(colorScheme, isInBasket, ref),
                  SizedBox(width: Adaptive.w(8)),
                  if (onDelete != null)
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(AppIcons.delete),
                    ),
                ],
              ),
              if ((word.phoneticUk ?? word.phoneticUs)?.isNotEmpty ?? false)
                Text(
                  '/${word.phoneticUk ?? word.phoneticUs}/',
                  style: TextStyle(fontSize: Adaptive.sp(15), color: colorScheme.onSurfaceVariant),
                ),
              SizedBox(height: Adaptive.h(16)),
              if (definitions.isNotEmpty) ...[
                _buildSectionTitle(context, '释义'),
                ...definitions.map(
                  (definition) => Padding(
                    padding: EdgeInsets.only(bottom: Adaptive.h(8)),
                    child: Text(
                      '${definition.partOfSpeech != null ? '${definition.partOfSpeech}. ' : ''}${definition.meaning}',
                      style: TextStyle(fontSize: Adaptive.sp(14), color: colorScheme.onSurface),
                    ),
                  ),
                ),
                SizedBox(height: Adaptive.h(8)),
              ],
              if (definitions.any((d) => d.example != null && d.example!.isNotEmpty)) ...[
                _buildDivider(context),
                _buildSectionTitle(context, '例句'),
                ...definitions.where((d) => d.example != null && d.example!.isNotEmpty).map(
                  (definition) => Padding(
                    padding: EdgeInsets.only(bottom: Adaptive.h(8)),
                    child: Text(
                      '• ${definition.example}',
                      style: TextStyle(fontSize: Adaptive.sp(14), color: colorScheme.onSurface),
                    ),
                  ),
                ),
                SizedBox(height: Adaptive.h(8)),
              ],
              if (morphology.isNotEmpty) ...[
                _buildDivider(context),
                _buildSectionTitle(context, '词形变化'),
                ...morphology.entries.map(
                  (entry) => Padding(
                    padding: EdgeInsets.only(bottom: Adaptive.h(6)),
                    child: Text(
                      '${_morphologyLabel(entry.key)}: ${entry.value}',
                      style: TextStyle(fontSize: Adaptive.sp(14), color: colorScheme.onSurface),
                    ),
                  ),
                ),
                SizedBox(height: Adaptive.h(8)),
              ],
              if ((word.mnemonic ?? '').isNotEmpty) ...[
                _buildDivider(context),
                _buildSectionTitle(context, '助记'),
                Text(
                  word.mnemonic!,
                  style: TextStyle(fontSize: Adaptive.sp(14), color: colorScheme.onSurface),
                ),
                SizedBox(height: Adaptive.h(8)),
              ],
              if (word.contextSentence?.isNotEmpty ?? false) ...[
                _buildDivider(context),
                _buildSectionTitle(context, '来源上下文'),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(Adaptive.r(12)),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(Adaptive.r(14)),
                  ),
                  child: Text(
                    word.contextSentence!,
                    style: TextStyle(fontSize: Adaptive.sp(14), color: colorScheme.onSurface),
                  ),
                ),
                SizedBox(height: Adaptive.h(12)),
              ],
              if ((word.sourceTitle ?? '').isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: Adaptive.h(12)),
                  child: Text(
                    '来源：${word.sourceTitle}',
                    style: TextStyle(fontSize: Adaptive.sp(13), color: colorScheme.onSurfaceVariant),
                  ),
                ),
              if (tags.isNotEmpty) ...[
                _buildDivider(context),
                _buildSectionTitle(context, '标签'),
                Wrap(
                  spacing: Adaptive.w(8),
                  runSpacing: Adaptive.h(8),
                  children: tags
                      .map(
                        (tag) => Container(
                          padding: EdgeInsets.symmetric(horizontal: Adaptive.w(10), vertical: Adaptive.h(5)),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(Adaptive.r(999)),
                          ),
                          child: Text(
                            tag.name,
                            style: TextStyle(fontSize: Adaptive.sp(12), color: colorScheme.primary),
                          ),
                        ),
                      )
                      .toList(),
                ),
                SizedBox(height: Adaptive.h(12)),
              ],
              _buildDivider(context),
              _buildSectionTitle(context, '学习记录'),
              Text(
                '复习 ${word.reviewCount} 次 · 正确率 $accuracy%',
                style: TextStyle(fontSize: Adaptive.sp(13), color: colorScheme.onSurfaceVariant),
              ),
              SizedBox(height: Adaptive.h(18)),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onUnrecognized,
                      child: const Text('不认识'),
                    ),
                  ),
                  SizedBox(width: Adaptive.w(12)),
                  Expanded(
                    child: FilledButton(
                      onPressed: onRecognized,
                      child: const Text('认识'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建测试按钮（测试基调）
  Widget _buildTestButton(ColorScheme colorScheme, bool isInBasket, WidgetRef ref) {
    return Material(
      elevation: 0,
      borderRadius: BorderRadius.circular(Adaptive.r(20)),
      child: InkWell(
        onTap: () {
          ref.read(testBasketProvider.notifier).toggle(word);
        },
        borderRadius: BorderRadius.circular(Adaptive.r(20)),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: Adaptive.w(12),
            vertical: Adaptive.h(6),
          ),
          decoration: BoxDecoration(
            color: isInBasket ? colorScheme.primary.withValues(alpha: 0.15) : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(Adaptive.r(20)),
            border: Border.all(
              color: isInBasket ? colorScheme.primary : colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isInBasket ? AppIcons.checkCircle : AppIcons.addCircleOutline,
                size: Adaptive.sp(14),
                color: isInBasket ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
              SizedBox(width: Adaptive.w(4)),
              Text(
                isInBasket ? '待测' : '加测',
                style: TextStyle(
                  fontSize: Adaptive.sp(12),
                  fontWeight: FontWeight.w600,
                  color: isInBasket ? colorScheme.primary : colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: Adaptive.h(8)),
      child: Text(
        title,
        style: TextStyle(
          fontSize: Adaptive.sp(14),
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Adaptive.h(12)),
      child: Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
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
}
