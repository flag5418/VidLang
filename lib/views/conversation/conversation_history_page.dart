import 'package:flutter/material.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/models/conversation_record.dart';
import 'package:vidlang/providers/conversation_provider.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/views/conversation/conversation_page.dart';
import 'package:vidlang/widgets/app_dialogs.dart';

/// 对话历史记录列表页面
class ConversationHistoryPage extends StatefulWidget {
  /// 来源类型筛选（可选）
  final String? sourceType;

  /// 来源 code 筛选（可选）
  final String? sourceCode;

  const ConversationHistoryPage({super.key, this.sourceType, this.sourceCode});

  @override
  State<ConversationHistoryPage> createState() =>
      _ConversationHistoryPageState();
}

class _ConversationHistoryPageState extends State<ConversationHistoryPage> {
  List<ConversationRecord> _records = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final records = await ConversationNotifier.getConversationHistory(
        sourceType: widget.sourceType,
        sourceCode: widget.sourceCode,
        limit: 100,
      );
      if (mounted) {
        setState(() {
          _records = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteRecord(ConversationRecord record) async {
    final confirm = await AppConfirmDialog.show(
      context,
      title: '删除对话记录',
      content: '确定要删除这条对话记录吗？\n${record.firstMessagePreview ?? ""}',
      confirmText: '删除',
      destructive: true,
    );

    if (confirm == true) {
      await ConversationNotifier.deleteConversationRecord(record.code!);
      _loadHistory();
      if (mounted) {
        // ✅ TDesign 规范：使用 TDToast 替代 SnackBar
        TDToast.showText('已删除', context: context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            AppIcons.arrowBackIosNew,
            color: context.colors.textSecondary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '对话历史',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_records.isNotEmpty)
            IconButton(
              icon: Icon(AppIcons.delete, color: context.colors.textSecondary),
              tooltip: '清空所有',
              onPressed: () => _showClearAllDialog(),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // 使用 TDesign TDLoading 替换 CircularProgressIndicator
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TDLoading(size: TDLoadingSize.medium, icon: TDLoadingIcon.circle),
            SizedBox(height: 12),
            Text(
              '加载中...',
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.error, color: context.colors.error, size: 48),
              SizedBox(height: 12),
              Text(
                '加载失败',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              // ✅ TDesign 规范：使用 TDButton 替换 ElevatedButton
              TDButton(
                text: '重试',
                onTap: _loadHistory,
                type: TDButtonType.fill,
                theme: TDButtonTheme.primary,
              ),
            ],
          ),
        ),
      );
    }

    if (_records.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: adaptive.Adaptive.w(32),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  AppIcons.chatBubbleOutline,
                  size: 36,
                  color: context.colors.primary,
                ),
              ),
              SizedBox(height: 16),
              Text(
                '暂无对话记录',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '开始和 AI 练习口语后，对话记录会显示在这里',
                style: TextStyle(
                  fontSize: 14,
                  color: context.colors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      color: context.colors.primary,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(
          horizontal: adaptive.Adaptive.w(16),
          vertical: adaptive.Adaptive.h(12),
        ),
        itemCount: _records.length,
        separatorBuilder: (_, _) => SizedBox(height: 10),
        itemBuilder: (context, index) {
          return _buildRecordCard(_records[index]);
        },
      ),
    );
  }

  Widget _buildRecordCard(ConversationRecord record) {
    final colors = context.colors;

    return GestureDetector(
      onTap: () => _navigateToDetail(record),
      onLongPress: () => _deleteRecord(record),
      child: Container(
        padding: EdgeInsets.all(adaptive.Adaptive.w(14)),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.outlinedCard),
          border: Border.all(
            color: colors.border.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左侧图标
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _getSourceColor(
                  record.sourceType,
                  colors,
                ).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getSourceIcon(record.sourceType),
                color: _getSourceColor(record.sourceType, colors),
                size: 22,
              ),
            ),
            SizedBox(width: 12),
            // 中间内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题行
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          record.sourceTitle ?? record.sourceTypeLabel,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildStatusBadge(record.status, colors),
                    ],
                  ),
                  SizedBox(height: 4),
                  // 预览文本
                  if (record.firstMessagePreview != null)
                    Text(
                      record.firstMessagePreview!,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  SizedBox(height: 8),
                  // 底部信息行
                  Row(
                    children: [
                      // 难度标签
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.textWeak.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          record.difficultyLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      // 轮数
                      Icon(AppIcons.forum, size: 13, color: colors.textWeak),
                      SizedBox(width: 2),
                      Text(
                        '${record.turnCount}轮',
                        style: TextStyle(fontSize: 12, color: colors.textWeak),
                      ),
                      SizedBox(width: 8),
                      // 时长
                      Icon(AppIcons.schedule, size: 13, color: colors.textWeak),
                      SizedBox(width: 2),
                      Text(
                        record.formattedDuration,
                        style: TextStyle(fontSize: 12, color: colors.textWeak),
                      ),
                      const Spacer(),
                      // 时间
                      Text(
                        _formatTime(record.createdAt),
                        style: TextStyle(fontSize: 11, color: colors.textWeak),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, AppColorsData colors) {
    Color badgeColor;
    String label;
    switch (status) {
      case 'completed':
        badgeColor = AppColors.success;
        label = '已完成';
        break;
      case 'interrupted':
        badgeColor = colors.warning;
        label = '中断';
        break;
      case 'error':
        badgeColor = colors.error;
        label = '异常';
        break;
      default:
        badgeColor = colors.textWeak;
        label = status;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: adaptive.Adaptive.w(6),
        vertical: adaptive.Adaptive.h(2),
      ),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: badgeColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  IconData _getSourceIcon(String? sourceType) {
    switch (sourceType) {
      case 'subtitle':
        return AppIcons.playCircleOutline;
      case 'article':
        return AppIcons.article;
      default:
        return AppIcons.chatBubbleOutline;
    }
  }

  Color _getSourceColor(String? sourceType, AppColorsData colors) {
    switch (sourceType) {
      case 'subtitle':
        return colors.primary;
      case 'article':
        return AppColors.warning;
      default:
        return colors.textSecondary;
    }
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';

    return '${time.month}/${time.day}';
  }

  void _navigateToDetail(ConversationRecord record) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationDetailPage(record: record),
      ),
    );
  }

  void _showClearAllDialog() async {
    final confirm = await AppConfirmDialog.show(
      context,
      title: '清空所有记录',
      content: '确定要删除所有对话记录吗？此操作不可恢复。',
      confirmText: '全部删除',
      destructive: true,
    );

    if (confirm == true) {
      for (final record in _records) {
        await ConversationNotifier.deleteConversationRecord(record.code!);
      }
      _loadHistory();
      if (mounted) {
        // ✅ TDesign 规范：使用 TDToast 替代 SnackBar
        TDToast.showText('已清空所有记录', context: context);
      }
    }
  }
}

/// 对话详情页面（查看历史消息）
class ConversationDetailPage extends ConsumerWidget {
  final ConversationRecord record;

