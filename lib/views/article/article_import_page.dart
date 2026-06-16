import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vidlang/services/article_parser.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/theme/app_spacing.dart';
import 'package:vidlang/views/article/article_reader_page.dart';

/// 文章导入/创建页
///
/// 支持粘贴文章正文，自动解析段落/句子并保存到数据库。
class ArticleImportPage extends StatefulWidget {
  const ArticleImportPage({super.key});

  @override
  State<ArticleImportPage> createState() => _ArticleImportPageState();
}

class _ArticleImportPageState extends State<ArticleImportPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _importArticle() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入文章标题')));
      return;
    }
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请粘贴文章正文')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final parsed = ArticleParser.parse(title: title, content: content);

      // 保存 Article
      await DatabaseService.insert(parsed.article);
      final articleCode = parsed.article.code!;

      // 填充 articleCode 到句子、章节和段落
      for (final s in parsed.sentences) {
        s.articleCode = articleCode;
      }
      for (final ch in parsed.chapters) {
        ch.articleCode = articleCode;
      }
      for (final p in parsed.paragraphs) {
        p.articleCode = articleCode;
      }

      // 保存句子
      if (parsed.sentences.isNotEmpty) {
        await DatabaseService.batchInsert(parsed.sentences);
      }

      // 保存章节（阅读器核心依赖）
      if (parsed.chapters.isNotEmpty) {
        await DatabaseService.batchInsert(parsed.chapters);
      }

      // 保存段落
      if (parsed.paragraphs.isNotEmpty) {
        await DatabaseService.batchInsert(parsed.paragraphs);
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ArticleReaderPage(articleCode: parsed.article.code!)),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导入失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('创建文章'),
        backgroundColor: colorScheme.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppSpacing.md.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题输入
                  TextField(
                    controller: _titleController,
                    style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: '文章标题',
                      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: BorderSide(color: AppColors.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  SizedBox(height: AppSpacing.md.h),

                  // 正文输入
                  TextField(
                    controller: _contentController,
                    maxLines: null,
                    minLines: 12,
                    style: TextStyle(fontSize: 15.sp, color: colorScheme.onSurface, height: 1.6),
                    decoration: InputDecoration(
                      hintText: '粘贴文章正文...',
                      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: BorderSide(color: AppColors.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  SizedBox(height: AppSpacing.sm.h),

                  // 提示文字
                  Text(
                    '支持 Markdown 格式，段落之间用空行分隔',
                    style: TextStyle(fontSize: 12.sp, color: colorScheme.outline),
                  ),
                ],
              ),
            ),
          ),

          // 底部按钮
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.md.w),
              child: SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _importArticle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 20.w,
                          height: 20.w,
                          child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text('导入并打开', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
