import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:vidlang/services/native/ios_native_features.dart';
import 'package:vidlang/services/word_book/word_book_service.dart';
import 'package:vidlang/utils/adaptive.dart';
import 'package:vidlang/utils/app_globals.dart';
import 'package:vidlang/theme/theme.dart';

/// 免费模式翻译弹窗（紧凑弹窗 V5）
///
/// 设计参考：iOS 系统词典 / 欧路词典 / 有道词典的简洁弹窗风格
/// - 紧凑尺寸：固定宽度，最大高度限制，非全屏页面
/// - 顶部操作区：原文 + 右上角发音/收藏/关闭按钮
/// - 翻译区：无卡片背景、无渐变装饰，纯文本层次排版
/// - 发音按钮：状态正确管理，手动触发，播放中显示 spinner
class FreeTranslationCard extends StatefulWidget {
  final String word;
  final String? contextSentence;
  final String? translation;
  final bool success;
  final String? error;

  final Future<bool> Function({
    required String word,
    String? contextSentence,
    required String sourceType,
    required String sourceCode,
    String? sourceTitle,
  })?
  onSaveWord;

  final String sourceType;
  final String sourceCode;
  final String? sourceTitle;

  final VoidCallback onClose;

  const FreeTranslationCard({
    super.key,
    required this.word,
    this.contextSentence,
    this.translation,
    this.success = true,
    this.error,
    this.onSaveWord,
    this.sourceType = 'video',
    this.sourceCode = '',
    this.sourceTitle,
    required this.onClose,
  });

  @override
  State<FreeTranslationCard> createState() => _FreeTranslationCardState();
}

class _FreeTranslationCardState extends State<FreeTranslationCard> {
  bool _saving = false;
  bool _saved = false;
  bool _isSpeaking = false;

  bool get _isSingleWord => WordBookService.isSingleWord(widget.word);

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadSavedState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedState() async {
    try {
      bool saved;
      if (_isSingleWord) {
        saved = await WordBookService.isWordSaved(
          word: widget.word,
          sourceType: widget.sourceType,
          sourceCode: widget.sourceCode,
        );
      } else {
        saved = await WordBookService.isSentenceSaved(
          text: widget.word,
          sourceType: widget.sourceType,
          sourceCode: widget.sourceCode,
        );
      }
      if (!mounted) return;
      setState(() => _saved = saved);
    } catch (_) {}
  }

