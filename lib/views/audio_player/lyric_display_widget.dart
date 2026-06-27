import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/widgets/selectable_english_line.dart';

class LyricDisplayWidget extends StatelessWidget {
  final Subtitles subtitle;
  final bool subtitleVisible;
  final bool translateVisible;
  final bool pronunciationVisible;
  final double fontSize;
  final void Function(List<String> words)? onSelectionChanged;

  const LyricDisplayWidget({
    super.key,
    required this.subtitle,
    required this.subtitleVisible,
    required this.translateVisible,
    required this.pronunciationVisible,
    this.fontSize = 20.0,
    this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pronMap = parsePronunciationMap(subtitle.pronunciationMapJson);
    final hasAlignedPron = pronMap != null && pronMap.isNotEmpty && pronunciationVisible;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.playerSubtitleBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (subtitleVisible && subtitle.content.isNotEmpty)
            onSelectionChanged != null
                ? SelectableEnglishLine(
                    text: subtitle.content,
                    fontSize: fontSize,
                    fontColor: Colors.white,
                    selectedBgColor: AppColors.primary.withValues(alpha: 0.7),
                    onStartSelection: () {},
                    onSelectionChanged: onSelectionChanged!,
                  )
                : Text(
                    subtitle.content,
                    style: TextStyle(color: Colors.white, fontSize: fontSize, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
          if (pronunciationVisible && !hasAlignedPron && subtitle.pronunciation != null && subtitle.pronunciation!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                subtitle.pronunciation!,
                style: TextStyle(
                  color: AppColors.primary.withValues(alpha: 0.8),
                  fontSize: fontSize - 4,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          if (hasAlignedPron && subtitleVisible)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _AlignedPronunciationRow(
                content: subtitle.content,
                pronMap: pronMap,
                fontSize: fontSize - 4,
              ),
            ),
          if (translateVisible && subtitle.contentTranslate != null && subtitle.contentTranslate!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                subtitle.contentTranslate!,
                style: TextStyle(
                  color: AppColors.playerSubtitleTranslate,
                  fontSize: fontSize - 4,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  static List<PronunciationEntry>? parsePronunciationMap(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final list = jsonDecode(json) as List;
      return list.map((e) => PronunciationEntry(
        word: e['word'] as String? ?? '',
        zh: e['zh'] as String? ?? '',
      )).toList();
    } catch (_) {
      return null;
    }
  }
}

class _AlignedPronunciationRow extends StatelessWidget {
  final String content;
  final List<PronunciationEntry> pronMap;
  final double fontSize;

  const _AlignedPronunciationRow({
    required this.content,
    required this.pronMap,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final pronLookup = <String, String>{};
    for (final entry in pronMap) {
      pronLookup[entry.word.toLowerCase()] = entry.zh;
    }

    final tokens = content.split(RegExp(r'(\s+)'));
    final spans = <InlineSpan>[];

    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      final clean = token.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();
      final zh = pronLookup[clean] ?? '';

      if (zh.isNotEmpty) {
        spans.add(TextSpan(
          children: [
            TextSpan(
              text: zh,
              style: TextStyle(
                color: AppColors.primary.withValues(alpha: 0.8),
                fontSize: fontSize,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ));
      } else {
        final spacing = zh.isEmpty && clean.isNotEmpty ? token.length : 0;
        if (spacing > 0) {
          spans.add(TextSpan(
            text: ' ' * (token.length > 1 ? token.length : 1),
            style: TextStyle(fontSize: fontSize, color: Colors.transparent),
          ));
        }
      }

      if (i < tokens.length - 1) {
        spans.add(TextSpan(
          text: ' ',
          style: TextStyle(fontSize: fontSize, color: Colors.transparent),
        ));
      }
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(children: spans),
    );
  }
}

class PronunciationEntry {
  final String word;
  final String zh;
  const PronunciationEntry({required this.word, required this.zh});
}
