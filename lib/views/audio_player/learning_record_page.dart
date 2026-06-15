import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vidlang/models/ai_evaluation_log.dart';
import 'package:vidlang/models/recording_record.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/views/audio_player/ai_evaluation_sheet.dart';

class LearningRecordPage extends StatefulWidget {
  final String videoCode;
  final String videoTitle;

  const LearningRecordPage({
    super.key,
    required this.videoCode,
    required this.videoTitle,
  });

  @override
  State<LearningRecordPage> createState() => _LearningRecordPageState();
}

class _LearningRecordPageState extends State<LearningRecordPage> {
  List<RecordingRecord> _records = [];
  List<AiEvaluationLog> _evaluations = [];
  bool _loading = true;

  double? _sentenceAvg;
  double? _fullAvg;
  double? _resourceScore;
  int _totalFollowCount = 0;
  int _uniqueSentenceCount = 0;
  Map<String, dynamic>? _bestRecord;
  Map<String, dynamic>? _worstRecord;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final records = await DatabaseService.findByCondition(
      () => RecordingRecord(),
      where: 'resource_code = ? AND is_deleted = 0',
      whereArgs: [widget.videoCode],
      orderBy: 'created_at DESC',
    );

    final evaluations = await DatabaseService.findByCondition(
      () => AiEvaluationLog(),
      where: 'resource_code = ? AND is_deleted = 0',
      whereArgs: [widget.videoCode],
      orderBy: 'evaluated_at DESC',
    );

    final sentenceRecords = records.where((r) => r.scope == 'sentence').toList();
    final fullRecords = records.where((r) => r.scope == 'full').toList();

    double? sentenceAvg;
    if (sentenceRecords.isNotEmpty) {
      final scored = sentenceRecords.where((r) => r.overallScore != null).toList();
      if (scored.isNotEmpty) {
        sentenceAvg = scored.map((r) => r.overallScore!).reduce((a, b) => a + b) / scored.length;
      }
    }

    double? fullAvg;
    if (fullRecords.isNotEmpty) {
      final scored = fullRecords.where((r) => r.overallScore != null).toList();
      if (scored.isNotEmpty) {
        fullAvg = scored.map((r) => r.overallScore!).reduce((a, b) => a + b) / scored.length;
      }
    }

    double? resourceScore;
    if (sentenceAvg != null && fullAvg != null) {
      resourceScore = (sentenceAvg + fullAvg) / 2;
    } else {
      resourceScore = sentenceAvg ?? fullAvg;
    }

    RecordingRecord? best;
    RecordingRecord? worst;
    final scored = records.where((r) => r.overallScore != null).toList();
    if (scored.isNotEmpty) {
      scored.sort((a, b) => (b.overallScore ?? 0).compareTo(a.overallScore ?? 0));
      best = scored.first;
      worst = scored.last;
    }

    final uniqueSentences = records.where((r) => r.scope == 'sentence').map((r) => r.sentenceCode).toSet();

