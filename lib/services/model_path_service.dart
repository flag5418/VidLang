import 'package:flutter/foundation.dart';

/// 统一模型路径管理服务
/// 
/// 现在使用 iOS 系统翻译（MLTranslation，需 iOS 17.4+）
/// 不再需要本地 MarianMT 模型
class ModelPathService {
  ModelPathService._();

  /// 检查模型是否完整
  /// 
  /// 现在使用 iOS 系统翻译，始终返回 true
  static Future<bool> get isMarianmtModelComplete async {
    debugPrint('ModelPathService: 使用 iOS 系统翻译，模型检查跳过');
    return true;
  }
}
