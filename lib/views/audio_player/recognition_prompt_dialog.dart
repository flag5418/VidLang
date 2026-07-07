import 'package:flutter/material.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';

class RecognitionPromptDialog extends StatelessWidget {
  final String audioType;
  final String videoName;
  final VoidCallback onSmartMatch;
  final VoidCallback onManualImport;
  final VoidCallback onAppreciate;

  const RecognitionPromptDialog({
    super.key,
    required this.audioType,
    required this.onSmartMatch,
    required this.onManualImport,
    required this.onAppreciate,
    this.videoName = '',
  });

  @override
  Widget build(BuildContext context) {
    final isMusic = audioType == 'music';
    final matchLabel = isMusic ? '智能搜索歌词' : '智能识别字幕';
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: cs.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isMusic ? AppIcons.lyrics : AppIcons.subtitlesOutline,
              color: cs.primary,
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              isMusic ? '暂无歌词' : '暂无字幕',
              style: TextStyle(color: cs.onSurface, fontSize: Adaptive.sp(context, 16), fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              isMusic
                  ? '可以选择搜索歌词或手动导入LRC文件'
                  : '可以选择AI识别音频内容或手动导入字幕文件',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: Adaptive.sp(context, 12)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _actionBtn(matchLabel, AppIcons.autoAwesome, cs.primary, onSmartMatch, cs),
            const SizedBox(height: 10),
            _actionBtn('手动导入', AppIcons.upload, cs.secondary, onManualImport, cs),
            const SizedBox(height: 10),
            _actionBtn('先欣赏吧', AppIcons.headphones, cs.onSurfaceVariant, onAppreciate, cs),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap, ColorScheme cs) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