    if (mounted) {
      setState(() {
        _records = records;
        _evaluations = evaluations;
        _sentenceAvg = sentenceAvg;
        _fullAvg = fullAvg;
        _resourceScore = resourceScore;
        _totalFollowCount = records.length;
        _uniqueSentenceCount = uniqueSentences.length;
        _bestRecord = best != null ? {'refText': best.refText, 'score': best.overallScore} : null;
        _worstRecord = worst != null ? {'refText': worst.refText, 'score': worst.overallScore} : null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('学习记录', style: TextStyle(color: Colors.white, fontSize: 16.sp)),
        backgroundColor: AppColors.surface,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildScoreOverview(),
                  const SizedBox(height: 16),
                  _buildStatsGrid(),
                  const SizedBox(height: 16),
                  if (_bestRecord != null || _worstRecord != null)
                    _buildBestWorst(),
                  const SizedBox(height: 16),
                  _buildEvaluationHistory(),
                  const SizedBox(height: 16),
                  _buildFollowHistory(),
                ],
              ),
            ),
    );
  }

  Widget _buildScoreOverview() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withValues(alpha: 0.2), AppColors.secondary.withValues(alpha: 0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(widget.videoTitle, style: TextStyle(color: Colors.white70, fontSize: 12.sp), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          if (_resourceScore != null) ...[
            Text(
              '${_resourceScore!.round()}',
              style: TextStyle(
                color: _scoreColor(_resourceScore!),
                fontSize: 56.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text('综合评分', style: TextStyle(color: Colors.white54, fontSize: 12.sp)),
          ] else
            Column(
              children: [
                Icon(Icons.mic_none_rounded, size: 48, color: Colors.white24),
                const SizedBox(height: 8),
                Text('暂无跟读评分', style: TextStyle(color: Colors.white38, fontSize: 13.sp)),
              ],
            ),
          if (_sentenceAvg != null || _fullAvg != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_sentenceAvg != null) _miniScore('单句', _sentenceAvg!),
                  if (_sentenceAvg != null && _fullAvg != null)
                    Container(width: 1, height: 16, color: Colors.white12, margin: const EdgeInsets.symmetric(horizontal: 16)),
                  if (_fullAvg != null) _miniScore('全文', _fullAvg!),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _miniScore(String label, double score) {
    return Column(
      children: [
        Text('${score.round()}', style: TextStyle(color: _scoreColor(score), fontSize: 18.sp, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.white54, fontSize: 10.sp)),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem(Icons.mic_rounded, '跟读次数', '$_totalFollowCount'),
          _statItem(Icons.text_fields_rounded, '覆盖句数', '$_uniqueSentenceCount'),
          _statItem(Icons.auto_awesome_rounded, 'AI点评', '${_evaluations.length}'),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.white54, fontSize: 10.sp)),
      ],
    );
  }

  Widget _buildBestWorst() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('表现分析', style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (_bestRecord != null)
            _analysisRow(Icons.thumb_up_outlined, '最佳', _bestRecord!['refText'] ?? '', _bestRecord!['score'] as double, Colors.green),
          if (_bestRecord != null && _worstRecord != null) const SizedBox(height: 8),
          if (_worstRecord != null)
            _analysisRow(Icons.thumb_down_outlined, '待提升', _worstRecord!['refText'] ?? '', _worstRecord!['score'] as double, Colors.orange),
        ],
      ),
    );
  }

  Widget _analysisRow(IconData icon, String label, String text, double score, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(color: Colors.white70, fontSize: 12.sp), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
          child: Text('${score.round()}', style: TextStyle(color: color, fontSize: 11.sp, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildEvaluationHistory() {
    if (_evaluations.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('AI 点评历史', style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w600)),
            const Spacer(),
            GestureDetector(
              onTap: () => AiEvaluationSheet.show(
                context,
                videoCode: widget.videoCode,
                videoTitle: widget.videoTitle,
              ),
              child: Text('查看详情', style: TextStyle(color: AppColors.primary, fontSize: 11.sp)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._evaluations.take(3).map((e) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (e.resourceScore != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: _scoreColor(e.resourceScore!).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${e.resourceScore!.round()}', style: TextStyle(color: _scoreColor(e.resourceScore!), fontSize: 11.sp, fontWeight: FontWeight.bold)),
                    ),
                  const SizedBox(width: 8),
                  if (e.overallLevel != null)
                    Text(e.overallLevel!, style: TextStyle(color: Colors.white54, fontSize: 11.sp)),
                  const Spacer(),
                  Text(_fmtDate(e.evaluatedAt), style: TextStyle(color: Colors.white38, fontSize: 9.sp)),
                ],
              ),
              if (e.summary != null && e.summary!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(e.summary!, style: TextStyle(color: Colors.white70, fontSize: 11.sp, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildFollowHistory() {
    if (_records.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('跟读记录', style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ..._records.take(20).map((r) => Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              if (r.overallScore != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: _scoreColor(r.overallScore!).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${r.overallScore!.round()}', style: TextStyle(color: _scoreColor(r.overallScore!), fontSize: 11.sp, fontWeight: FontWeight.bold)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(6)),
                  child: Text('--', style: TextStyle(color: Colors.white38, fontSize: 11.sp)),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  r.refText ?? '',
                  style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                r.scope == 'sentence' ? '单句' : '全文',
                style: TextStyle(color: Colors.white38, fontSize: 9.sp),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Color _scoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 75) return Colors.orange;
    if (score >= 60) return Colors.deepOrange;
    return Colors.red;
  }

  String _fmtDate(DateTime d) {
    return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
