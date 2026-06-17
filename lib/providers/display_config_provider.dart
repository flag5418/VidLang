import 'package:flutter_riverpod/flutter_riverpod.dart';

/// WordDetailPanel 中各内容区块的枚举
enum WordDetailSection {
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
      case WordDetailSection.sentenceTranslation: return '语境释义';
      case WordDetailSection.definitions:          return '词典释义';
      case WordDetailSection.englishMeaning:       return '英文解释';
      case WordDetailSection.partOfSpeech:         return '词性';
      case WordDetailSection.examples:             return '例句';
      case WordDetailSection.difficulty:           return '单词难度';
      case WordDetailSection.morphology:           return '词形变化';
      case WordDetailSection.mnemonic:             return '记忆技巧';
    }
  }
}

/// 弹窗展示配置
///
/// 控制 WordDetailPanel 中内容区块的显示/隐藏和排列顺序。
/// 支持通过 SharedPreferences 持久化用户自定义配置。
class WordDetailDisplayConfig {
  /// 区块列表（按显示顺序排列）
  final List<WordDetailSection> sections;

  /// 是否显示发音按钮
  final bool showPronounceButtons;

  const WordDetailDisplayConfig({
    required this.sections,
    this.showPronounceButtons = true,
  });

  /// 付费用户默认配置（全量显示）
  static const defaultPremium = WordDetailDisplayConfig(
    sections: [
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

/// 展示配置 Notifier — 预留持久化入口
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

  // TODO: 后续实现 SharedPreferences 持久化读取/保存
}

/// 展示配置 Provider
final displayConfigProvider = StateNotifierProvider<DisplayConfigNotifier, DisplayConfigState>((ref) {
  // 默认使用付费版配置；后续可根据订阅状态动态切换
  return DisplayConfigNotifier(initial: WordDetailDisplayConfig.defaultPremium);
});
