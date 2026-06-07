import 'package:vidlang/models/user.dart';

class AppConfig {
  static const String supabaseUrl = 'https://tqehcadjuwodbmgmxzmf.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_aKICDtmL2aisDtOpNh88jQ_IZ3m_fuB';
  static User? currentUser;

  // ==================== 声通语音评测配置 ====================
  /// 声通评测 appKey（晚些时候设置实际值）
  static const String shengtongAppKey = '';

  /// 声通评测 secretKey（晚些时候设置实际值）
  static const String shengtongSecretKey = '';

  /// 声通 WebSocket 地址（ws 协议）
  static const String shengtongWsUrl = 'ws://api.stkouyu.com:8080';

  /// 声通 WebSocket 地址（wss 协议）
  static const String shengtongWssUrl = 'wss://api.stkouyu.com:8443';

  /// 是否使用 SSL 连接声通
  static const bool shengtongUseSSL = false;

  // ==================== 阿里云 DashScope 通用配置 ====================
  /// DashScope API Key（千问 LLM + TTS 共用）
  static const String aliDashScopeApiKey = 'sk-185f8cb02c1d4bc2b7afc586e049fc5a';

  // ==================== 千问 LLM 配置 ====================
  /// 千问 API 地址（OpenAI 兼容模式）
  static const String qwenBaseUrl = 'https://dashscope.aliyuncs.com/compatible-mode/v1';

  /// 千问 LLM 默认模型
  static const String qwenModel = 'qwen-plus';

  // ==================== 阿里云 TTS 配置 ====================

  /// 阿里云 TTS API 地址
  static const String aliTtsBaseUrl = 'https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation';

  /// 阿里云 TTS 默认模型
  static const String aliTtsModel = 'qwen-tts-vc-custom-voice-20260302151023899-2d6b';

  /// 阿里云 TTS 备用模型列表（循环切换）
  static const List<String> aliTtsModelList = [
    'qwen-tts-vc-custom-voice-20260302151023899-2d6b',
    'qwen-tts-vc-custom-voice-20260302153008560-8ae1',
    'qwen-tts-vc-custom-voice-20260302153319489-b008',
  ];

  /// 默认音色
  static const String aliTtsDefaultVoice = 'Aiden';

  /// TTS 采样率
  static const int aliTtsSampleRate = 24000;
}
