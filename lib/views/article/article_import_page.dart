import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:vidlang/services/article_parser.dart';
import 'package:vidlang/services/conversation_service.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/theme/app_spacing.dart';
import 'package:vidlang/views/article/article_reader_page.dart';
import 'package:vidlang/utils/adaptive.dart';

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
      // ✅ TDesign 规范：使用 TDToast 替代 SnackBar
      TDToast.showText('请输入文章标题', context: context);
      return;
    }
    if (content.isEmpty) {
      TDToast.showText('请粘贴文章正文', context: context);
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

      // Upload to cloud for AI question generation
      try {
        await ConversationService.uploadArticleContentToCloud(articleCode, folderCode: parsed.article.folderCode);
      } catch (_) {}

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ArticleReaderPage(articleCode: parsed.article.code!)),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        // ✅ TDesign 规范：使用 TDToast 替代 SnackBar
        TDToast.showFail('导入失败: $e', context: context);
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
              padding: EdgeInsets.all(Adaptive.w(context, AppSpacing.md)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题输入
                  TextField(
                    controller: _titleController,
                    style: TextStyle(fontSize: Adaptive.sp(context, 18), fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: '文章标题',
                      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Adaptive.r(context, 10)),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Adaptive.r(context, 10)),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Adaptive.r(context, 10)),
                        borderSide: BorderSide(color: AppColors.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  SizedBox(height: Adaptive.h(context, AppSpacing.md)),

                  // 正文输入
                  TextField(
                    controller: _contentController,
                    maxLines: null,
                    minLines: 12,
                    style: TextStyle(fontSize: Adaptive.sp(context, 15), color: colorScheme.onSurface, height: 1.6),
                    decoration: InputDecoration(
                      hintText: '粘贴文章正文...',
                      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Adaptive.r(context, 10)),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Adaptive.r(context, 10)),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Adaptive.r(context, 10)),
                        borderSide: BorderSide(color: AppColors.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  SizedBox(height: Adaptive.h(context, AppSpacing.sm)),

                  // 提示文字
                  Text(
                    '支持 Markdown 格式，段落之间用空行分隔',
                    style: TextStyle(fontSize: Adaptive.sp(context, 12), color: colorScheme.outline),
                  ),
                ],
              ),
            ),
          ),

          // 底部按钮
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(Adaptive.w(context, AppSpacing.md)),
              // ✅ TDesign 规范：使用 TDButton 替换 ElevatedButton
              child: SizedBox(
                width: double.infinity,
                height: Adaptive.h(context, 50),
                child: TDButton(
                  text: _isSaving ? '' : '导入并打开',
                  onTap: _isSaving ? null : _importArticle,
                  type: TDButtonType.fill,
                  theme: TDButtonTheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
