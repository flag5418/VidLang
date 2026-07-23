import 'package:flutter/material.dart';
import 'package:vidlang/models/word_tag.dart';
import 'package:vidlang/services/word_book/word_tag_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';

/// 标签管理弹窗
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

  @override
  void initState() {
    super.initState();
    _selectedCodes = widget.currentTags
        .map((t) => t.code)
        .whereType<String>()
        .toSet();
  }

  Future<void> _createTag(String name) async {
    if (name.isEmpty) return;
    final tag = await WordTagService.createTag(name);
    if (tag != null && tag.code != null) {
      setState(() {
        _selectedCodes.add(tag.code!);
      });
      _newTagController.clear();
    }
  }

  @override
  void dispose() {
    _newTagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WordTag>>(
      future: WordTagService.listTags(),
      builder: (context, snapshot) {
        final tags = snapshot.data ?? [];
        final cs = context.colors;

        return Dialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Adaptive.r(16)),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: Adaptive.w(360),
              maxHeight: Adaptive.h(420),
            ),
            child: Padding(
              padding: EdgeInsets.all(Adaptive.r(20)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  Row(
                    children: [
                      Icon(
                        AppIcons.labelOutline,
                        size: Adaptive.sp(20),
                        color: cs.primary,
                      ),
                      SizedBox(width: Adaptive.w(8)),
                      Text(
                        '管理标签',
                        style: TextStyle(
                          fontSize: Adaptive.sp(16),
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: Adaptive.h(12)),

                  // 标签列表
                  if (tags.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: Adaptive.h(8)),
                      child: Text(
                        '暂无标签，请在下方输入创建。',
                        style: TextStyle(
                          fontSize: Adaptive.sp(13),
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    Container(
                      constraints: BoxConstraints(maxHeight: Adaptive.h(200)),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(Adaptive.r(12)),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.symmetric(vertical: Adaptive.h(4)),
                        itemCount: tags.length,
                        itemBuilder: (_, index) {
                          final tag = tags[index];
                          final selected =
                              tag.code != null &&
                              _selectedCodes.contains(tag.code!);
                          return InkWell(
                            borderRadius: BorderRadius.circular(Adaptive.r(8)),
                            onTap: tag.code == null
                                ? null
                                : () {
                                    setState(() {
                                      if (selected) {
                                        _selectedCodes.remove(tag.code!);
                                      } else {
                                        _selectedCodes.add(tag.code!);
                                      }
                                    });
                                  },
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: Adaptive.w(12),
                                vertical: Adaptive.h(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    selected
                                        ? AppIcons.checkBox
                                        : AppIcons.checkBoxOutlineBlank,
                                    size: Adaptive.sp(20),
                                    color: selected
                                        ? cs.primary
                                        : cs.onSurfaceVariant,
                                  ),
                                  SizedBox(width: Adaptive.w(10)),
                                  Expanded(
                                    child: Text(
                                      tag.name,
                                      style: TextStyle(
                                        fontSize: Adaptive.sp(14),
                                        fontWeight: selected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: selected
                                            ? cs.primary
                                            : cs.onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  SizedBox(height: Adaptive.h(12)),

                  // 新建标签
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newTagController,
                          style: TextStyle(
                            fontSize: Adaptive.sp(14),
                            color: cs.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: '新标签名称',
                            hintStyle: TextStyle(
                              fontSize: Adaptive.sp(13),
                              color: cs.onSurfaceVariant,
                            ),
                            isDense: true,
                            filled: true,
                            fillColor: cs.surfaceContainerLow,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: Adaptive.w(12),
                              vertical: Adaptive.h(10),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                Adaptive.r(10),
                              ),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) =>
                              _createTag(_newTagController.text.trim()),
                        ),
                      ),
                      SizedBox(width: Adaptive.w(8)),
                      SizedBox(
                        height: Adaptive.h(38),
                        child: FilledButton.tonal(
                          onPressed: () =>
                              _createTag(_newTagController.text.trim()),
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: Adaptive.w(14),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                Adaptive.r(10),
                              ),
                            ),
                          ),
                          child: Text(
                            '添加',
                            style: TextStyle(fontSize: Adaptive.sp(13)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: Adaptive.h(16)),

                  // 确定按钮
                  SizedBox(
                    width: double.infinity,
                    height: Adaptive.h(44),
                    child: FilledButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await WordTagService.replaceTags(
                          widget.wordCode,
                          _selectedCodes.toList(),
                        );
                      },
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Adaptive.r(12)),
                        ),
                      ),
                      child: Text(
                        '确定',
                        style: TextStyle(
                          fontSize: Adaptive.sp(15),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
