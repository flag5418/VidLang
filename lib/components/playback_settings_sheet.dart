library;

import 'package:flutter/material.dart';
import 'package:vidlang/models/playback_settings.dart';
import 'package:vidlang/theme/theme.dart';

/// 片头/片尾/封面截图设置底部面板
class PlaybackSettingsSheet extends StatefulWidget {
  final PlaybackSettings initial;
  final String title;
  final Future<void> Function(PlaybackSettings settings) onSave;

  const PlaybackSettingsSheet({
    super.key,
    required this.initial,
    required this.onSave,
    this.title = '播放与封面',
  });

  static Future<void> show(
    BuildContext context, {
    required PlaybackSettings initial,
    required Future<void> Function(PlaybackSettings) onSave,
    String title = '播放与封面',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (ctx) => PlaybackSettingsSheet(
        initial: initial,
        onSave: onSave,
        title: title,
      ),
    );
  }

  @override
  State<PlaybackSettingsSheet> createState() => _PlaybackSettingsSheetState();
}

class _PlaybackSettingsSheetState extends State<PlaybackSettingsSheet> {
  late bool _skipOpening;
  late int _openingSec;
  late bool _skipEnding;
  late int _endingSec;
  late int _thumbnailSec;

  @override
  void initState() {
    super.initState();
    _skipOpening = widget.initial.skipOpening;
    _openingSec = widget.initial.skipOpeningDuration;
    _skipEnding = widget.initial.skipEnding;
    _endingSec = widget.initial.skipEndingDuration;
    _thumbnailSec = widget.initial.thumbnailTime;
  }

  PlaybackSettings get _settings => PlaybackSettings(
        skipOpening: _skipOpening,
        skipOpeningDuration: _openingSec,
        skipEnding: _skipEnding,
        skipEndingDuration: _endingSec,
        thumbnailTime: _thumbnailSec,
      );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        bottom + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: AppSpacing.md),
          _switchRow(
            colorScheme,
            '跳过片头',
            _skipOpening,
            (v) => setState(() => _skipOpening = v),
          ),
          if (_skipOpening) _secondsRow(colorScheme, '片头时长（秒）', _openingSec, (v) => setState(() => _openingSec = v)),
          _switchRow(
            colorScheme,
            '跳过片尾',
            _skipEnding,
            (v) => setState(() => _skipEnding = v),
          ),
          if (_skipEnding) _secondsRow(colorScheme, '片尾时长（秒）', _endingSec, (v) => setState(() => _endingSec = v)),
          _secondsRow(
            colorScheme,
            '封面截图时间（秒）',
            _thumbnailSec,
            (v) => setState(() => _thumbnailSec = v),
            min: 1,
            max: 600,
          ),
          SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: () async {
              await widget.onSave(_settings);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Widget _switchRow(
    ColorScheme colorScheme,
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: value,
      onChanged: onChanged,
      activeThumbColor: colorScheme.primary,
    );
  }

  Widget _secondsRow(
    ColorScheme colorScheme,
    String label,
    int value,
    ValueChanged<int> onChanged, {
    int min = 0,
    int max = 300,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          IconButton(
            icon: const Icon(Icons.remove_rounded, size: 20),
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          Text('$value', style: Theme.of(context).textTheme.titleMedium),
          IconButton(
            icon: AppIcons.getIcon(AppIcons.add, size: 20),
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}
