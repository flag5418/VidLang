import 'package:flutter/material.dart';
import 'package:vidlang/models/word_tag.dart';
import 'package:vidlang/services/word_book/word_tag_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';

/// 标签管理弹窗（重新设计）
///
/// 设计理念 — 参考主流英语学习软件（Anki / 多邻国 / 百词斩）：
/// - ✅ Chip 芯片式选择（而非 Checkbox 列表）
/// - ✅ 已选标签顶部实时展示，可点击取消
/// - ✅ 每个标签有独立颜色标识
/// - ✅ 输入框 + 快捷添加一体化
/// - ✅ 统一使用 AppBaseDialog 基座确保视觉一致性
class CollectionTagManager extends StatefulWidget {
  final String wordCode;
  final List<WordTag> currentTags;

  const CollectionTagManager({
    super.key,
    required this.wordCode,
    required this.currentTags,
  });

  @override
  State<CollectionTagManager> createState() => _CollectionTagManagerState();
}

class _CollectionTagManagerState extends State<CollectionTagManager> {
  late Set<String> _selectedCodes;
  final TextEditingController _newTagController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  /// 标签颜色 — 统一使用主题色，保持朴素严谨风格
  static const Color _tagColor = Color(0xFF3B6EFF); // 主题蓝

  @override
  void initState() {
    super.initState();
    _selectedCodes = widget.currentTags
        .map((t) => t.code)
        .whereType<String>()
        .toSet();
  }

  /// 获取标签颜色（统一主题色）
  Color _colorFor(String name) => _tagColor;

  Future<void> _createTag(String name) async {
    if (name.trim().isEmpty) return;
    final tag = await WordTagService.createTag(name.trim());
    if (tag != null && tag.code != null) {
      setState(() {
        _selectedCodes.add(tag.code!);
      });
      _newTagController.clear();
    }
  }

  void _toggleTag(String? code) {
    if (code == null) return;
    setState(() {
      if (_selectedCodes.contains(code)) {
        _selectedCodes.remove(code);
      } else {
        _selectedCodes.add(code);
      }
    });
  }

  @override
  void dispose() {
    _newTagController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WordTag>>(
      future: WordTagService.listTags(),
      builder: (context, snapshot) {
        final allTags = snapshot.data ?? [];
        final cs = context.colors;

        return Dialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Adaptive.r(20)),
          ),
          insetPadding: EdgeInsets.symmetric(
            horizontal: Adaptive.w(20),
            vertical: Adaptive.h(24),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: Adaptive.w(380),
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ══════════════════════════════════════
                // 头部区域
                // ══════════════════════════════════════
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    Adaptive.w(22),
                    Adaptive.h(20),
                    Adaptive.w(22),
                    Adaptive.h(12),
                  ),
                  child: Row(
                    children: [
                      // 图标背景圆
                      Container(
                        width: Adaptive.w(36),
                        height: Adaptive.w(36),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          AppIcons.tag,
                          size: Adaptive.icon(18),
                          color: cs.primary,
                        ),
                      ),
                      SizedBox(width: Adaptive.w(12)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '管理标签',
                              style: TextStyle(
                                fontSize: Adaptive.sp(17),
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                                letterSpacing: -0.3,
                              ),
                            ),
                            if (_selectedCodes.isNotEmpty)
                              Text(
                                '已选择 ${_selectedCodes.length} 个标签',
                                style: TextStyle(
                                  fontSize: Adaptive.sp(12),
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // 关闭按钮
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: Adaptive.w(32),
                          height: Adaptive.w(32),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            AppIcons.close,
                            size: Adaptive.icon(14),
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ══════════════════════════════════════
                // 已选标签展示区（可点击取消）
                // ══════════════════════════════════════
                if (_selectedCodes.isNotEmpty) ...[
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      Adaptive.w(22),
                      Adaptive.h(4),
                      Adaptive.w(22),
                      Adaptive.h(8),
                    ),
                    child: Wrap(
                      spacing: Adaptive.w(8),
                      runSpacing: Adaptive.h(8),
                      children: _selectedCodes.map((code) {
                        final tag = allTags.where((t) => t.code == code).firstOrNull;
                        if (tag == null) return const SizedBox.shrink();
                        final color = _colorFor(tag.name);
                        return _buildSelectedChip(tag, color);
                      }).toList(),
                    ),
                  ),
                  Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.2)),
                ],