  Future<void> _speakWord() async {
    if (_isSpeaking) return;
    setState(() => _isSpeaking = true);
    try {
      await IosNativeFeatures.speak(text: widget.word, language: 'en-US');
      await Future.delayed(const Duration(milliseconds: 2500));
    } catch (e) {
      dev.log('🔊 [FreeTranslationCard] TTS 异常: $e', name: 'FreeTranslationCard');
    } finally {
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  Future<void> _handleToggleSave() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (_saved) {
        bool ok;
        if (_isSingleWord) {
          ok = await WordBookService.unsaveWord(
            word: widget.word,
            sourceType: widget.sourceType,
            sourceCode: widget.sourceCode,
          );
        } else {
          ok = await WordBookService.unsaveSentence(
            text: widget.word,
            sourceType: widget.sourceType,
            sourceCode: widget.sourceCode,
          );
        }
        if (!mounted) return;
        setState(() {
          _saving = false;
          if (ok) _saved = false;
        });
        if (ok) TDToast.showText('已取消收藏', context: context);
        return;
      }

      bool ok;
      if (_isSingleWord) {
        if (widget.onSaveWord == null) {
          ok = false;
        } else {
          ok = await widget.onSaveWord!(
            word: widget.word,
            contextSentence: widget.contextSentence,
            sourceType: widget.sourceType,
            sourceCode: widget.sourceCode,
            sourceTitle: widget.sourceTitle,
          );
        }
      } else {
        final wb = await WordBookService.saveSentence(
          text: widget.word,
          translation: widget.translation,
          sourceType: widget.sourceType,
          sourceCode: widget.sourceCode,
          sourceTitle: widget.sourceTitle,
        );
        ok = wb != null;
      }

      if (!mounted) return;
      setState(() {
        _saving = false;
        if (ok) _saved = true;
      });
      if (ok) {
        TDToast.showSuccess('已收藏「${widget.word}」', context: context);
      }
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final brightness = Theme.of(context).brightness;
    final screenSize = MediaQuery.of(context).size;
    final isWide = AppGlobals.isTablet;

    // 紧凑弹窗尺寸：固定宽度，最大高度限制
    final cardWidth = isWide ? 380.0 : screenSize.width * 0.82;
    final maxHeight = screenSize.height * 0.48;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: Adaptive.w(24),
        vertical: Adaptive.h(24),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: cardWidth,
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(Adaptive.r(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: brightness == Brightness.dark ? 0.5 : 0.12,
              ),
              blurRadius: Adaptive.w(24),
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 顶部栏：原文 + 操作按钮 ──
            _buildHeader(cs),
            // ── 分割线 ──
            Divider(
              height: 1,
              thickness: 0.5,
              color: cs.outlineVariant.withValues(
                alpha: brightness == Brightness.dark ? 0.3 : 0.15,
              ),
            ),
            // ── 滚动内容区 ──
            Flexible(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(
                  Adaptive.w(20),
                  Adaptive.h(16),
                  Adaptive.w(20),
                  Adaptive.h(20),
                ),
                child: widget.success ? _buildContent(cs) : _buildErrorContent(cs),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 顶部栏：原文大字 + 右上角操作按钮组 ──

  Widget _buildHeader(AppColorsData cs) {
    final word = widget.word;
    final hasContext = (widget.contextSentence ?? '').isNotEmpty;
    final displayText = hasContext ? widget.contextSentence! : word;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Adaptive.w(20),
        Adaptive.h(16),
        Adaptive.w(12),
        Adaptive.h(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 原文文本（占满剩余空间）
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: Adaptive.h(2)),
              child: Text(
                displayText,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: displayText.length > 25
                      ? Adaptive.sp(15)
                      : Adaptive.sp(18),
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          SizedBox(width: Adaptive.w(8)),
          // 右上角操作按钮组：发音 | 收藏 | 关闭
          _buildActionButtons(cs),
        ],
      ),
    );
  }

  // ── 右上角操作按钮组 ──

  Widget _buildActionButtons(AppColorsData cs) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 发音按钮
        _buildSpeakIcon(cs),
        SizedBox(width: Adaptive.w(4)),
        // 收藏按钮
        if (widget.onSaveWord != null) ...[
          _buildSaveIcon(cs),
          SizedBox(width: Adaptive.w(4)),
        ],
        // 关闭按钮
        _buildCloseButton(cs),
      ],
    );
  }

  Widget _buildSpeakIcon(AppColorsData cs) {
    return InkWell(
      onTap: _isSpeaking ? null : _speakWord,
      borderRadius: BorderRadius.circular(Adaptive.r(10)),
      child: Container(
        width: Adaptive.w(28),
        height: Adaptive.h(28),
        decoration: BoxDecoration(
          color: _isSpeaking
              ? cs.primary.withValues(alpha: 0.12)
              : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(Adaptive.r(10)),
        ),
        child: _isSpeaking
            ? Center(
                child: SizedBox(
                  width: Adaptive.icon(14),
                  height: Adaptive.icon(14),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.primary,
                  ),
                ),
              )
            : Icon(
                AppIcons.volumeUp,
                size: Adaptive.icon(14),
                color: cs.onSurfaceVariant,
              ),
      ),
    );
  }

  Widget _buildSaveIcon(AppColorsData cs) {
    return InkWell(
      onTap: _saving ? null : _handleToggleSave,
      borderRadius: BorderRadius.circular(Adaptive.r(10)),
      child: Container(
        width: Adaptive.w(28),
        height: Adaptive.h(28),
        decoration: BoxDecoration(
          color: _saved
              ? cs.primary.withValues(alpha: 0.12)
              : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(Adaptive.r(10)),
        ),
        child: _saving
            ? Center(
                child: SizedBox(
                  width: Adaptive.icon(14),
                  height: Adaptive.icon(14),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.primary,
                  ),
                ),
              )
            : Icon(
                _saved ? AppIcons.star : AppIcons.starOutline,
                size: Adaptive.icon(14),
                color: _saved ? cs.primary : cs.onSurfaceVariant,
              ),
      ),
    );
  }

  Widget _buildCloseButton(AppColorsData cs) {
    return InkWell(
      onTap: widget.onClose,
      borderRadius: BorderRadius.circular(Adaptive.r(10)),
      child: Container(
        width: Adaptive.w(28),
        height: Adaptive.h(28),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(Adaptive.r(10)),
        ),
        child: Icon(
          Icons.close_rounded,
          size: Adaptive.icon(14),
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }

  // ── 内容区：简洁翻译展示 ──

  Widget _buildContent(AppColorsData cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 翻译内容（无卡片背景，直接展示）
        _buildTranslation(cs),
      ],
    );
  }

  Widget _buildTranslation(AppColorsData cs) {
    final translation = widget.translation ?? '';

    if (translation.isEmpty) {
      return Text(
        '暂无翻译',
        style: TextStyle(
          color: cs.onSurfaceVariant,
          fontSize: Adaptive.sp(14),
        ),
      );
    }

    // 尝试分割多个释义
    final parts = translation.split(RegExp(r'[，,、；;]'));
    final definitions = parts.where((p) => p.trim().isNotEmpty).map((p) => p.trim()).toList();

    if (definitions.length > 1) {
      return _buildMultiDefinitions(definitions, cs);
    }

    // 单条翻译：直接显示，字号稍大
    return Text(
      translation,
      style: TextStyle(
        color: cs.onSurface,
        fontSize: Adaptive.sp(15),
        fontWeight: FontWeight.w500,
        height: 1.6,
      ),
    );
  }

  Widget _buildMultiDefinitions(List<String> definitions, AppColorsData cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: definitions.asMap().entries.map((entry) {
        final index = entry.key + 1;
        final def = entry.value;
        final isLast = index == definitions.length;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : Adaptive.h(8)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 序号：主色小圆点替代数字标签
              Container(
                width: Adaptive.w(6),
                height: Adaptive.h(6),
                margin: EdgeInsets.only(
                  top: Adaptive.h(6),
                  right: Adaptive.w(10),
                ),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(Adaptive.r(3)),
                ),
              ),
              Expanded(
                child: Text(
                  def,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: Adaptive.sp(14),
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── 错误状态 ──

  Widget _buildErrorContent(AppColorsData cs) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Adaptive.h(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: Adaptive.icon(28),
            color: cs.error.withValues(alpha: 0.6),
          ),
          SizedBox(height: Adaptive.h(10)),
          Text(
            widget.error ?? '查询失败',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: Adaptive.sp(14),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: Adaptive.h(4)),
          Text(
            '请检查网络连接后重试',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: Adaptive.sp(12),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
