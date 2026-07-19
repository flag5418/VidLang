import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
    // ✅ 正确：不覆盖方向方法，让 FlutterSceneDelegate 内部处理
    // FlutterSceneDelegate 已实现动态方向管理
    // 覆盖此方法会导致 Flutter 的 SystemChrome.setPreferredOrientations() 失效
}
