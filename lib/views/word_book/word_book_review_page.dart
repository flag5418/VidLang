import 'package:flutter/material.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/services/word_book/word_book_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';
import 'package:vidlang/components/dialogs/app_dialogs.dart';
import 'package:vidlang/views/word_book/widgets/review_card.dart';

/// 单词复习页面
///
/// 参考文档：docs/modules/wordbook-design.md 第七节「复习模式」
///
/// 复习流程：
/// 1. 显示单词详情（单词 + 音标 + 释义 + 例句）
/// 2. 用户直接判断认识 / 不认识（无需翻转）
/// 3. 自动进入下一个单词
/// 4. 全部完成后显示统计结果
class WordBookReviewPage extends StatefulWidget {
  final List<WordBook> words;

  const WordBookReviewPage({super.key, required this.words});

  @override
  State<WordBookReviewPage> createState() => _WordBookReviewPageState();
}

class _WordBookReviewPageState extends State<WordBookReviewPage> {
  late List<WordBook> _remaining;
  int _totalCount = 0;

  /// 当前单词（安全访问，列表为空时返回 null）
  WordBook? get _currentWord => _remaining.isEmpty ? null : _remaining.first;

  @override
  void initState() {
    super.initState();
    _remaining = List.of(widget.words);
    _totalCount = widget.words.length;
  }

  void _nextWord({required bool recognized}) async {
    // 先保存当前单词引用，因为 setState 后列表会变化
    final current = _currentWord;
    if (current == null) return;

    await WordBookService.updateMastery(
      wordBookCode: current.code!,
      recognized: recognized,
    );
    if (!mounted) return;

    setState(() {
      _remaining.removeAt(0);
    });

    // 列表为空时显示完成弹窗
    if (_remaining.isEmpty) {
      _showComplete();
    }
  }

  void _showComplete() {
    AppConfirmDialog.show(
      context,
      title: '复习完成',
      content: '已复习 $_totalCount 个单词',
      confirmText: '返回',
      onConfirm: () => Navigator.of(context).pop(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final brightness = Theme.of(context).brightness;
    final progress = _totalCount > 0 ? 1.0 - (_remaining.length / _totalCount) : 0.0;

    // 列表为空时不渲染卡片区域，避免 Bad state: No element
    final word = _currentWord;
    if (word == null) {
      return Scaffold(
        backgroundColor: AppColors.getSurfaceHighest(brightness: brightness),
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.getSurfaceHighest(brightness: brightness),
      body: SafeArea(
        child: Column(
          children: [
            // ── 顶部标题栏 ──
            _buildAppBar(cs, progress),

            // ── 单词详情卡片区域（占据剩余空间） ──
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: Adaptive.w(16)),
                child: ReviewCard(
                  word: word,
                  isFlipped: true,
                ),
              ),
            ),

            // ── 底部操作按钮区（始终可用，带安全区间距） ──
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  Adaptive.w(24),
                  Adaptive.h(12),
                  Adaptive.w(24),
                  Adaptive.h(16),
                ),
                child: _buildJudgmentButtons(cs),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 自定义 AppBar
  Widget _buildAppBar(AppColorsData cs, double progress) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        Adaptive.w(16),
        Adaptive.h(12),
        Adaptive.w(16),
        Adaptive.h(8),
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(AppIcons.arrowBack),
                constraints: BoxConstraints(
                  minWidth: Adaptive.w(36),
                  minHeight: Adaptive.h(36),
                ),
                padding: EdgeInsets.zero,
                tooltip: '返回',
              ),
              SizedBox(width: Adaptive.w(4)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '单词复习',
                    style: TextStyle(
                      fontSize: Adaptive.sp(17),
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    '剩余 ${_remaining.length} / $_totalCount',
                    style: TextStyle(
                      fontSize: Adaptive.sp(12),
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: Icon(AppIcons.close, size: Adaptive.sp(20), color: cs.onSurfaceVariant),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: '关闭',
                constraints: BoxConstraints(
                  minWidth: Adaptive.w(36),
                  minHeight: Adaptive.h(36),
                ),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          SizedBox(height: Adaptive.h(10)),
          LinearProgressIndicator(
            value: progress,
            minHeight: Adaptive.h(4),
            borderRadius: BorderRadius.circular(AppRadius.full),
            backgroundColor: cs.outlineVariant.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
          ),
        ],
      ),
    );
  }

  /// 构建判断按钮（不认识 / 认识）
  Widget _buildJudgmentButtons(AppColorsData cs) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: Adaptive.h(48),
            child: OutlinedButton.icon(
              onPressed: () => _nextWord(recognized: false),
              icon: Icon(AppIcons.close, size: Adaptive.sp(18)),
              label: const Text('不认识'),
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.error,
                side: BorderSide(color: cs.error, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.buttonLarge),
                ),
                textStyle: TextStyle(
                  fontSize: Adaptive.sp(15),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: Adaptive.w(16)),
        Expanded(
          child: SizedBox(
            height: Adaptive.h(48),
            child: FilledButton.icon(
              onPressed: () => _nextWord(recognized: true),
              icon: Icon(AppIcons.check, size: Adaptive.sp(18)),
              label: const Text('认识'),
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.buttonLarge),
                ),
                textStyle: TextStyle(
                  fontSize: Adaptive.sp(15),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