  const ConversationDetailPage({super.key, required this.record});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final messages = record.parsedMessages;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            AppIcons.arrowBackIosNew,
            color: colors.textSecondary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          record.sourceTitle ?? '对话详情',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // 可以添加"继续对话"按钮，用于恢复上下文
          IconButton(
            icon: Icon(AppIcons.refresh, color: colors.primary),
            tooltip: '基于此记录继续对话',
            onPressed: () => _resumeConversation(context),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 对话信息头部
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: adaptive.Adaptive.w(16),
              vertical: adaptive.Adaptive.h(10),
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(
                bottom: BorderSide(
                  color: colors.border.withValues(alpha: 0.5),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                _infoChip('${record.turnCount} 轮', AppIcons.forum, colors),
                SizedBox(width: 10),
                _infoChip(record.formattedDuration, AppIcons.schedule, colors),
                SizedBox(width: 10),
                _infoChip(record.difficultyLabel, AppIcons.school, colors),
                SizedBox(width: 10),
                _infoChip(record.voice, AppIcons.recordVoiceOver, colors),
              ],
            ),
          ),
          // 消息列表
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Text(
                      '暂无消息内容',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageItem(messages[index], colors);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String text, IconData icon, AppColorsData colors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colors.textSecondary),
        SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 12, color: colors.textSecondary)),
      ],
    );
  }

  Widget _buildMessageItem(Map<String, dynamic> msg, AppColorsData colors) {
    final isAi = msg['role'] == 'ai';
    final text = msg['text'] as String? ?? '';
    final translation = msg['translation'] as String?;

    final borderRadius = BorderRadius.circular(16);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isAi
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: [
          if (isAi) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8, top: 4),
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F6),
                  borderRadius: borderRadius,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                    if (translation != null && translation.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          translation,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 48),
          ] else ...[
            SizedBox(width: 48),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: borderRadius,
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    color: colors.textPrimary.withValues(alpha: 0.85),
                    fontSize: 14,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(left: 8, top: 4),
              decoration: BoxDecoration(
                color: colors.textWeak.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                AppIcons.person,
                size: 18,
                color: colors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 跳转到对话页面并恢复上下文
  void _resumeConversation(BuildContext context) {
    // 先返回到对话页面，然后通过参数传递记录信息进行恢复
    // 这里直接导航到 ConversationPage 并传入恢复标记
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationPage(
          sourceType: record.sourceType.isNotEmpty
              ? record.sourceType
              : 'article',
          sourceCode: record.sourceCode,
          sourceTitle: record.sourceTitle,
          voice: record.voice,
        ),
      ),
      (route) => false,
    );
  }
}
