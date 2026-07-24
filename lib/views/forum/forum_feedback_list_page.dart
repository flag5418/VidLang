import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/components/ui/ui_components.dart';
import 'package:vidlang/components/ui/loading_widget.dart';
import 'package:vidlang/models/forum/forum_feedback.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;
import 'package:vidlang/views/forum/providers/forum_providers.dart';

/// 我的反馈列表页 — V2.0
class ForumFeedbackListPage extends ConsumerStatefulWidget {
  const ForumFeedbackListPage({super.key});

  @override
  ConsumerState<ForumFeedbackListPage> createState() =>
      _ForumFeedbackListPageState();
}

class _ForumFeedbackListPageState extends ConsumerState<ForumFeedbackListPage> {
  final ScrollController _scrollController = ScrollController();
  final List<ForumFeedback> _feedbacks = [];
  int _page = 1;
  bool _hasMore = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_isLoading) {
        _page++;
        _loadData();
      }
    }
  }

  Future<void> _loadData() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final service = ref.read(forumServiceProvider);
      final response = await service.getMyFeedback(page: _page);
      setState(() {
        _feedbacks.addAll(response.data);
        _hasMore = response.pagination.hasMore;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _page = 1;
      _feedbacks.clear();
      _hasMore = true;
    });
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
appBar: AppNavBar(
  title: '我的反馈',
  backgroundColor: colors.surface,
  foregroundColor: colors.textPrimary,
  elevation: 1,
),
      body: _feedbacks.isEmpty && _isLoading
          ? const Center(child: LoadingWidget())
          : _feedbacks.isEmpty
              ? Center(
                  child: EmptyState(
                    icon: Icons.feedback_outlined,
                    title: '暂无反馈',
                    description: '遇到问题或有好建议？随时提交反馈',
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(vertical: adaptive.Adaptive.h(8)),
                    itemCount: _feedbacks.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _feedbacks.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }
                      return _buildFeedbackCard(
                          colors, _feedbacks[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildFeedbackCard(AppColorsData colors, ForumFeedback feedback) {
    return BaseCard.outlined(
      margin: EdgeInsets.symmetric(
        horizontal: adaptive.Adaptive.w(16),
        vertical: adaptive.Adaptive.h(6),
      ),
      padding: EdgeInsets.all(adaptive.Adaptive.w(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildTypeTag(colors, feedback.type),
              SizedBox(width: adaptive.Adaptive.w(8)),
              Expanded(
                child: Text(
                  feedback.title,
                  style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(15),
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: adaptive.Adaptive.w(8)),
              _buildStatusTag(colors, feedback.status),
            ],
          ),
          SizedBox(height: adaptive.Adaptive.h(6)),
          Text(
            feedback.content,
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(13),
              color: colors.textSecondary,
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (feedback.adminReply != null) ...[
            SizedBox(height: adaptive.Adaptive.h(10)),
            Container(
              padding: EdgeInsets.all(adaptive.Adaptive.w(10)),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(adaptive.Adaptive.r(8)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.reply,
                      size: adaptive.Adaptive.sp(14),
                      color: colors.primary),
                  SizedBox(width: adaptive.Adaptive.w(6)),
                  Expanded(
                    child: Text(
                      '管理员回复：${feedback.adminReply}',
                      style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(13),
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: adaptive.Adaptive.h(8)),
          Text(
            _formatTime(feedback.createdAt),
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(11),
              color: colors.textWeak,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTag(AppColorsData colors, String type) {
    final label = type == 'bug'
        ? 'Bug'
        : type == 'feature'
            ? '建议'
            : '其他';
    final icon = type == 'bug'
        ? Icons.bug_report
        : type == 'feature'
            ? Icons.lightbulb
            : Icons.more_horiz;
    final bgColor = type == 'bug'
        ? Colors.red.withValues(alpha: 0.08)
        : type == 'feature'
            ? Colors.amber.withValues(alpha: 0.12)
            : colors.surfaceContainer;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: adaptive.Adaptive.w(8),
        vertical: adaptive.Adaptive.h(3),
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: adaptive.Adaptive.sp(12), color: colors.textSecondary),
          SizedBox(width: adaptive.Adaptive.w(3)),
          Text(
            label,
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(11),
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTag(AppColorsData colors, String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'pending':
        bgColor = Colors.orange.withValues(alpha: 0.1);
        textColor = Colors.orange;
        label = '待处理';
        break;
      case 'processing':
        bgColor = Colors.blue.withValues(alpha: 0.1);
        textColor = Colors.blue;
        label = '处理中';
        break;
      case 'replied':
        bgColor = colors.primary.withValues(alpha: 0.1);
        textColor = colors.primary;
        label = '已回复';
        break;
      case 'closed':
        bgColor = colors.surfaceContainer;
        textColor = colors.textWeak;
        label = '已关闭';
        break;
      default:
        bgColor = colors.surfaceContainer;
        textColor = colors.textWeak;
        label = status;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: adaptive.Adaptive.w(8),
        vertical: adaptive.Adaptive.h(3),
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: adaptive.Adaptive.sp(11),
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  static String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}个月前';
    return '${(diff.inDays / 365).floor()}年前';
  }
}
