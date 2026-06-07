/// 生词本页面
///
/// 展示用户收藏的所有生词，支持：
/// - 按来源类型筛选（视频/文章/音频）
/// - 按掌握程度筛选
/// - 单词详情（释义、音标、上下文）
/// - 复习模式（间隔重复）
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/theme/app_spacing.dart';
import 'package:vidlang/theme/app_typography.dart';
import 'package:vidlang/utils/responsive_size.dart';

/// 生词本页面
class WordBookPage extends ConsumerStatefulWidget {
  const WordBookPage({super.key});

  @override
  ConsumerState<WordBookPage> createState() => _WordBookPageState();
}

class _WordBookPageState extends ConsumerState<WordBookPage> {
  List<WordBook> _words = [];
  bool _loading = true;
  String _filterSource = 'all'; // all / video / article / music
  String _filterMastery = 'all'; // all / learning / reviewing / mastered

  String _masteryLabel(String value) {
    switch (value) {
      case 'mastered':
        return '已掌握';
      case 'reviewing':
        return '复习中';
      case 'learning':
        return '学习中';
      default:
        return value;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    setState(() => _loading = true);
    try {
      String? where;
      List<Object?>? whereArgs;

      final conditions = <String>['is_deleted = 0'];
      final args = <Object?>[];

      if (_filterSource != 'all') {
        conditions.add('source_type = ?');
        args.add(_filterSource);
      }
      if (_filterMastery != 'all') {
        conditions.add('mastery_level = ?');
        args.add(_filterMastery);
      }

      where = conditions.join(' AND ');
      whereArgs = args;

      final rows = await DatabaseService.findByCondition(
        () => WordBook(),
        where: where,
        whereArgs: whereArgs,
        orderBy: 'next_review_at ASC, created_at DESC',
      );

      if (!mounted) return;
      setState(() {
        _words = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Row(
                children: [
                  Text(
                    '生词本',
                    style: TextStyle(fontSize: ResponsiveSize.fontSize(context, AppTypography.fontSizeLarge), fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      '${_words.length}',
                      style: TextStyle(fontSize: ResponsiveSize.fontSize(context, 12), fontWeight: FontWeight.w600, color: colorScheme.primary),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.sm),
              // 筛选栏
              _buildFilterBar(colorScheme),
              SizedBox(height: AppSpacing.md),
              // 单词列表
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _words.isEmpty
                    ? _buildEmptyState(colorScheme)
                    : _buildWordList(colorScheme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar(ColorScheme colorScheme) {
    return Column(
      children: [
        // 来源筛选
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip('全部', 'all', _filterSource, (v) {
                setState(() => _filterSource = v);
                _loadWords();
              }, colorScheme),
              SizedBox(width: 8),
              _filterChip('🎬 视频', 'video', _filterSource, (v) {
                setState(() => _filterSource = v);
                _loadWords();
              }, colorScheme),
              SizedBox(width: 8),
              _filterChip('📄 文章', 'article', _filterSource, (v) {
                setState(() => _filterSource = v);
                _loadWords();
              }, colorScheme),
              SizedBox(width: 8),
              _filterChip('🎵 音频', 'music', _filterSource, (v) {
                setState(() => _filterSource = v);
                _loadWords();
              }, colorScheme),
            ],
          ),
        ),
        SizedBox(height: 8),
        // 掌握程度筛选
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip(
                '全部掌握度',
                'all',
                _filterMastery,
                (v) {
                  setState(() => _filterMastery = v);
                  _loadWords();
                },
                colorScheme,
                small: true,
              ),
              SizedBox(width: 8),
              _filterChip(
                '🔵 学习中',
                'learning',
                _filterMastery,
                (v) {
                  setState(() => _filterMastery = v);
                  _loadWords();
                },
                colorScheme,
                small: true,
              ),
              SizedBox(width: 8),
              _filterChip(
                '🟡 复习中',
                'reviewing',
                _filterMastery,
                (v) {
                  setState(() => _filterMastery = v);
                  _loadWords();
                },
                colorScheme,
                small: true,
              ),
              SizedBox(width: 8),
              _filterChip(
                '🟢 已掌握',
                'mastered',
                _filterMastery,
                (v) {
                  setState(() => _filterMastery = v);
                  _loadWords();
                },
                colorScheme,
                small: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value, String current, Function(String) onTap, ColorScheme colorScheme, {bool small = false}) {
    final isSelected = value == current;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: small ? 12 : 16, vertical: small ? 6 : 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ResponsiveSize.fontSize(context, small ? 12 : 13),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book, size: ResponsiveSize.icon(context) * 2, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
          SizedBox(height: AppSpacing.md),
          Text('暂无收藏的生词', style: TextStyle(fontSize: ResponsiveSize.fontSize(context, 14), color: colorScheme.onSurfaceVariant)),
          SizedBox(height: 4),
          Text('在字幕里长按划词即可加入生词本', style: TextStyle(fontSize: ResponsiveSize.fontSize(context, 13), color: colorScheme.outline)),
        ],
      ),
    );
  }

  Widget _buildWordList(ColorScheme colorScheme) {
    return ListView.separated(
      itemCount: _words.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.1)),
      itemBuilder: (context, index) {
        final word = _words[index];
        return _buildWordItem(word, colorScheme);
      },
    );
  }

  Widget _buildWordItem(WordBook word, ColorScheme colorScheme) {
    final masteryColor = word.masteryLevel == 'mastered'
        ? Colors.green
        : word.masteryLevel == 'reviewing'
        ? Colors.orange
        : colorScheme.primary;

    return InkWell(
      onTap: () => _showWordDetail(word),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            // 掌握程度指示器
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: masteryColor),
            ),
            SizedBox(width: 12),
            // 单词信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word.word,
                    style: TextStyle(fontSize: ResponsiveSize.fontSize(context, 16), fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                  ),
                  SizedBox(height: 2),
                  if (word.phoneticUk != null || word.phoneticUs != null)
                    Text(
                      '英: ${word.phoneticUk ?? '-'}  美: ${word.phoneticUs ?? '-'}',
                      style: TextStyle(fontSize: ResponsiveSize.fontSize(context, 12), color: colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            // 来源类型
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: colorScheme.surfaceContainerHighest),
              child: Text(_sourceLabel(word.sourceType), style: TextStyle(fontSize: ResponsiveSize.fontSize(context, 11), color: colorScheme.onSurfaceVariant)),
            ),
            SizedBox(width: 8),
            // 复习次数
            Text('复习 ${word.reviewCount} 次', style: TextStyle(fontSize: ResponsiveSize.fontSize(context, 12), color: colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  String _sourceLabel(String type) {
    switch (type) {
      case 'video':
        return '🎬';
      case 'article':
        return '📄';
      case 'music':
        return '🎵';
      default:
        return '📖';
    }
  }

  void _showWordDetail(WordBook word) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.3,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: colorScheme.outlineVariant),
                ),
              ),
              SizedBox(height: 20),
              Text(
                word.word,
                style: TextStyle(fontSize: ResponsiveSize.fontSize(context, 28), fontWeight: FontWeight.bold, color: colorScheme.onSurface),
              ),
              if (word.phoneticUk != null || word.phoneticUs != null) ...[
                SizedBox(height: 8),
                Text(
                  '英: /${word.phoneticUk ?? '-'}/  美: /${word.phoneticUs ?? '-'}/',
                  style: TextStyle(fontSize: ResponsiveSize.fontSize(context, 16), color: colorScheme.onSurfaceVariant),
                ),
              ],
              SizedBox(height: 16),
              if (word.contextSentence != null && word.contextSentence!.isNotEmpty) ...[
                Text(
                  '上下文',
                  style: TextStyle(fontSize: ResponsiveSize.fontSize(context, 13), fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant),
                ),
                SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: colorScheme.surfaceContainerHighest),
                  child: Text(word.contextSentence!, style: TextStyle(fontSize: ResponsiveSize.fontSize(context, 14), color: colorScheme.onSurface)),
                ),
              ],
              SizedBox(height: 16),
              Row(
                children: [
                  _infoChip('难度：${word.difficulty}/5', colorScheme),
                  SizedBox(width: 8),
                  _infoChip('复习：${word.reviewCount}', colorScheme),
                  SizedBox(width: 8),
                  _infoChip(
                    '正确率：${word.correctCount > 0 ? (word.correctCount * 100 ~/ (word.reviewCount == 0 ? 1 : word.reviewCount)) : 0}%',
                    colorScheme,
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                '掌握度：${_masteryLabel(word.masteryLevel)}',
                style: TextStyle(
                  fontSize: ResponsiveSize.fontSize(context, 14),
                  fontWeight: FontWeight.w600,
                  color: word.masteryLevel == 'mastered'
                      ? Colors.green
                      : word.masteryLevel == 'reviewing'
                      ? Colors.orange
                      : colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(String label, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: colorScheme.surfaceContainerHighest),
      child: Text(label, style: TextStyle(fontSize: ResponsiveSize.fontSize(context, 12), color: colorScheme.onSurfaceVariant)),
    );
  }
}
