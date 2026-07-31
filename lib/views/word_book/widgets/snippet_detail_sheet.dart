import 'package:flutter/material.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/models/word_tag.dart';
import 'package:vidlang/services/tts/tts_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';

/// 生词本句子详情底部弹窗
///
/// 重新设计要点：
/// - 统一使用 DesignTokens 间距/圆角规范
/// - 标签区域采用 Chip 式展示（带颜色+可点击删除）
/// - 操作按钮区域视觉强化
/// - 信息层次更清晰（原文卡片化、来源行内展示）
class SnippetDetailSheet extends StatefulWidget {
  final WordBook snippet;
  final List<WordTag> tags;
  final VoidCallback onRecognized;
  final VoidCallback onUnrecognized;
  final VoidCallback? onDelete;
  final void Function(String note)? onNoteChanged;
  final VoidCallback? onEditTags;
  /// 是否已在测试篮中
  final bool isInBasket;
  /// 切换测试篮状态回调
  final VoidCallback? onToggleBasket;

  const SnippetDetailSheet({
    super.key,
    required this.snippet,
    required this.tags,
    required this.onRecognized,
    required this.onUnrecognized,
    this.onDelete,
    this.onNoteChanged,
    this.onEditTags,
    this.isInBasket = false,
    this.onToggleBasket,
  });

  @override
  State<SnippetDetailSheet> createState() => _SnippetDetailSheetState();
}

class _SnippetDetailSheetState extends State<SnippetDetailSheet> {
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.snippet.note ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final snippet = widget.snippet;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(Adaptive.w(20), Adaptive.h(16), Adaptive.w(20), Adaptive.h(24)),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 拖拽指示条 ──
              Center(
                child: Container(
                  width: Adaptive.w(40),
                  height: Adaptive.h(4),
                  decoration: BoxDecoration(
                    color: cs.outlineVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(Adaptive.r(999)),
                  ),
                ),
              ),
              SizedBox(height: Adaptive.h(20)),

              // ── 头部：标题 + 操作按钮 ──
              _buildHeader(context, snippet),

              SizedBox(height: Adaptive.h(20)),

              // ── 原文卡片 ──
              if ((snippet.sourceText ?? '').isNotEmpty) ...[
                _buildSourceCard(context, snippet),
                SizedBox(height: Adaptive.h(16)),
              ],

              // ── 翻译卡片 ──
              if ((snippet.sourceTranslation ?? '').isNotEmpty) ...[
                _buildTranslationCard(context, snippet),
                SizedBox(height: Adaptive.h(16)),
              ],

              // ── 来源 + 时间 行 ──
              _buildMetaRow(context, snippet),
              SizedBox(height: Adaptive.h(8)),
              _buildDivider(context),

              // ── 标签区域（Chip 式设计）──
              _buildTagsSection(context),
              SizedBox(height: Adaptive.h(8)),
              _buildDivider(context),

              // ── 备注 ──
              _buildNotesSection(context),
              SizedBox(height: Adaptive.h(20)),

              // ── 学习记录 ──
              _buildLearningStats(context, snippet),
              SizedBox(height: Adaptive.h(24)),

