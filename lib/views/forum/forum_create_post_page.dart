import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_vscode_logger/flutter_vscode_logger.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vidlang/components/ui/ui_components.dart';
import 'package:vidlang/models/forum/forum_tag.dart';
import 'package:vidlang/views/forum/providers/forum_providers.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

/// 创建帖子页 — V2.0 标签单选
class ForumCreatePostPage extends ConsumerStatefulWidget {
  const ForumCreatePostPage({super.key});

  @override
  ConsumerState<ForumCreatePostPage> createState() =>
      _ForumCreatePostPageState();
}

class _ForumCreatePostPageState extends ConsumerState<ForumCreatePostPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  ForumTag? _selectedTag;
  final List<File> _localImages = [];
  final List<String> _uploadedUrls = [];
  bool _isUploading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tagsAsync = ref.watch(forumTagsProvider);
    final createState = ref.watch(createPostProvider);

    ref.listen(createPostProvider, (_, next) {
      if (next.status == CreatePostStatus.success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('发布成功')));
        Navigator.pop(context, true);
      } else if (next.status == CreatePostStatus.error) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error ?? '发布失败')));
      }
    });

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppNavBar(
        title: '发布帖子',
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 1,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
          children: [
            // 标签选择（必选，V2.0 替代板块）
            _buildTagSelector(context, colors, tagsAsync),
            SizedBox(height: adaptive.Adaptive.h(16)),
            // 标题
            _buildTitleField(context, colors),
            SizedBox(height: adaptive.Adaptive.h(16)),
            // 正文
            _buildContentField(context, colors),
            SizedBox(height: adaptive.Adaptive.h(16)),
            // 图片
            _buildImageSection(context, colors),
            SizedBox(height: adaptive.Adaptive.h(80)),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.border, width: 0.5)),
        ),
        padding: EdgeInsets.fromLTRB(
          adaptive.Adaptive.w(16),
          adaptive.Adaptive.h(12),
          adaptive.Adaptive.w(16),
          adaptive.Adaptive.h(12) + MediaQuery.of(context).padding.bottom,
        ),
        child: SizedBox(
          width: double.infinity,
          height: adaptive.Adaptive.h(52),
          child: ElevatedButton(
            onPressed: createState.status == CreatePostStatus.loading
                ? null
                : () => _submitPost(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              disabledBackgroundColor: colors.primary.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(adaptive.Adaptive.r(12)),
              ),
              elevation: 0,
            ),
            child: createState.status == CreatePostStatus.loading
                ? SizedBox(
                    width: adaptive.Adaptive.w(20),
                    height: adaptive.Adaptive.h(20),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    '发布',
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(16),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildTagSelector(
    BuildContext context,
    AppColorsData colors,
    AsyncValue<List<ForumTag>> tagsAsync,
  ) {
    return tagsAsync.when(
      loading: () => const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (e, _) => Text('加载标签失败', style: TextStyle(color: colors.error)),
      data: (tags) {
        if (tags.isEmpty) {
          return const Text('暂无可用标签');
        }
        if (_selectedTag == null && tags.isNotEmpty) {
          Future.microtask(() {
            setState(() => _selectedTag = tags.first);
          });
        }
        return DropdownButtonFormField<ForumTag>(
          initialValue: _selectedTag,
          items: tags.map((t) {
            return DropdownMenuItem(value: t, child: Text(t.name));
          }).toList(),
          onChanged: (v) => setState(() => _selectedTag = v),
          decoration: InputDecoration(
            labelText: '选择标签（必选）',
            labelStyle: TextStyle(color: colors.textSecondary),
            contentPadding: EdgeInsets.symmetric(
              horizontal: adaptive.Adaptive.w(12),
              vertical: adaptive.Adaptive.h(12),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(adaptive.Adaptive.r(12)),
            ),
            filled: true,
            fillColor: colors.surfaceContainer,
          ),
          validator: (v) {
            if (v == null) return '请选择标签';
            return null;
          },
        );
      },
    );
  }

  Widget _buildTitleField(BuildContext context, AppColorsData colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '标题',
          style: TextStyle(
            fontSize: adaptive.Adaptive.sp(14),
            fontWeight: FontWeight.w500,
            color: colors.textPrimary,
          ),
        ),
        SizedBox(height: adaptive.Adaptive.h(8)),
        TextFormField(
          controller: _titleController,
          maxLength: 80,
          style: TextStyle(fontSize: adaptive.Adaptive.sp(16)),
          decoration: InputDecoration(
            hintText: '请输入帖子标题（2-80字）',
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
            if (v == null || v.trim().length < 2) return '标题至少2个字';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildContentField(BuildContext context, AppColorsData colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '正文',
          style: TextStyle(
            fontSize: adaptive.Adaptive.sp(14),
            fontWeight: FontWeight.w500,
            color: colors.textPrimary,
          ),
        ),
        SizedBox(height: adaptive.Adaptive.h(8)),
        TextFormField(
          controller: _contentController,
          maxLines: 10,
          minLines: 5,
          style: TextStyle(fontSize: adaptive.Adaptive.sp(14)),
          decoration: InputDecoration(
            hintText: '正文内容（Markdown 格式）',
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
        ),
      ],
    );
  }

  Widget _buildImageSection(BuildContext context, AppColorsData colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '图片（最多9张）',
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(14),
                color: colors.textSecondary,
              ),
            ),
            SizedBox(width: adaptive.Adaptive.w(8)),
            GestureDetector(
              onTap: _isUploading ? null : _pickImages,
              child: Icon(
                Icons.add_photo_alternate_outlined,
                size: adaptive.Adaptive.sp(20),
                color: colors.primary,
              ),
            ),
          ],
        ),
        SizedBox(height: adaptive.Adaptive.h(8)),
        if (_localImages.isNotEmpty || _uploadedUrls.isNotEmpty)
          Wrap(
            spacing: adaptive.Adaptive.w(8),
            runSpacing: adaptive.Adaptive.h(8),
            children: [
              ..._uploadedUrls.map(
                (url) => _buildImagePreview(
                  context,
                  colors,
                  isNetwork: true,
                  url: url,
                ),
              ),
              ..._localImages.asMap().entries.map(
                (e) => _buildImagePreview(
                  context,
                  colors,
                  localPath: e.value.path,
                  index: e.key,
                ),
              ),
              if ((_localImages.length + _uploadedUrls.length) < 9)
                _buildAddImageButton(context, colors),
            ],
          )
        else
          _buildAddImageButton(context, colors),
        if (_isUploading)
          Padding(
            padding: EdgeInsets.only(top: adaptive.Adaptive.h(8)),
            child: const LinearProgressIndicator(),
          ),
      ],
    );
  }

  Widget _buildImagePreview(
    BuildContext context,
    AppColorsData colors, {
    bool isNetwork = false,
    String? url,
    String? localPath,
    int? index,
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

  Widget _buildAddImageButton(BuildContext context, AppColorsData colors) {
    return GestureDetector(
      onTap: _isUploading ? null : _pickImages,
      child: Container(
        width: adaptive.Adaptive.w(80),
        height: adaptive.Adaptive.h(80),
        decoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(6)),
          border: Border.all(color: colors.border, style: BorderStyle.solid),
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

  Future<void> _submitPost(BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
      logger.debug('表单验证未通过', tag: 'FORUM');
      return;
    }
    if (_selectedTag == null) {
      logger.debug('未选择标签', tag: 'FORUM');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请选择标签')));
      return;
    }

    if (_localImages.isNotEmpty) {
      logger.debug('开始上传 ${_localImages.length} 张图片', tag: 'FORUM');
    } else {
      logger.debug('无图片，直接创建帖子', tag: 'FORUM');
    }

    setState(() => _isUploading = true);
    try {
      final service = ref.read(forumServiceProvider);
      for (final file in _localImages) {
        logger.debug('上传图片: ${file.path}', tag: 'FORUM');
        final url = await service.uploadImage(file.path);
        _uploadedUrls.add(url);
        logger.debug('上传成功: $url', tag: 'FORUM');
      }
      _localImages.clear();
    } catch (e) {
      logger.error('图片上传失败', tag: 'FORUM', error: e);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('图片上传失败: $e')));
      }
      setState(() => _isUploading = false);
      return;
    }

    setState(() => _isUploading = false);

    logger.debug('开始创建帖子: tagId=${_selectedTag!.id}', tag: 'FORUM');
    final notifier = ref.read(createPostProvider.notifier);
    await notifier.createPost(
      tagId: _selectedTag!.id,
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      imageUrls: _uploadedUrls,
    );
  }
}
