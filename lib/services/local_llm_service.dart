import 'package:flutter/foundation.dart';

/// 本地 LLM 推理服务
///
/// 注意：由于 iOS SPM 网络限制，暂未集成 LLM 推理包。
/// 所有 LLM 功能（翻译、释义、测验、对话）回退到云端 API。
/// 未来可接入支持纯 CocoaPods 的 LLM 包后启用。
class LocalLlmService {
  static LocalLlmService? _instance;
  static LocalLlmService get instance => _instance ??= LocalLlmService._();
  LocalLlmService._();

  bool get isInitialized => false;
  bool get isLoading => false;
  bool get isAvailable => false;

  Future<void> initialize() async {
    debugPrint('本地 LLM 未集成，功能回退到云端 API');
  }
}