                // ══════════════════════════════════════
                // 可选标签列表（Chip 式）
                // ══════════════════════════════════════
                Flexible(
                  child: allTags.isEmpty
                      ? _buildEmptyState(context)
                      : _buildTagList(context, allTags),
                ),

                Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.2)),

                // ══════════════════════════════════════
                // 新建标签输入区
                // ══════════════════════════════════════
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    Adaptive.w(22),
                    Adaptive.h(14),
                    Adaptive.w(22),
                    0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newTagController,
                          focusNode: _focusNode,
                          style: TextStyle(
                            fontSize: Adaptive.sp(14),
                            color: cs.onSurface,
                          ),
                          onSubmitted: (_) =>
                              _createTag(_newTagController.text),
                          decoration: InputDecoration(
                            hintText: '输入新标签名称...',
                            hintStyle: TextStyle(
                              fontSize: Adaptive.sp(13),
                              color: cs.outline,
                            ),
                            isDense: true,
                            filled: true,
                            fillColor: cs.surfaceContainerLow,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: Adaptive.w(14),
                              vertical: Adaptive.h(11),
                            ),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(Adaptive.r(12)),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(Adaptive.r(12)),
                              borderSide: BorderSide(
                                  color: cs.primary, width: 1.5),
                            ),
                            suffixIcon: _newTagController.text.isNotEmpty
                                ? GestureDetector(
                                    onTap: () {
                                      _createTag(_newTagController.text);
                                    },
                                    child: Container(
                                      margin: EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: cs.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        AppIcons.add,
                                        size: Adaptive.icon(16),
                                        color: AppColors.onPrimary,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ══════════════════════════════════════
                // 底部按钮
                // ══════════════════════════════════════
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    Adaptive.w(22),
                    Adaptive.h(16),
                    Adaptive.w(22),
                    Adaptive.h(20),
                  ),
                  child: Row(
                    children: [
                      // 取消按钮
                      Expanded(
                        child: SizedBox(
                          height: Adaptive.h(46),
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: cs.onSurfaceVariant,
                              side: BorderSide(color: cs.outlineVariant),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(Adaptive.r(14)),
                              ),
                              textStyle: TextStyle(
                                fontSize: Adaptive.sp(15),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            child: const Text('取消'),
                          ),
                        ),
                      ),
                      SizedBox(width: Adaptive.w(12)),
                      // 确定按钮
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: Adaptive.h(46),
                          child: FilledButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              await WordTagService.replaceTags(
                                widget.wordCode,
                                _selectedCodes.toList(),
                              );
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: cs.primary,
                              foregroundColor: AppColors.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(Adaptive.r(14)),
                              ),
                              textStyle: TextStyle(
                                fontSize: Adaptive.sp(15),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: Text('保存 (${_selectedCodes.length})'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 已选标签 Chip（带删除 ×）
  Widget _buildSelectedChip(WordTag tag, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: Adaptive.w(10), vertical: Adaptive.h(5)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Adaptive.r(999)),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 颜色圆点
          Container(
            width: Adaptive.w(7),
            height: Adaptive.w(7),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: Adaptive.w(6)),
          // 标签名
          Text(
            tag.name,
            style: TextStyle(
              fontSize: Adaptive.sp(13),
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          SizedBox(width: Adaptive.w(4)),
          // 删除按钮
          GestureDetector(
            onTap: () => _toggleTag(tag.code),
            child: Icon(
              Icons.close_rounded,
              size: Adaptive.sp(14),
              color: color.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  /// 可选标签列表（Chip 式选择）
  Widget _buildTagList(BuildContext context, List<WordTag> tags) {
    final cs = context.colors;

    // 分离：未选中的在前，已选中的在后（或用视觉区分）
    final unselectedTags =
        tags.where((t) => !_selectedCodes.contains(t.code)).toList();
    final selectedTags =
        tags.where((t) => _selectedCodes.contains(t.code)).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        Adaptive.w(22),
        Adaptive.h(12),
        Adaptive.w(22),
        Adaptive.h(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 未选中标签
          if (unselectedTags.isNotEmpty) ...[
            ...unselectedTags.map((tag) => Padding(
                  padding: EdgeInsets.only(bottom: Adaptive.h(6)),
                  child: _buildSelectableTile(tag, isSelected: false),
                )),
          ],
          // 已选中标签（视觉上区分）
          if (selectedTags.isNotEmpty) ...[
            if (unselectedTags.isNotEmpty) ...[
              SizedBox(height: Adaptive.h(8)),
              Padding(
                padding: EdgeInsets.only(bottom: Adaptive.h(8)),
                child: Text(
                  '✓ 已选中',
                  style: TextStyle(
                    fontSize: Adaptive.sp(11),
                    fontWeight: FontWeight.w600,
                    color: cs.primary.withValues(alpha: 0.7),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
            ...selectedTags.map((tag) => Padding(
                  padding: EdgeInsets.only(bottom: Adaptive.h(6)),
                  child: _buildSelectableTile(tag, isSelected: true),
                )),
          ],
        ],
      ),
    );
  }

  /// 单个可选标签行
  Widget _buildSelectableTile(WordTag tag, {required bool isSelected}) {
    final cs = context.colors;
    final color = _colorFor(tag.name);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Adaptive.r(12)),
        onTap: tag.code == null ? null : () => _toggleTag(tag.code),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: Adaptive.w(14),
            vertical: Adaptive.h(11),
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(Adaptive.r(12)),
            border: Border.all(
              color: isSelected ? color.withValues(alpha: 0.3) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // 选择指示器
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: Adaptive.w(22),
                height: Adaptive.w(22),
                decoration: BoxDecoration(
                  color: isSelected ? color : Colors.transparent,
                  borderRadius: BorderRadius.circular(Adaptive.r(6)),
                  border: Border.all(
                    color: isSelected ? color : cs.outlineVariant,
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? Icon(Icons.check_rounded,
                        size: Adaptive.sp(14), color: AppColors.onPrimary)
                    : null,
              ),
              SizedBox(width: Adaptive.w(12)),
              // 颜色标识
              Container(
                width: Adaptive.w(10),
                height: Adaptive.w(10),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: Adaptive.w(10)),
              // 标签名
              Expanded(
                child: Text(
                  tag.name,
                  style: TextStyle(
                    fontSize: Adaptive.sp(14),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? color : cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 空状态
  Widget _buildEmptyState(BuildContext context) {
    final cs = context.colors;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Adaptive.h(32)),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: Adaptive.w(48),
              height: Adaptive.w(48),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: Icon(AppIcons.tag,
                  size: Adaptive.icon(22), color: cs.outline),
            ),
            SizedBox(height: Adaptive.h(12)),
            Text(
              '还没有标签',
              style: TextStyle(
                fontSize: Adaptive.sp(14),
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant,
              ),
            ),
            SizedBox(height: Adaptive.h(4)),
            Text(
              '在下方输入框创建你的第一个标签',
              style: TextStyle(
                fontSize: Adaptive.sp(12),
                color: cs.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
