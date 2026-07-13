# 开发环境配置指南

> **版本**: v1.0.0
> **最后更新**: 2026-07-12
> **状态**: ✅ 已启用
> **适用平台**: macOS / Windows / Linux

---

## 📋 目录

1. [环境要求](#环境要求)
2. [快速开始](#快速开始)
3. [项目结构](#项目结构)
4. [依赖管理](#依赖管理)
5. [本地插件说明](#本地插件说明)
6. [开发工具配置](#开发工具配置)
7. [构建与运行](#构建与运行)
8. [调试技巧](#调试技巧)
9. [常见问题](#常见问题)

---

## 环境要求

### 必需软件

| 软件 | 版本要求 | 用途 | 安装方式 |
|------|----------|------|----------|
| Flutter SDK | ^3.13.0 | 核心框架 | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| Dart SDK | ^3.13.0 (随 Flutter) | 编程语言 | 随 Flutter 安装 |
| Xcode | 15+ | iOS 开发/构建 | Mac App Store |
| Android Studio | 2023.1+ | Android 开发 | [developer.android.com](https://developer.android.com/studio) |
| VS Code | 最新版 | 推荐编辑器 | [code.visualstudio.com](https://code.visualstudio.com/) |
| Git | 2.30+ | 版本控制 | `brew install git` 或 [git-scm.com](https://git-scm.com/) |

### 推荐工具

| 工具 | 用途 | 安装方式 |
|------|------|----------|
| CatPaw AI | AI 辅助开发（本项目使用） | IDE 插件 |
| Flutter DevTools | 性能调试 | `flutter pub global activate devtools` |
| Supabase CLI | 本地 Edge Functions 调试 | `npm install -g supabase` |
| CocoaPods | iOS 依赖管理 | `sudo gem install cocoapods` |

### 系统特定要求

#### macOS (推荐)

```bash
# 检查 Xcode 命令行工具
xcode-select --install

# 检查 CocoaPods
pod --version  # 需要 1.15+

# 检查 Homebrew（包管理器）
brew --version
```

#### Windows

```powershell
 # 确保 PowerShell 5.1+
 $PSVersionTable.PSVersion.Major

# 启用开发者模式
 Settings → Update & Security → For developers → Developer mode
```

#### Linux (Ubuntu 22.04+)

```bash
# 安装基础依赖
sudo apt update
sudo apt install -y curl git unzip xz-utils zip libglu1-mesa

# 安装 Chrome（用于 Flutter Web 测试）
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo dpkg -i google-chrome-stable_current_amd64.deb
```

---

## 快速开始

### 1. 克隆项目

```bash
git clone <repository-url>
cd vidlang
```

### 2. 安装 Flutter 依赖

```bash
# 获取依赖
flutter pub get

# 如果遇到问题，尝试清理后重新获取
flutter clean && flutter pub get
```

### 3. iOS 初始化（macOS only）

```bash
cd ios
pod install   # 安装 CocoaPods 依赖
cd ..
```

**注意**: 
- 项目使用了自定义插件（如 OmniPlayer），需要打开 `ios/Runner.xcworkspace` 而非 `.xcodeproj`
- 首次运行需要在真机或模拟器上信任开发者证书

### 4. Android 初始化

```bash
# 确保已接受 Android 许可证
flutter doctor --android-licenses

# 打开 Android Studio，等待 Gradle 同步完成
# 路径: android/
```

### 5. 运行应用

```bash
# 运行到连接的设备
flutter run

# 指定设备
flutter run -d <device-id>

# 运行到 iOS 模拟器
flutter run -d iPhone 15 Pro

# 运行到 Android 模拟器
flutter run -d Pixel 8 Pro
```

---

## 项目结构

### 目录概览

```
vidlang/
├── lib/                          # Dart 源代码
│   ├── main.dart                 # 应用入口
│   ├── models/                   # 数据模型
│   │   ├── base_entity.dart      # 实体基类
│   │   ├── video_info.dart       # 视频信息
│   │   ├── video_folder.dart     # 文件夹
│   │   ├── subtitles.dart        # 字幕
│   │   ├── user.dart             # 用户
│   │   └── ...
│   ├── services/                 # 服务层
│   │   ├── database_service.dart # 数据库服务
│   │   ├── auth_service.dart     # 认证服务
│   │   ├── ai_service.dart       # AI 服务
│   │   └── ...
│   ├── providers/                # Riverpod Providers
│   │   ├── file_provider.dart    # 文件状态
│   │   ├── player_engine_provider.dart  # 播放器状态
│   │   └── ...
│   ├── views/                    # 页面 UI
│   │   ├── home/                # 首页
│   │   ├── player/              # 播放器页
│   │   ├── files/               # 文件管理
│   │   ├── profile/             # 个人中心
│   │   └── ...
│   ├── widgets/                  # 公共组件
│   │   ├── common/              # 通用组件
│   │   └── ...                  # 业务组件
│   ├── theme/                   # 主题系统
│   │   ├── app_colors.dart
│   │   ├── app_typography.dart
│   │   ├── app_spacing.dart
│   │   ├── app_radius.dart
│   │   └── app_theme.dart
│   ├── utils/                   # 工具类
│   │   ├── adaptive.dart        # 屏幕适配
│   │   └── ...
│   └── constants/               # 常量定义
│
├── plugs/                       # 本地插件（未发布到 pub.dev）
│   ├── tdesign_flutter/         # TDesign UI 组件库
│   ├── omni_player/            # 视频播放器
│   ├── file_picker/            # 文件选择器
│   └── spm_mirrors/           # SPM 包镜像
│
├── assets/                      # 静态资源
│   ├── Logo/                    # 应用图标
│   ├── app/                     # 应用资源
│   ├── models/                  # ML 模型文件
│   └── video_plays/            # 视频相关资源
│
├── docs/                        # 项目文档
│   ├── DOCUMENTATION_INDEX.md   # 文档索引
│   └── developer/design/code-knowledge-base/  # 知识库
│
├── test/                        # 单元测试
├── integration_test/            # 集成测试
├── android/                     # Android 平台代码
├── ios/                         # iOS 平台代码
├── .supabase_cli/              # Supabase 配置
└── pubspec.yaml                 # 项目配置文件
```

### 关键文件说明

| 文件/目录 | 说明 | 重要程度 |
|-----------|------|----------|
| `lib/main.dart` | 应用入口、初始化流程 | ⭐⭐⭐ |
| `lib/services/auth_service.dart` | 认证核心逻辑 | ⭐⭐⭐ |
| `lib/services/ai_service.dart` | AI 服务统一入口 | ⭐⭐⭐ |
| `lib/providers/player_engine_provider.dart` | 播放器状态管理 | ⭐⭐⭐ |
| `lib/theme/app_theme.dart` | 主题配置 | ⭐⭐ |
| `plugs/omni_player/` | 播放器原生代码 | ⭐⭐ |
| `plugs/tdesign_flutter/` | TDesign 组件库源码 | ⭐⭐ |

---

## 依赖管理

### 核心依赖列表

```yaml
# pubspec.yaml 关键依赖

# === 状态管理 ===
flutter_riverpod: ^2.6.1          # 状态管理（必须）

# === UI 组件库 ===
tdesign_flutter:
  path: plugs/tdesign_flutter     # TDesign（唯一 UI 库）

# === 播放器 ===
omni_player:
  path: plugs/omni_player         # 视频/音频播放器（必须）

# === 后端服务 ===
supabase_flutter: ^2.8.4          # 认证/数据库/Edge Functions
flutter_secure_storage: ^9.2.4    # 安全存储（密码等）

# === 本地数据库 ===
sqflite: ^2.3.3                  # SQLite
synchronized: ^3.1.0             # 并发锁

# === 工具库 ===
uuid: ^4.4.0                     # UUID 生成
path_provider: ^2.1.3            # 文件路径
dio: ^5.7.0                      # HTTP 客户端
video_thumbnail: ^0.5.6          # 视频缩略图
flutter_screenutil: ^5.9.3       # 屏幕适配
lottie: ^2.7.0                   # 动画
crypto: ^3.0.6                   # 加密
```

### 本地插件（plugs/）

项目使用多个本地插件，这些插件**未发布到 pub.dev**，通过 `path:` 引用：

| 插件 | 路径 | 说明 |
|------|------|------|
| `tdesign_flutter` | `plugs/tdesign_flutter/` | TDesign Flutter UI 库（定制版） |
| `omni_player` | `plugs/omni_player/` | 原生播放器封装（iOS AVPlayer + Android ExoPlayer） |
| `file_picker` | `plugs/file_picker/` | 文件选择器（增强版） |

**重要**: 这些插件的修改会直接影响项目功能，请谨慎更新。

### 添加新依赖

```bash
# 1. 搜索依赖
flutter pub add <package_name>

# 2. 指定版本
flutter pub add <package_name>@^1.0.0

# 3. 开发依赖
flutter pub dev <package_name>

# 4. 手动编辑 pubspec.yaml 后执行
flutter pub get
```

### 移除依赖

```bash
flutter remove <package_name>
```

---

## 本地插件说明

### OmniPlayer 播放器

**路径**: `plugs/omni_player/`

**技术栈**:
- iOS: AVPlayer (AVFoundation)
- Android: ExoPlayer / MediaPlayer
- 通信: MethodChannel + EventChannel

**功能**:
- 视频播放/暂停/Seek
- 音频播放（后台继续）
- 缓存系统（首次流式，后续本地）
- 锁屏控制 + 通知栏控制
- Seek 同步优化

**修改注意事项**:
- 修改原生代码后需重新构建：`flutter clean && flutter run`
- iOS 需要在 Xcode 中打开 `Runner.xcworkspace`
- 测试时优先在真机上测试（模拟器的视频解码有限制）

### TDesign Flutter

**路径**: `plugs/tdesign_flutter/`

**定制内容**:
- 可能包含项目特定的样式调整
- 版本可能与官方 pub.dev 版本不同

**更新建议**:
- 定期同步官方仓库的新功能和 Bug 修复
- 修改前备份当前版本
- 测试所有使用 TDesign 的页面

---

## 开发工具配置

### VS Code 推荐扩展

| 扩展名 | 用途 | 必要性 |
|--------|------|--------|
| Dart & Flutter | 语言支持、调试 | ⭐⭐⭐ 必须 |
| CatPaw AI | AI 辅助编码 | ⭐⭐⭐ 推荐 |
| Flutter Widget Snippets | 快速生成 Widget 代码 | ⭐⭐ 推荐 |
| Error Lens | 内联错误提示 | ⭐⭐ 推荐 |
| GitLens | Git 增强 | ⭐ 可选 |
| Material Icon Theme | 图标预览 | ⭐ 可选 |

### VS Code 设置

```json
// .vscode/settings.json
{
  "dart.lineLength": 120,
  "dart.previewLsp": true,
  
  // 格式化
  "[dart]": {
    "editor.formatOnSave": true,
    "editor.rulers": [120],
    "editor.codeActionsOnSave": [
      "source.fixAll"
    ]
  },
  
  // 排除文件
  "files.exclude": {
    "**/.dart_tool": true,
    "**/.packages": true,
    "**/build": true,
    "**/.plugin_manager": true
  }
}
```

### Flutter 分析选项

```yaml
# analysis_options.yaml (位于项目根目录)
include: package:flutter_lints/flutter.yaml

analyzer:
  errors:
    missing_return: error
    dead_code: warning
    unused_import: warning
    
linter:
  rules:
    # 错误预防
    avoid_print: false           # 允许 debugPrint
    prefer_const_constructors: true
    prefer_final_locals: true
    
    # 代码风格
    always_declare_return_types: true
    avoid_empty_else: true
    prefer_single_quotes: true
    
    # 文档
    public_member_api_docs: false  # 不强制公共 API 文档
```

---

## 构建与运行

### 开发模式（Debug）

```bash
# 热重载开发
flutter run

# 仅运行（不附加调试器）
flutter run --release  # 注意：这是 Profile 模式
```

### Profile 模式（性能测试）

```bash
flutter run --profile

# 使用 DevTools 分析性能
# 1. 启动 DevTools
flutter pub global activate devtools
devtools

# 2. 在应用中启动性能分析
# 3. 在 DevTools 中查看结果
```

### Release 构建

```bash
# iOS (需要 Mac + Xcode)
flutter build ios --release
# 产物: ios/build/ios/Runner.app

# Android (APK)
flutter build apk --release
# 产物: build/app/outputs/flutter-apk/app-release.apk

# Android (App Bundle - 用于应用商店)
flutter build appbundle --release
# 产物: build/app/outputs/bundle/release/app-release.aab
```

### 代码签名

#### iOS

```bash
# 方式 1: Xcode 自动签名（开发阶段）
# 在 Xcode → Signing & Capabilities 中选择 Team

# 方式 2: 手动指定
flutter build ios --release \
  --obfuscate \
  --split-debug-info=build/debug-info/

# 上传符号表到 App Store Connect
# （用于崩溃日志解析）
```

#### Android

```bash
# 配置 keystore（首次）
keytool -genkey -v -keystore ~/key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias key

# 创建 key.properties（不要提交到 Git！）
# android/key.properties
storePassword=<password>
keyPassword=<password>
keyAlias=key
storeFile=<path-to-key.jks>

# 构建
flutter build appbundle --release
```

---

## 调试技巧

### 日志系统

项目使用 **VSCode Logger** 进行结构化日志：

```dart
import 'package:flutter_vscode_logger/flutter_vscode_logger.dart';

// 初始化（main.dart 中已完成）
VscodeLogger.instance.init(
  appName: 'VidLang',
  minLevel: LogLevel.debug,  // 开发环境输出 debug 及以上
);

// 使用示例
VscodeLogger.instance.info('用户登录成功');
VscodeLogger.instance.error('网络请求失败', error: e);
VscodeLogger.instance.debug('播放器状态变更: ${state.name}');
```

### 断点调试

1. 在 VS Code 中按 `F5` 启动调试
2. 在代码行号左侧点击设置断点
3. 在 Debug Console 中查看变量值
4. 使用调试工具栏控制执行流程

### DevTools 调试

```bash
# 启动 DevTools
devtools

# 主要功能：
# - Inspector: 查看 Widget 树和属性
# - Performance: 性能分析（帧率、渲染时间）
# - Memory: 内存泄漏检测
# - Network: 网络请求监控
# - Logging: 结构化日志查看
```

### 常用调试命令

```bash
# 查看设备信息
flutter devices

# 清理构建缓存
flutter clean

# 检查依赖冲突
flutter pub deps

# 运行单元测试
flutter test

# 运行特定测试文件
flutter test test/database_service_test.dart

# 代码覆盖率
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

### Supabase 本地开发

```bash
# 1. 登录 Supabase
supabase login

# 2. 启动本地服务
supabase start

# 3. 运行 Edge Functions（带热重载）
supabase functions serve --env ./env --no-verify-jwt

# 4. 查看日志
supabase functions logs ai-proxy --follow

# 5. 停止服务
supabase stop
```

---

## 常见问题

### Q1: `flutter pub get` 失败？

**原因**: 网络问题或依赖版本冲突。

**解决方案**:
```bash
# 使用国内镜像
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

# 重试
flutter pub get

# 如果仍失败，清理后重试
flutter clean && flutter pub get
```

### Q2: iOS 构建失败 "Module 'xxx' not found"？

**原因**: CocoaPods 依赖未正确安装。

**解决方案**:
```bash
cd ios
rm -rf Pods Podfile.lock
pod install --repo-update
cd ..
flutter clean && flutter pub get
```

### Q3: Android 构建失败 "Gradle build failed"？

**原因**: Gradle 版本不兼容或依赖下载失败。

**解决方案**:
```bash
# 清理 Android 缓存
cd android
./gradlew clean
cd ..

# 检查 Gradle 版本
cat android/gradle/wrapper/gradle-wrapper.properties

# 手动下载依赖（如果网络慢）
cd android
./gradlew assembleDebug --stacktrace
```

### Q4: 运行时崩溃 "MissingPluginException"？

**原因**: 原生插件未正确注册。

**解决方案**:
```bash
# iOS: 检查 Podfile 是否包含所有插件
cat ios/Podfile

# Android: 检查 MainActivity.kt 或 MainActivity.java
# 确保有 PluginRegistrant.registerWith()
flutter clean && flutter run
```

### Q5: 如何切换 Supabase 环境？

**方案**: 使用不同的配置文件。

```dart
// lib/services/app_keys_service.dart
class AppKeysService {
  static String get supabaseUrl {
    // 开发环境
    if (kDebugMode) {
      return const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'https://dev-project.supabase.co',
      );
    }
    // 生产环境
    return const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://prod-project.supabase.co',
    );
  }
}

# 通过环境变量切换
SUPABASE_URL=https://dev-xxx.supabase.co SUPABASE_ANON_KEY=xxx flutter run
```

---

## 📚 相关文档

- [Flutter 官方文档](https://docs.flutter.dev/)
- [Dart 官方文档](https://dart.dev/guides)
- [Riverpod 文档](https://riverpod.dev/)
- [Supabase Flutter 入门](https://supabase.com/docs/guides/getting-started/quickstarts/flutter)
- [TDesign Flutter](./tdesign-components.md)
- [项目全局规则](../../PROJECT_RULES.md)

---

## 🔄 版本历史

| 版本 | 日期 | 变更内容 | 作者 |
|------|------|----------|------|
| v1.0.0 | 2026-07-12 | 初版建立 | AI Assistant |

---

## ✅ 新成员入职检查清单

### 环境准备
- [ ] Flutter SDK 已安装且版本 ≥ 3.13.0
- [ ] Xcode / Android Studio 已安装并配置
- [ ] VS Code 已安装并配置 Dart/Flutter 扩展
- [ ] Git 已配置用户名和邮箱
- [ ] 项目已克隆并可运行

### 代码理解
- [ ] 阅读 `项目全局规则.md`
- [ ] 阅读 `docs/DOCUMENTATION_INDEX.md`
- [ ] 运行应用并熟悉主要页面
- [ ] 理解 Models → Services → Providers → Views 架构

### 开发配置
- [ ] VS Code settings.json 已配置
- [ ] analysis_options.yaml 已生效
- [ ] 代码格式化工具已启用（保存时自动格式化）
- [ ] Git Hook 已配置（可选：pre-commit 检查）

### 权限申请
- [ ] Supabase 访问权限（如需云端功能）
- [ ] 测试设备已添加（iOS TestFlight / Google Play 内测）
