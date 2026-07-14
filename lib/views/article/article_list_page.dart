import 'package:flutter/material.dart';
import 'package:vidlang/models/article.dart';
import 'package:vidlang/models/base_entity.dart';
import 'package:vidlang/views/article/article_import_page.dart';
import 'package:vidlang/views/article/article_reader_page.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';
import 'package:vidlang/widgets/app_dialogs.dart';

/// 文章列表页
///
/// 展示所有已创建的文章，支持：
/// - 卡片预览（标题、段落数、句子数、词数、进度条）
/// - 点击进入阅读器
/// - 长按删除
/// - FAB 创建新文章
class ArticleListPage extends StatefulWidget {
  const ArticleListPage({super.key});

  @override
  State<ArticleListPage> createState() => _ArticleListPageState();
}

class _ArticleListPageState extends State<ArticleListPage> {
  List<Article> _articles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArticles();
  }

  Future<void> _loadArticles() async {
    setState(() => _isLoading = true);
    try {
      final articles = await BaseEntityExtension.findAll<Article>(
        () => Article(),
      );
      setState(() {
        _articles = articles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteArticle(Article article) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: '删除文章',
      content: '确定删除「${article.title}」？',
      confirmText: '删除',
      destructive: true,
    );
    if (confirmed == true) {
      await article.softDelete();
      _loadArticles();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colors;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('文章'),
        backgroundColor: colorScheme.surface,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _articles.isEmpty
          ? _buildEmptyState(colorScheme)
          : _buildList(colorScheme),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ArticleImportPage()),
          );
          if (mounted) _loadArticles();
        },
        child: Icon(AppIcons.add, color: context.colors.surface),
      ),
    );
  }

  Widget _buildEmptyState(AppColorsData colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            AppIcons.article,
            size: Adaptive.sp(context, 64),
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          SizedBox(height: Adaptive.h(context, AppSpacing.md)),
          Text(
            '暂无文章',
            style: TextStyle(
              fontSize: Adaptive.sp(context, 16),
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: Adaptive.h(context, AppSpacing.sm)),
          Text(
            '点击右下角按钮创建第一篇',
            style: TextStyle(
              fontSize: Adaptive.sp(context, 13),
              color: colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(AppColorsData colorScheme) {
    return RefreshIndicator(
      onRefresh: _loadArticles,
      child: ListView.builder(
        padding: EdgeInsets.all(Adaptive.w(context, AppSpacing.md)),
        itemCount: _articles.length,
        itemBuilder: (context, index) {
          final article = _articles[index];
          return _buildArticleCard(article, colorScheme);
        },
      ),
    );
  }

  Widget _buildArticleCard(Article article, AppColorsData colorScheme) {
    final estimatedMinutes = (article.wordCount / 200).ceil().clamp(1, 999);

    return Card(
      margin: EdgeInsets.only(bottom: Adaptive.h(context, AppSpacing.sm)),
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Adaptive.r(context, 12)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(Adaptive.r(context, 12)),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ArticleReaderPage(articleCode: article.code!),
            ),
          );
          if (mounted) _loadArticles();
        },
        onLongPress: () => _deleteArticle(article),
        child: Padding(
          padding: EdgeInsets.all(Adaptive.w(context, AppSpacing.md)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              Row(
                children: [
                  Expanded(
                    child: Text(
                      article.title,
                      style: TextStyle(
                        fontSize: Adaptive.sp(context, 16),
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (article.lastStudyDate != null)
                    Icon(
                      AppIcons.history,
                      size: Adaptive.sp(context, 14),
                      color: colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
              SizedBox(height: Adaptive.h(context, AppSpacing.sm)),

              // 统计信息
              Row(
                children: [
                  _buildStatChip('${article.totalParagraphs} 段', colorScheme),
                  SizedBox(width: Adaptive.w(context, AppSpacing.sm)),
                  _buildStatChip('${article.totalSentences} 句', colorScheme),
                  SizedBox(width: Adaptive.w(context, AppSpacing.sm)),
                  _buildStatChip('${article.wordCount} 词', colorScheme),
                  const Spacer(),
                  _buildStatChip('约 $estimatedMinutes 分钟', colorScheme),
                ],
              ),
              SizedBox(height: Adaptive.h(context, AppSpacing.sm)),

              // 进度条
              ClipRRect(
                borderRadius: BorderRadius.circular(Adaptive.r(context, 4)),
                child: LinearProgressIndicator(
                  value: article.progress.clamp(0.0, 1.0),
                  minHeight: Adaptive.h(context, 4),
                  backgroundColor: colorScheme.outline.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(String text, AppColorsData colorScheme) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Adaptive.w(context, 8),
        vertical: Adaptive.h(context, 2),
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(Adaptive.r(context, 6)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: Adaptive.sp(context, 13),
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
