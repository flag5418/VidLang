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
          if (pronunciationVisible && subtitle.pronunciation != null && subtitle.pronunciation!.isNotEmpty)
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

class PronunciationEntry {
  final String word;
  final String zh;
  const PronunciationEntry({required this.word, required this.zh});
}
