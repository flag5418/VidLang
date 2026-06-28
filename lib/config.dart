import 'package:vidlang/models/user.dart';

class AppConfig {
  static const String supabaseUrl = 'https://tqehcadjuwodbmgmxzmf.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_aKICDtmL2aisDtOpNh88jQ_IZ3m_fuB';
  static User? currentUser;

  // ==================== 声通语音评测配置 ====================
  static const String shengtongAppKey = '17618890190005e3';

  static const String shengtongSecretKey = '5d0b32c950794688f6caf0c797980cde';

  static const String shengtongUid = 'uid';

  /// 声通 WebSocket 地址（ws 协议）
  static const String shengtongWsUrl = 'ws://api.stkouyu.com:8080';

  /// 声通 WebSocket 地址（wss 协议）
  static const String shengtongWssUrl = 'wss://api.stkouyu.com:8443';

  /// 是否使用 SSL 连接声通
  static const bool shengtongUseSSL = false;
}
