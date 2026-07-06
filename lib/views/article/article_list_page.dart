import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vidlang/models/article.dart';
import 'package:vidlang/models/base_entity.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/theme/app_spacing.dart';
import 'package:vidlang/views/article/article_import_page.dart';
import 'package:vidlang/views/article/article_reader_page.dart';

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
      final articles = await BaseEntityExtension.findAll<Article>(() => Article());
      setState(() {
        _articles = articles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteArticle(Article article) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除文章'),
        content: Text('确定删除「${article.title}」？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await article.softDelete();
      _loadArticles();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const ArticleImportPage()));
          if (mounted) _loadArticles();
        },
        child: Icon(Icons.add, color: context.colors.surface),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined, size: 64.sp, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
          SizedBox(height: AppSpacing.md.h),
          Text('暂无文章', style: TextStyle(fontSize: 16.sp, color: colorScheme.onSurfaceVariant)),
          SizedBox(height: AppSpacing.sm.h),
          Text('点击右下角按钮创建第一篇', style: TextStyle(fontSize: 13.sp, color: colorScheme.outline)),
        ],
      ),
    );
  }

  Widget _buildList(ColorScheme colorScheme) {
    return RefreshIndicator(
      onRefresh: _loadArticles,
      child: ListView.builder(
        padding: EdgeInsets.all(AppSpacing.md.w),
        itemCount: _articles.length,
        itemBuilder: (context, index) {
          final article = _articles[index];
          return _buildArticleCard(article, colorScheme);
        },
      ),
    );
  }

  Widget _buildArticleCard(Article article, ColorScheme colorScheme) {
    final estimatedMinutes = (article.wordCount / 200).ceil().clamp(1, 999);

    return Card(
      margin: EdgeInsets.only(bottom: AppSpacing.sm.h),
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ArticleReaderPage(articleCode: article.code!)),
          );
          if (mounted) _loadArticles();
        },
        onLongPress: () => _deleteArticle(article),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              Row(
                children: [
                  Expanded(
                    child: Text(
                      article.title,
                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (article.lastStudyDate != null)
                    Icon(Icons.history, size: 14.sp, color: colorScheme.onSurfaceVariant),
                ],
              ),
              SizedBox(height: AppSpacing.sm.h),

              // 统计信息
              Row(
                children: [
                  _buildStatChip('${article.totalParagraphs} 段', colorScheme),
                  SizedBox(width: AppSpacing.sm.w),
                  _buildStatChip('${article.totalSentences} 句', colorScheme),
                  SizedBox(width: AppSpacing.sm.w),
                  _buildStatChip('${article.wordCount} 词', colorScheme),
                  const Spacer(),
                  _buildStatChip('约 $estimatedMinutes 分钟', colorScheme),
                ],
              ),
              SizedBox(height: AppSpacing.sm.h),

              // 进度条
              ClipRRect(
                borderRadius: BorderRadius.circular(4.r),
                child: LinearProgressIndicator(
                  value: article.progress.clamp(0.0, 1.0),
                  minHeight: 4.h,
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

  Widget _buildStatChip(String text, ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(text, style: TextStyle(fontSize: 13.sp, color: colorScheme.onSurfaceVariant)),
    );
  }
}
