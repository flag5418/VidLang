import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/services/settings_service.dart';

/// WordDetailPanel 中各内容区块的枚举
enum WordDetailSection {
  chineseMeaning,
  sentenceTranslation,
  definitions,
  englishMeaning,
  partOfSpeech,
  examples,
  difficulty,
  morphology,
  mnemonic,
}

extension WordDetailSectionX on WordDetailSection {
  String get label {
    switch (this) {
      case WordDetailSection.chineseMeaning:     return '中文释义';
      case WordDetailSection.sentenceTranslation: return '当前句释义';
      case WordDetailSection.definitions:          return '词典释义';
      case WordDetailSection.englishMeaning:       return '英文解释';
      case WordDetailSection.partOfSpeech:         return '词性';
      case WordDetailSection.examples:             return '例句';
      case WordDetailSection.difficulty:           return '单词难度';
      case WordDetailSection.morphology:           return '词形变化';
      case WordDetailSection.mnemonic:             return '记忆技巧';
    }
  }

  String get keyName {
    switch (this) {
      case WordDetailSection.chineseMeaning:     return 'chineseMeaning';
      case WordDetailSection.sentenceTranslation: return 'sentenceTranslation';
      case WordDetailSection.definitions:          return 'definitions';
      case WordDetailSection.englishMeaning:       return 'englishMeaning';
      case WordDetailSection.partOfSpeech:         return 'partOfSpeech';
      case WordDetailSection.examples:             return 'examples';
      case WordDetailSection.difficulty:           return 'difficulty';
      case WordDetailSection.morphology:           return 'morphology';
      case WordDetailSection.mnemonic:             return 'mnemonic';
    }
  }
}

/// 弹窗展示配置
///
/// 控制 WordDetailPanel 中内容区块的显示/隐藏和排列顺序。
/// 通过 SettingsService 持久化到本地数据库。
class WordDetailDisplayConfig {
  /// 区块列表（按显示顺序排列）
  final List<WordDetailSection> sections;

  /// 是否显示发音按钮
  final bool showPronounceButtons;

  const WordDetailDisplayConfig({
    required this.sections,
    this.showPronounceButtons = true,
  });

  /// 从数据库加载用户自定义配置
  static Future<WordDetailDisplayConfig> loadFromSettings() async {
    final rawSections = await SettingsService.getWordDisplaySections();
    if (rawSections.isEmpty) {
      return WordDetailDisplayConfig.defaultPremium;
    }
    final sections = <WordDetailSection>[];
    for (final key in rawSections) {
      if (key == null) continue;
      try {
        final section = WordDetailSection.values.byName(key);
        sections.add(section);
      } catch (_) {
        // ignore invalid section names
      }
    }
    if (sections.isEmpty) {
      return WordDetailDisplayConfig.defaultPremium;
    }
    return WordDetailDisplayConfig(
      sections: sections,
      showPronounceButtons: true,
    );
  }

  /// 保存配置到数据库
  Future<void> saveToSettings() async {
    final keys = sections.map((s) => s.keyName).toList();
    await SettingsService.setWordDisplaySections(keys);
  }

  /// 付费用户默认配置（全量显示）
  static const defaultPremium = WordDetailDisplayConfig(
    sections: [
      WordDetailSection.chineseMeaning,
      WordDetailSection.sentenceTranslation,
      WordDetailSection.definitions,
      WordDetailSection.englishMeaning,
      WordDetailSection.examples,
      WordDetailSection.morphology,
      WordDetailSection.difficulty,
      WordDetailSection.mnemonic,
    ],
    showPronounceButtons: true,
  );

  /// 免费用户默认配置（精简显示）
  static const defaultFree = WordDetailDisplayConfig(
    sections: [
      WordDetailSection.chineseMeaning,
      WordDetailSection.sentenceTranslation,
      WordDetailSection.definitions,
      WordDetailSection.examples,
      WordDetailSection.difficulty,
    ],
    showPronounceButtons: true,
  );

  /// 横屏精简配置
  static const landscapeCompact = WordDetailDisplayConfig(
    sections: [
      WordDetailSection.chineseMeaning,
      WordDetailSection.sentenceTranslation,
      WordDetailSection.definitions,
      WordDetailSection.examples,
      WordDetailSection.morphology,
      WordDetailSection.mnemonic,
    ],
    showPronounceButtons: true,
  );

  WordDetailDisplayConfig copyWith({
    List<WordDetailSection>? sections,
    bool? showPronounceButtons,
  }) {
    return WordDetailDisplayConfig(
      sections: sections ?? List.from(this.sections),
      showPronounceButtons: showPronounceButtons ?? this.showPronounceButtons,
    );
  }
}

/// 展示配置的 State
class DisplayConfigState {
  final WordDetailDisplayConfig config;

  const DisplayConfigState({required this.config});

  DisplayConfigState copyWith({WordDetailDisplayConfig? config}) {
    return DisplayConfigState(config: config ?? this.config);
  }
}

/// 展示配置 Notifier
class DisplayConfigNotifier extends StateNotifier<DisplayConfigState> {
  DisplayConfigNotifier({WordDetailDisplayConfig? initial})
      : super(DisplayConfigState(config: initial ?? WordDetailDisplayConfig.defaultPremium));

  /// 设置为付费版配置
  void setPremium() {
    state = state.copyWith(config: WordDetailDisplayConfig.defaultPremium);
  }

  /// 设置为免费版配置
  void setFree() {
    state = state.copyWith(config: WordDetailDisplayConfig.defaultFree);
  }

  /// 设置为横屏配置
  void setLandscape() {
    state = state.copyWith(config: WordDetailDisplayConfig.landscapeCompact);
  }

  /// 自定义配置
  void updateConfig(WordDetailDisplayConfig config) {
    state = state.copyWith(config: config);
  }

  /// 移动区块顺序
  void moveSection(int fromIndex, int toIndex) {
    final sections = List<WordDetailSection>.from(state.config.sections);
    if (fromIndex < 0 || toIndex < 0 || fromIndex >= sections.length || toIndex >= sections.length) return;
    final item = sections.removeAt(fromIndex);
    sections.insert(toIndex, item);
    state = state.copyWith(
      config: state.config.copyWith(sections: sections),
    );
  }

  /// 切换区块显隐
  void toggleSection(WordDetailSection section) {
    final sections = List<WordDetailSection>.from(state.config.sections);
    if (sections.contains(section)) {
      sections.remove(section);
    } else {
      sections.add(section);
    }
    state = state.copyWith(
      config: state.config.copyWith(sections: sections),
    );
  }

  /// 保存当前配置到数据库
  Future<void> persistConfig() async {
    await state.config.saveToSettings();
  }
}

/// 展示配置 Provider
final displayConfigProvider = StateNotifierProvider<DisplayConfigNotifier, DisplayConfigState>((ref) {
  return DisplayConfigNotifier(initial: WordDetailDisplayConfig.defaultPremium);
});
