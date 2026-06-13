import 'package:flutter/material.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/models/word_card_data.dart';
import 'package:vidlang/services/word_book_service.dart';
import 'package:vidlang/services/tts_service.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/widgets/recharge_dialog.dart';

/// 单词/翻译弹窗组件（免费/付费共用）
/// 余额不足时自动弹出 RechargeDialog
class WordCard extends StatefulWidget {
  final WordCardData data;
  final VoidCallback onClose;
  final bool compact;
  final VoidCallback? onGoRecharge;
  final VoidCallback? onSpeak;

  /// 收藏回调，返回是否成功
  final Future<bool> Function()? onSaveWord;

  /// 是否为可收藏的单个单词
  final bool canSave;

  /// 是否已收藏
  final bool isSaved;

  const WordCard({
    super.key,
    required this.data,
    required this.onClose,
    this.compact = false,
    this.onGoRecharge,
    this.onSpeak,
    this.onSaveWord,
    this.canSave = false,
    this.isSaved = false,
  });

  @override
  State<WordCard> createState() => _WordCardState();
}

extension WordBookWordCardMapper on WordBook {
  WordCardData toWordCardData() {
    return WordCardData(
      word: word,
      phonetic: phoneticUk ?? phoneticUs,
      definitions: WordBookService.parseDefinitions(definitionsJson),
      source: 'native',
    );
  }
}

class _WordCardState extends State<WordCard> {
  bool _rechargeShown = false;
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _saved = widget.isSaved;
    // 余额不足时，延迟显示充值弹窗
    if (widget.data.isInsufficientBalance && !_rechargeShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showRechargeDialog();
      });
    }
  }

  void _showRechargeDialog() {
    if (_rechargeShown) return;
    _rechargeShown = true;
    RechargeDialog.show(
      context,
      requiredCny: widget.data.costCny ?? 0.01,
      balanceCny: widget.data.balanceAfter ?? 0,
      featureName: 'AI释义',
      onGoRecharge: widget.onGoRecharge,
    );
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final t = MediaQuery.of(context).size.width >= 768;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(maxWidth: t ? 500 : 320),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
            boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 8))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context, t),
              if (widget.data.error != null && !widget.data.isInsufficientBalance) _buildError(context),
              if (!widget.compact && widget.data.phonetic != null) _buildPhonetic(context),
              if (!widget.compact && widget.data.definitions.isNotEmpty) _buildDefinitions(context),
              if (!widget.compact && widget.data.examples.isNotEmpty) _buildExamples(context),
              if (widget.data.translation != null && widget.data.translation!.isNotEmpty) _buildTranslation(context),
              if (widget.data.costCny != null && widget.data.success) _buildCost(context),
              const SizedBox(height: 12),
              // 收藏按钮：仅单个单词可收藏
              _buildSaveButton(context),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text('关闭', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool t) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            widget.data.word,
            style: TextStyle(color: Colors.white, fontSize: widget.compact ? 18 : 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
        if (!widget.compact || widget.data.phonetic != null) SizedBox(width: 8),
        GestureDetector(
          onTap: widget.onSpeak ?? () => TtsService().speakWord(widget.data.word),
          child: Icon(Icons.volume_up_rounded, color: AppColors.primary, size: 20),
        ),
      ],
    );
  }

  Widget _buildPhonetic(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 4),
      child: Text('/${widget.data.phonetic}/', style: TextStyle(color: AppColors.playerSubtitleTranslate, fontSize: 14)),
    );
  }

  Widget _buildDefinitions(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: widget.data.definitions.map((d) {
            return Padding(
              padding: EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (d.partOfSpeech != null)
                    Container(
                      margin: EdgeInsets.only(right: 6, top: 2),
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        d.partOfSpeech!,
                        style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.meaning, style: TextStyle(color: Colors.white, fontSize: 14)),
                        if (d.example != null) Text(d.example!, style: TextStyle(color: AppColors.playerSubtitleTranslate, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildExamples(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '例句',
              style: TextStyle(color: AppColors.playerSubtitleTranslate, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            ...widget.data.examples.map(
              (e) => Padding(
                padding: EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.english, style: TextStyle(color: Colors.white, fontSize: 13)),
                    if (e.chinese != null) Text(e.chinese!, style: TextStyle(color: AppColors.playerSubtitleTranslate, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranslation(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(widget.data.translation!, style: TextStyle(color: Colors.white, fontSize: 14)),
      ),
    );
  }

  Widget _buildCost(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.monetization_on_outlined, size: 14, color: AppColors.playerSubtitleTranslate),
          SizedBox(width: 4),
          Text(
            '-¥${widget.data.costCny!.toStringAsFixed(2)}  |  余额 ¥${widget.data.balanceAfter?.toStringAsFixed(2) ?? '--'}',
            style: TextStyle(color: AppColors.playerSubtitleTranslate, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 12),
      child: Text(
        widget.data.error!,
        style: TextStyle(color: Colors.redAccent, fontSize: 13),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    // 不可收藏（多词选择或查询失败）：不显示收藏按钮
    if (!widget.canSave || !widget.data.success) {
      return const SizedBox.shrink();
    }

    final isSaved = _saved;
    final isSaving = _saving;

    return GestureDetector(
      onTap: isSaving || isSaved
          ? null
          : () async {
              if (widget.onSaveWord == null) return;
              setState(() => _saving = true);
              try {
                final ok = await widget.onSaveWord!();
                if (!mounted) return;
                setState(() {
                  _saving = false;
                  if (ok) _saved = true;
                });
                if (ok) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已收藏「${widget.data.word}」'),
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (_) {
                if (mounted) setState(() => _saving = false);
              }
            },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSaved
              ? AppColors.primary.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSaved ? AppColors.primary : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSaving)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              )
            else
              Icon(
                isSaved ? Icons.star_rounded : Icons.star_border_rounded,
                size: 16,
                color: isSaved ? AppColors.primary : Colors.white54,
              ),
            SizedBox(width: 6),
            Text(
              isSaving ? '收藏中...' : (isSaved ? '已收藏' : '收藏到生词本'),
              style: TextStyle(
                color: isSaved ? AppColors.primary : Colors.white70,
                fontSize: 12,
                fontWeight: isSaved ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
