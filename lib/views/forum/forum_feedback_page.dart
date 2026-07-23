import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;
import 'package:vidlang/views/forum/providers/forum_providers.dart';

/// 提交反馈页 — V2.0
class ForumFeedbackPage extends ConsumerStatefulWidget {
  const ForumFeedbackPage({super.key});

  @override
  ConsumerState<ForumFeedbackPage> createState() =>
      _ForumFeedbackPageState();
}

class _ForumFeedbackPageState extends ConsumerState<ForumFeedbackPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _type = 'bug';
  final List<File> _localImages = [];
  final List<String> _uploadedUrls = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('提交反馈'),
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 1,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
          children: [
            // 反馈类型
            _buildSectionLabel(colors, '反馈类型'),
            SizedBox(height: adaptive.Adaptive.h(8)),
            _buildTypeSelector(colors),
            SizedBox(height: adaptive.Adaptive.h(16)),
            // 标题
            _buildSectionLabel(colors, '标题'),
            SizedBox(height: adaptive.Adaptive.h(8)),
            _buildTitleField(colors),
            SizedBox(height: adaptive.Adaptive.h(16)),
            // 内容
            _buildSectionLabel(colors, '详细描述'),
            SizedBox(height: adaptive.Adaptive.h(8)),
            _buildContentField(colors),
            SizedBox(height: adaptive.Adaptive.h(16)),
            // 图片（可选）
            _buildSectionLabel(colors, '截图（可选）'),
            SizedBox(height: adaptive.Adaptive.h(8)),
            _buildImageSection(colors),
            SizedBox(height: adaptive.Adaptive.h(40)),
            // 提交按钮
            SizedBox(
              width: double.infinity,
              height: adaptive.Adaptive.h(52),
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  disabledBackgroundColor:
                      colors.primary.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(adaptive.Adaptive.r(12)),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? SizedBox(
                        width: adaptive.Adaptive.w(20),
                        height: adaptive.Adaptive.h(20),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        '提交反馈',
                        style: TextStyle(
                          fontSize: adaptive.Adaptive.sp(16),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(AppColorsData colors, String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: adaptive.Adaptive.sp(14),
        fontWeight: FontWeight.w500,
        color: colors.textPrimary,
      ),
    );
  }

  Widget _buildTypeSelector(AppColorsData colors) {
    final types = [
      ('bug', 'Bug 报告', Icons.bug_report_outlined),
      ('feature', '功能建议', Icons.lightbulb_outline),
      ('other', '其他', Icons.more_horiz),
    ];

    return Row(
      children: types.map((t) {
        final isSelected = _type == t.$1;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: adaptive.Adaptive.w(8)),
            child: GestureDetector(
              onTap: () => setState(() => _type = t.$1),
              child: Container(
                padding: EdgeInsets.symmetric(
                  vertical: adaptive.Adaptive.h(10),
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.primary.withValues(alpha: 0.08)
                      : colors.surfaceContainer,
                  borderRadius:
                      BorderRadius.circular(adaptive.Adaptive.r(12)),
                  border: Border.all(
                    color: isSelected ? colors.primary : colors.border,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      t.$3,
                      size: adaptive.Adaptive.sp(22),
                      color: isSelected ? colors.primary : colors.textSecondary,
                    ),
                    SizedBox(height: adaptive.Adaptive.h(4)),
                    Text(
                      t.$2,
                      style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(12),
                        color:
                            isSelected ? colors.primary : colors.textSecondary,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTitleField(AppColorsData colors) {
    return TextFormField(
      controller: _titleController,
      maxLength: 100,
      style: TextStyle(fontSize: adaptive.Adaptive.sp(16)),
      decoration: InputDecoration(
        hintText: '简要描述你的问题或建议',
        hintStyle: TextStyle(color: colors.textWeak),
        filled: true,
        fillColor: colors.surfaceContainer,
        contentPadding: EdgeInsets.symmetric(
          horizontal: adaptive.Adaptive.w(12),
          vertical: adaptive.Adaptive.h(12),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(12)),
          borderSide: BorderSide.none,
        ),
        counterStyle: TextStyle(color: colors.textWeak),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return '请输入标题';
        return null;
      },
    );
  }

  Widget _buildContentField(AppColorsData colors) {
    return TextFormField(
      controller: _contentController,
      maxLines: 8,
      minLines: 4,
      style: TextStyle(fontSize: adaptive.Adaptive.sp(14)),
      decoration: InputDecoration(
        hintText: '请详细描述你遇到的问题或建议...',
        hintStyle: TextStyle(color: colors.textWeak),
        filled: true,
        fillColor: colors.surfaceContainer,
        contentPadding: EdgeInsets.fromLTRB(
          adaptive.Adaptive.w(12),
          adaptive.Adaptive.h(12),
          adaptive.Adaptive.w(12),
          adaptive.Adaptive.h(12),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(12)),
          borderSide: BorderSide.none,
        ),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return '请输入描述内容';
        if (v.trim().length < 10) return '描述至少10个字';
        return null;
      },
    );
  }

  Widget _buildImageSection(AppColorsData colors) {
    return Wrap(
      spacing: adaptive.Adaptive.w(8),
      runSpacing: adaptive.Adaptive.h(8),
      children: [
        ..._uploadedUrls.map((url) => _buildImagePreview(
              url: url,
              isNetwork: true,
            )),
        ..._localImages.asMap().entries.map((e) => _buildImagePreview(
              localPath: e.value.path,
              index: e.key,
            )),
        if ((_localImages.length + _uploadedUrls.length) < 9)
          _buildAddImageButton(colors),
      ],
    );
  }

  Widget _buildImagePreview({
    String? url,
    String? localPath,
    int? index,
    bool isNetwork = false,
  }) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(6)),
          child: isNetwork
              ? Image.network(
                  url!,
                  width: adaptive.Adaptive.w(80),
                  height: adaptive.Adaptive.h(80),
                  fit: BoxFit.cover,
                )
              : Image.file(
                  File(localPath!),
                  width: adaptive.Adaptive.w(80),
                  height: adaptive.Adaptive.h(80),
                  fit: BoxFit.cover,
                ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: GestureDetector(
            onTap: () {
              setState(() {
                if (isNetwork) {
                  _uploadedUrls.remove(url);
                } else if (index != null) {
                  _localImages.removeAt(index);
                }
              });
            },
            child: Container(
              padding: EdgeInsets.all(adaptive.Adaptive.w(2)),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close,
                size: adaptive.Adaptive.sp(14),
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddImageButton(AppColorsData colors) {
    return GestureDetector(
      onTap: _isSubmitting ? null : _pickImages,
      child: Container(
        width: adaptive.Adaptive.w(80),
        height: adaptive.Adaptive.h(80),
        decoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(6)),
          border: Border.all(color: colors.border),
        ),
        child: Icon(
          Icons.add,
          color: colors.textWeak,
          size: adaptive.Adaptive.sp(28),
        ),
      ),
    );
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final maxAllowed = 9 - _localImages.length - _uploadedUrls.length;
    if (maxAllowed <= 0) return;

    try {
      final List<XFile> images = await picker.pickMultiImage(
        limit: maxAllowed,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (images.isEmpty) return;
      setState(() {
        _localImages.addAll(images.map((x) => File(x.path)));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('选择图片失败: $e')));
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final service = ref.read(forumServiceProvider);

      // Upload images
      for (final file in _localImages) {
        final url = await service.uploadImage(file.path);
        _uploadedUrls.add(url);
      }
      _localImages.clear();

      await service.submitFeedback(
        _type,
        _titleController.text.trim(),
        _contentController.text.trim(),
        _uploadedUrls.isEmpty ? null : _uploadedUrls,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('反馈已提交，感谢你的反馈！')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('提交失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
