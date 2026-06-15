import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vidlang/models/ai_evaluation_log.dart';
import 'package:vidlang/models/recording_record.dart';
import 'package:vidlang/services/ai_service.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/models/video_info.dart';

class AiEvaluationSheet extends StatefulWidget {
  final String videoCode;
  final String videoTitle;
  final String language;

  const AiEvaluationSheet({
    super.key,
    required this.videoCode,
    required this.videoTitle,
    this.language = 'en',
  });

  @override
  State<AiEvaluationSheet> createState() => _AiEvaluationSheetState();

  static void show(BuildContext context, {
    required String videoCode,
    required String videoTitle,
    String language = 'en',
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => AiEvaluationSheet(
        videoCode: videoCode,
        videoTitle: videoTitle,
        language: language,
      ),
    );
  }
}

class _AiEvaluationSheetState extends State<AiEvaluationSheet> {
  bool _loading = false;
  AiEvaluationLog? _evaluation;
  List<AiEvaluationLog> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final records = await DatabaseService.findByCondition(
      () => AiEvaluationLog(),
      where: 'resource_code = ? AND is_deleted = 0',
      whereArgs: [widget.videoCode],
      orderBy: 'evaluated_at DESC',
    );
    if (mounted) {
      setState(() {
        _history = records;
        if (records.isNotEmpty) _evaluation = records.first;
      });
    }
  }

  Future<void> _requestEvaluation() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final records = await DatabaseService.findByCondition(
        () => RecordingRecord(),
        where: 'resource_code = ? AND is_deleted = 0',
        whereArgs: [widget.videoCode],
      );

      if (records.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('暂无跟读记录，请先跟读后再请求AI点评')),
          );
        }
        return;
      }

      final sentenceRecords = records.where((r) => r.scope == 'sentence').toList();
      final fullRecords = records.where((r) => r.scope == 'full').toList();

      final sentenceAvg = sentenceRecords.isNotEmpty
          ? sentenceRecords.map((r) => r.overallScore ?? 0).reduce((a, b) => a + b) / sentenceRecords.length
          : null;
      final fullAvg = fullRecords.isNotEmpty
          ? fullRecords.map((r) => r.overallScore ?? 0).reduce((a, b) => a + b) / fullRecords.length
          : null;

      double? resourceScore;
      if (sentenceAvg != null && fullAvg != null) {
        resourceScore = (sentenceAvg + fullAvg) / 2;
      } else if (sentenceAvg != null) {
        resourceScore = sentenceAvg;
      } else if (fullAvg != null) {
        resourceScore = fullAvg;
      }

      final followSummary = <String>[];
      for (final r in records.take(10)) {
        followSummary.add('${r.refText ?? ""}: ${r.overallScore?.round() ?? "?"}分');
      }

      final result = await AiService.callAiProxy(
        ruleCode: 'ai_audio_evaluation',
        scene: 'audio_player',
        entry: 'ai_commentary',
        word: widget.videoTitle,
        params: {
          'resource_title': widget.videoTitle,
          'language': widget.language,
          'sentence_follow_avg': sentenceAvg?.round(),
          'sentence_follow_count': sentenceRecords.length,
          'full_follow_avg': fullAvg?.round(),
          'full_follow_count': fullRecords.length,
          'resource_score': resourceScore?.round(),
          'follow_summary': followSummary.join('\n'),
        },
      );

      if (!mounted) return;

      final evaluationJson = result.success ? result.toJson().toString() : '{}';
      final summary = result.success ? (result.translation ?? result.wordMeaningInContext ?? result.word) : null;

      final level = _determineLevel(resourceScore);

      final log = AiEvaluationLog(
        resourceCode: widget.videoCode,
        resourceType: 'music',
        resourceTitle: widget.videoTitle,
        language: widget.language,
        sentenceFollowAvgScore: sentenceAvg,
        sentenceFollowCount: sentenceRecords.length,
        fullFollowAvgScore: fullAvg,
        fullFollowCount: fullRecords.length,
        resourceScore: resourceScore,
        evaluationJson: evaluationJson,
        summary: summary,
        overallLevel: level,
      );
      await DatabaseService.insert(log);

      if (mounted) {
        await _loadHistory();
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI点评请求失败')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _determineLevel(double? score) {
    if (score == null) return 'N/A';
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    return 'F';
  }

  Color _scoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 75) return Colors.orange;
    if (score >= 60) return Colors.deepOrange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text('AI 点评', style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w600)),
                const Spacer(),
                GestureDetector(
                  onTap: _loading ? null : _requestEvaluation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: _loading ? null : AppColors.sunsetGradient,
                      color: _loading ? Colors.grey : null,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_loading)
                          const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        else
                          Icon(Icons.auto_awesome, size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(_loading ? '分析中...' : '请求点评', style: TextStyle(color: Colors.white, fontSize: 12.sp)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _evaluation != null
                ? _buildEvaluationContent(controller)
                : _buildEmptyState(controller),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ScrollController controller) {
    return ListView(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        SizedBox(height: 40),
        Icon(Icons.auto_awesome_outlined, size: 48, color: Colors.white24),
        SizedBox(height: 12),
        Text(
          '暂无AI点评\n跟读练习后点击"请求点评"',
          style: TextStyle(color: Colors.white54, fontSize: 13.sp),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEvaluationContent(ScrollController controller) {
    final e = _evaluation!;
    return ListView(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (e.resourceScore != null)
          Center(
            child: Column(
              children: [
                Text(
                  '${e.resourceScore!.round()}',
                  style: TextStyle(
                    color: _scoreColor(e.resourceScore!),
                    fontSize: 48.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                if (e.overallLevel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    decoration: BoxDecoration(
                      color: _scoreColor(e.resourceScore!).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      e.overallLevel!,
                      style: TextStyle(color: _scoreColor(e.resourceScore!), fontSize: 12.sp, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _statItem('单句均分', e.sentenceFollowAvgScore),
            _statItem('单句次数', e.sentenceFollowCount.toDouble(), showInt: true),
            _statItem('全文均分', e.fullFollowAvgScore),
            _statItem('全文次数', e.fullFollowCount.toDouble(), showInt: true),
          ],
        ),
        const SizedBox(height: 16),
        if (e.summary != null && e.summary!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              e.summary!,
              style: TextStyle(color: Colors.white, fontSize: 13.sp, height: 1.6),
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (_history.length > 1) ...[
          Text('历史点评', style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
          const SizedBox(height: 8),
          ..._history.skip(1).map((h) => _historyItem(h)),
        ],
      ],
    );
  }

  Widget _statItem(String label, double? value, {bool showInt = false}) {
    return Column(
      children: [
        Text(
          value != null ? (showInt ? value.round().toString() : value.round().toString()) : '-',
          style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.white54, fontSize: 10.sp)),
      ],
    );
  }

  Widget _historyItem(AiEvaluationLog h) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          if (h.resourceScore != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _scoreColor(h.resourceScore!).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${h.resourceScore!.round()}',
                style: TextStyle(color: _scoreColor(h.resourceScore!), fontSize: 12.sp, fontWeight: FontWeight.bold),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              h.summary ?? '无点评内容',
              style: TextStyle(color: Colors.white70, fontSize: 11.sp),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            _fmtDate(h.evaluatedAt),
            style: TextStyle(color: Colors.white38, fontSize: 9.sp),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) {
    return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