              // ── 底部操作按钮 ──
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  /// 头部区域：标题 + 朗读 + 删除
  Widget _buildHeader(BuildContext context, WordBook snippet) {
    final cs = context.colors;
    return Row(
      children: [
        Expanded(
          child: Text(
            '句子详情',
            style: TextStyle(
              fontSize: Adaptive.sp(18),
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
              letterSpacing: -0.3,
            ),
          ),
        ),
        // 朗读按钮
        _buildIconButton(
          context,
          icon: AppIcons.volumeUp,
          tooltip: '朗读',
          onTap: () {
            final text = (snippet.sourceText ?? '').isNotEmpty
                ? snippet.sourceText!
                : snippet.word;
            TtsService().speakSubtitle(text);
          },
        ),
        // 加入测试篮按钮
        if (widget.onToggleBasket != null) ...[
          SizedBox(width: Adaptive.w(8)),
          Material(
            elevation: 0,
            borderRadius: BorderRadius.circular(Adaptive.r(20)),
            child: InkWell(
              onTap: widget.onToggleBasket,
              borderRadius: BorderRadius.circular(Adaptive.r(20)),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: Adaptive.w(12),
                  vertical: Adaptive.h(6),
                ),
                decoration: BoxDecoration(
                  color: widget.isInBasket
                      ? cs.primaryContainer.withValues(alpha: 0.5)
                      : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(Adaptive.r(20)),
                  border: Border.all(
                    color: widget.isInBasket
                        ? cs.primary
                        : cs.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.isInBasket ? AppIcons.check : AppIcons.add,
                      size: Adaptive.sp(14),
                      color: widget.isInBasket ? cs.primary : cs.onSurfaceVariant,
                    ),
                    SizedBox(width: Adaptive.w(4)),
                    Text(
                      widget.isInBasket ? '已加入' : '测试',
                      style: TextStyle(
                        fontSize: Adaptive.sp(12),
                        fontWeight: FontWeight.w600,
                        color: widget.isInBasket ? cs.primary : cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        if (widget.onDelete != null) ...[
          SizedBox(width: Adaptive.w(8)),
          // 删除按钮
          _buildIconButton(
            context,
            icon: AppIcons.delete,
            tooltip: '删除',
            isDestructive: true,
            onTap: widget.onDelete!,
          ),
        ],
      ],
    );
  }

  /// 圆形图标按钮（统一样式）
  Widget _buildIconButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final cs = context.colors;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(Adaptive.r(20)),
          onTap: onTap,
          child: Container(
            width: Adaptive.w(40),
            height: Adaptive.w(40),
            decoration: BoxDecoration(
              color: isDestructive
                  ? cs.errorContainer.withValues(alpha: 0.5)
                  : cs.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: Adaptive.icon(18),
              color: isDestructive ? cs.error : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  /// 原文卡片
  Widget _buildSourceCard(BuildContext context, WordBook snippet) {
    final cs = context.colors;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Adaptive.r(16)),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(Adaptive.r(16)),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Text(
        snippet.sourceText!,
        style: TextStyle(
          fontSize: Adaptive.sp(16),
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
          height: 1.6,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  /// 翻译卡片
  Widget _buildTranslationCard(BuildContext context, WordBook snippet) {
    final cs = context.colors;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Adaptive.r(14)),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Adaptive.r(14)),
      ),
      child: Text(
        snippet.sourceTranslation!,
        style: TextStyle(
          fontSize: Adaptive.sp(14),
          color: cs.onSurfaceVariant,
          height: 1.6,
        ),
      ),
    );
  }

  /// 元信息行：来源 + 收藏时间
  Widget _buildMetaRow(BuildContext context, WordBook snippet) {
    final cs = context.colors;
    return Row(
      children: [
        // 来源图标 + 名称
        if ((snippet.sourceTitle ?? '').isNotEmpty) ...[
          Icon(
            _sourceIcon(snippet.sourceType),
            size: Adaptive.sp(14),
            color: cs.primary.withValues(alpha: 0.7),
          ),
          SizedBox(width: Adaptive.w(4)),
          Text(
            snippet.sourceTitle!,
            style: TextStyle(
              fontSize: Adaptive.sp(13),
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
        // 收藏时间
        if (snippet.createdAt != null) ...[
          if ((snippet.sourceTitle ?? '').isNotEmpty)
            Text(
              ' · ',
              style: TextStyle(fontSize: Adaptive.sp(13), color: cs.outline),
            ),
          Text(
            _formatDate(snippet.createdAt!),
            style: TextStyle(fontSize: Adaptive.sp(12), color: cs.outline),
          ),
        ],
      ],
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

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 标签区域 — Chip 式设计
  Widget _buildTagsSection(BuildContext context) {
    final cs = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 区块标题行
        Row(
          children: [
            Icon(AppIcons.tag, size: Adaptive.sp(15), color: cs.onSurfaceVariant),
            SizedBox(width: Adaptive.w(6)),
            Text(
              '标签',
              style: TextStyle(
                fontSize: Adaptive.sp(14),
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            if (widget.tags.isNotEmpty) ...[
              SizedBox(width: Adaptive.w(6)),
              Container(
                padding: EdgeInsets.symmetric(horizontal: Adaptive.w(7), vertical: Adaptive.h(1)),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(Adaptive.r(10)),
                ),
                child: Text(
                  '${widget.tags.length}',
                  style: TextStyle(
                    fontSize: Adaptive.sp(11),
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: Adaptive.h(12)),

        // 标签 Chip 列表 或空状态
        if (widget.tags.isEmpty)
          _buildEmptyTagsHint(context)
        else
          Wrap(
            spacing: Adaptive.w(8),
            runSpacing: Adaptive.h(10),
            children: widget.tags.map((tag) => _buildTagChip(context, tag)).toList(),
          ),

        SizedBox(height: Adaptive.h(14)),

        // 编辑标签入口
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: widget.onEditTags,
            icon: Icon(AppIcons.edit, size: Adaptive.sp(16)),
            label: const Text('编辑标签'),
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.primary,
              side: BorderSide(color: cs.primary.withValues(alpha: 0.3)),
              padding: EdgeInsets.symmetric(vertical: Adaptive.h(11)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Adaptive.r(12)),
              ),
              textStyle: TextStyle(
                fontSize: Adaptive.sp(14),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 单个标签 Chip（朴素主题色风格）
  Widget _buildTagChip(BuildContext context, WordTag tag) {
    final cs = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: Adaptive.w(12), vertical: Adaptive.h(5)),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(Adaptive.r(999)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            AppIcons.tag,
            size: Adaptive.sp(12),
            color: cs.primary.withValues(alpha: 0.7),
          ),
          SizedBox(width: Adaptive.w(5)),
          Text(
            tag.name,
            style: TextStyle(
              fontSize: Adaptive.sp(13),
              fontWeight: FontWeight.w500,
              color: cs.primary,
            ),
          ),
        ],
      ),
    );
  }

  /// 空标签提示
  Widget _buildEmptyTagsHint(BuildContext context) {
    final cs = context.colors;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: Adaptive.h(16)),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Adaptive.r(12)),
      ),
      child: Center(
        child: Text(
          '暂无标签，点击下方添加',
          style: TextStyle(
            fontSize: Adaptive.sp(13),
            color: cs.outline,
          ),
        ),
      ),
    );
  }

  /// 备注区域
  Widget _buildNotesSection(BuildContext context) {
    final cs = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(AppIcons.edit, size: Adaptive.sp(15), color: cs.onSurfaceVariant),
            SizedBox(width: Adaptive.w(6)),
            Text(
              '备注',
              style: TextStyle(
                fontSize: Adaptive.sp(14),
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
        SizedBox(height: Adaptive.h(10)),
        TextField(
          controller: _noteController,
          maxLines: 3,
          minLines: 2,
          onChanged: (value) => widget.onNoteChanged?.call(value),
          style: TextStyle(
            fontSize: Adaptive.sp(14),
            color: cs.onSurface,
          ),
          decoration: InputDecoration(
            hintText: '添加备注...',
            hintStyle: TextStyle(
              fontSize: Adaptive.sp(13),
              color: cs.outline,
            ),
            filled: true,
            fillColor: cs.surfaceContainerLow,
            contentPadding: EdgeInsets.symmetric(
              horizontal: Adaptive.w(14),
              vertical: Adaptive.h(12),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Adaptive.r(12)),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Adaptive.r(12)),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Adaptive.r(12)),
              borderSide: BorderSide(color: cs.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  /// 学习统计
  Widget _buildLearningStats(BuildContext context, WordBook snippet) {
    final cs = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(AppIcons.history, size: Adaptive.sp(15), color: cs.onSurfaceVariant),
            SizedBox(width: Adaptive.w(6)),
            Text(
              '学习记录',
              style: TextStyle(
                fontSize: Adaptive.sp(14),
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
        SizedBox(height: Adaptive.h(10)),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(Adaptive.r(14)),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(Adaptive.r(12)),
          ),
          child: Row(
            children: [
              Icon(
                AppIcons.repeat,
                size: Adaptive.sp(18),
                color: cs.primary.withValues(alpha: 0.7),
              ),
              SizedBox(width: Adaptive.w(10)),
              Text(
                '复习 ${snippet.reviewCount} 次',
                style: TextStyle(
                  fontSize: Adaptive.sp(14),
                  color: cs.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (snippet.reviewCount > 0) ...[
                SizedBox(width: Adaptive.w(4)),
                Text(
                  '·',
                  style: TextStyle(fontSize: Adaptive.sp(14), color: cs.outline),
                ),
                SizedBox(width: Adaptive.w(4)),
                Text(
                  '正确率 ${snippet.correctCount * 100 ~/ snippet.reviewCount}%',
                  style: TextStyle(
                    fontSize: Adaptive.sp(14),
                    color: snippet.correctCount * 100 ~/ snippet.reviewCount >= 80
                        ? AppColors.success
                        : cs.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 底部操作按钮
  Widget _buildActionButtons(BuildContext context) {
    final cs = context.colors;
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: Adaptive.h(48),
            child: OutlinedButton(
              onPressed: widget.onUnrecognized,
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.onSurfaceVariant,
                side: BorderSide(color: cs.outlineVariant),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Adaptive.r(14)),
                ),
                textStyle: TextStyle(
                  fontSize: Adaptive.sp(15),
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('不认识'),
            ),
          ),
        ),
        SizedBox(width: Adaptive.w(14)),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: Adaptive.h(48),
            child: FilledButton(
              onPressed: widget.onRecognized,
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Adaptive.r(14)),
                ),
                textStyle: TextStyle(
                  fontSize: Adaptive.sp(15),
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('认识'),
            ),
          ),
        ),
      ],
    );
  }

  /// 分割线
  Widget _buildDivider(BuildContext context) {
    final cs = context.colors;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Adaptive.h(16)),
      child: Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.25)),
    );
  }
}
