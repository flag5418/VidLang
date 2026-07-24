# 构建环境问题排查知识库

> **版本**: V2.0 | **日期**: 2026-07-24
> **触发关键词**: 编译失败, build failed, sqlite3, dylib, 下载超时, SocketException, github.com, CocoaPods, pod install, Gradle, gradle distribution, hooks_runner, pods-cache, flutter clean, 更换设备, 环境搭建
> **V2.0 变更**: 新增 Android Gradle 发行版缓存、统一恢复脚本、pods-cache 完整目录结构、网络依赖分析表

---

## 一、问题总览

VidLang 项目在 iOS / Android 构建时，可能遇到以下几类环境问题：

| 编号 | 问题 | 平台 | 严重度 | 触发场景 | 是否已缓存 |
|------|------|------|--------|----------|-----------|
| B01 | sqlite3 预编译 dylib 下载超时 | iOS | 🔴 阻断 | flutter clean 后首次构建 | ✅ pods-cache/sqlite3/ |
| B02 | CocoaPods 依赖安装失败 | iOS | 🟡 中 | Pods 目录损坏 / 网络问题 | ❌ (CDN 通常可用) |
| B03 | IPHONEOS_DEPLOYMENT_TARGET 警告 | iOS | 🟡 警告 | 插件最低版本过低 | N/A |
| B04 | Swift Package Manager 不支持警告 | iOS | 🟡 警告 | 插件未适配 SPM | N/A |
| B05 | Gradle 发行版下载慢/失败 | Android | 🔴 阻断 | 首次构建 / 更换设备 | ✅ pods-cache/gradle/ |
| B06 | Gradle Maven 依赖下载失败 | Android | 🟡 中 | 网络问题 / 仓库不可达 | ❌ (阿里云镜像已配) |
| B07 | Android SDK License 未接受 | Android | 🔴 阻断 | 首次安装 SDK | N/A |
| B08 | MissingPluginException | 双端 | 🔴 运行时 | 插件未正确注册 | N/A |

---

## 二、B01: sqlite3 预编译 dylib 下载超时（核心问题）

### 2.1 问题现象

```
By default, this package downloads a pre-compiled SQLite library.
This failed (attepted to download https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-3.5.0/libsqlite3.arm64.ios.dylib).
Original cause: SocketException: Operation timed out (OS Error: Operation timed out, errno = 60), address = github.com
```

### 2.2 根因分析

```
依赖链路:
  sqflite (2.4.3)
    └── sqflite_common_ffi (2.4.2) [dev_dependency]
          └── sqlite3 (3.5.0) [Dart 原生包]
                └── hook/build.dart [构建钩子]
                      └── 从 GitHub Releases 下载预编译 dylib
```

**关键机制**：

1. `sqlite3` 包使用 **Dart Hooks** 机制（`hook/build.dart`），在构建时从 GitHub 下载预编译的二进制库
2. 下载 URL 格式: `https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-{version}/{filename}`
3. 下载的文件存放在 `.dart_tool/hooks_runner/shared/sqlite3/build/download-{hash前8位}/libsqlite3.dylib`
4. 构建时会校验 SHA256 哈希值，必须与 `asset_hashes.dart` 中记录的完全匹配
5. **`flutter clean` 会删除 `.dart_tool/`，导致缓存丢失，下次构建需要重新下载**

### 2.3 解决方案：pods-cache 本地缓存

项目在 `pods-cache/sqlite3/` 目录维护了预编译 dylib 的本地副本（已在 `.gitignore` 中排除）。

**文件清单（sqlite3 3.5.0）**：

| 文件 | 用途 | SHA256 |
|------|------|--------|
| `libsqlite3.arm64.ios.dylib` | iOS 真机 (arm64) | `14ddadc35d7e92e58e219a34dc4a9b66fd5b195c9e144dcfed06978a65dfaba9` |
| `libsqlite3.arm64.ios_sim.dylib` | iOS 模拟器 (arm64) | `1ef1f54d5524f6c99ff74ae1244fb3d815f7a40c7c1cf7615a6321ba752fa8ff` |

**hooks_runner 缓存目录映射**：

| 目标平台 | 缓存目录 | 源文件 |
|----------|----------|--------|
| iOS 真机 | `.dart_tool/hooks_runner/shared/sqlite3/build/download-14ddadc3/libsqlite3.dylib` | `pods-cache/sqlite3/libsqlite3.arm64.ios.dylib` |
| iOS 模拟器 | `.dart_tool/hooks_runner/shared/sqlite3/build/download-1ef1f54d/libsqlite3.dylib` | `pods-cache/sqlite3/libsqlite3.arm64.ios_sim.dylib` |

### 2.4 恢复操作

#### 方式一：使用恢复脚本（推荐）

```bash
# 在项目根目录执行
./scripts/restore_sqlite3_cache.sh
```

脚本会自动：
1. 检查 `pods-cache/sqlite3/` 中的源文件
2. 创建对应的 `download-{hash前8位}/` 目录
3. 复制 dylib 文件并验证 SHA256 哈希

#### 方式二：手动复制

```bash
# iOS 真机
mkdir -p .dart_tool/hooks_runner/shared/sqlite3/build/download-14ddadc3/
cp pods-cache/sqlite3/libsqlite3.arm64.ios.dylib \
   .dart_tool/hooks_runner/shared/sqlite3/build/download-14ddadc3/libsqlite3.dylib

# iOS 模拟器
mkdir -p .dart_tool/hooks_runner/shared/sqlite3/build/download-1ef1f54d/
cp pods-cache/sqlite3/libsqlite3.arm64.ios_sim.dylib \
   .dart_tool/hooks_runner/shared/sqlite3/build/download-1ef1f54d/libsqlite3.dylib
```

#### 方式三：从 GitHub 重新下载（需要网络）

```bash
# 直连 GitHub（可能超时）
curl -L -o pods-cache/sqlite3/libsqlite3.arm64.ios.dylib \
  "https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-3.5.0/libsqlite3.arm64.ios.dylib"

# 通过 GitHub 代理（推荐国内使用）
curl -L -o pods-cache/sqlite3/libsqlite3.arm64.ios.dylib \
  "https://ghproxy.net/https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-3.5.0/libsqlite3.arm64.ios.dylib"
```

### 2.5 sqlite3 版本升级时的操作

当 `sqflite_common_ffi` 或 `sqlite3` 包版本升级时：

1. **查找新版本的哈希值**：
   ```bash
   # 查看 asset_hashes.dart 中的哈希
   cat ~/.pub-cache/hosted/pub.flutter-io.cn/sqlite3-{新版本}/lib/src/hook/asset_hashes.dart
   ```

2. **下载新版本的 dylib**：
   ```bash
   # 替换 {新版本} 和对应文件名
   curl -L -o pods-cache/sqlite3/libsqlite3.arm64.ios.dylib \
     "https://ghproxy.net/https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-{新版本}/libsqlite3.arm64.ios.dylib"

   curl -L -o pods-cache/sqlite3/libsqlite3.arm64.ios_sim.dylib \
     "https://ghproxy.net/https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-{新版本}/libsqlite3.arm64.ios_sim.dylib"
   ```

3. **验证哈希**：
   ```bash
   shasum -a 256 pods-cache/sqlite3/*
   ```

4. **更新 `scripts/restore_sqlite3_cache.sh` 中的哈希映射**：
   - 修改 `FILE_HASH_MAP` 中的 hash 前缀（SHA256 前 8 位）

5. **更新本文档的文件清单表格**

### 2.6 诊断命令

```bash
# 检查 pods-cache 文件是否存在且哈希正确
shasum -a 256 pods-cache/sqlite3/*

# 检查 hooks_runner 缓存是否存在
ls -la .dart_tool/hooks_runner/shared/sqlite3/build/

# 查看当前 sqlite3 包版本
grep sqlite3 .dart_tool/package_config.json | grep -o '"version":"[^"]*"'

# 查看 sqlite3 依赖来源
flutter pub deps 2>/dev/null | grep sqlite3
```

---

## 三、B02: CocoaPods 依赖安装失败

### 3.1 问题现象

```
Error: CocoaPods not installed or not in PATH
# 或
[!] Unable to find a specification for `xxx`
# 或
Module 'xxx' not found
```

### 3.2 解决方案

```bash
# 完整重置 CocoaPods
cd ios
rm -rf Pods Podfile.lock
pod install --repo-update
cd ..

# 如果仍然失败，清理 Flutter 缓存后重试
flutter clean && flutter pub get
cd ios && pod install --repo-update && cd ..
```

### 3.3 网络问题导致 pod install 超时

```bash
# 使用国内镜像源（在 Podfile 顶部替换 source）
# source 'https://cdn.cocoapods.org/'  ← 替换为:
# source 'https://mirrors.tuna.tsinghua.edu.cn/git/CocoaPods/Specs.git'

# 或者手动清除 CDN 缓存
pod repo remove trunk
pod repo add trunk https://mirrors.tuna.tsinghua.edu.cn/git/CocoaPods/Specs.git
```

---

## 四、B03: IPHONEOS_DEPLOYMENT_TARGET 警告

### 4.1 问题现象

```
warning: The iOS deployment target 'IPHONEOS_DEPLOYMENT_TARGET' is set to 9.0,
but the range of supported deployment target versions is 12.0 to 26.1.99.
```

### 4.2 原因

某些插件的 Podspec 中设置的最低部署版本过低（如 9.0），而当前 Xcode 要求最低 12.0。

### 4.3 解决方案

在 `ios/Podfile` 中添加全局最低版本覆盖：

```ruby
# 在 Podfile 的 target 块内添加
platform :ios, '13.0'

# 在 post_install 钩子中强制覆盖所有 Pod 的部署目标
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
    end
  end
end
```

> **注意**: 项目 iOS 最低部署版本为 13.0，参见 `architecture/overview-V1.1.md`。

---

## 五、B04: Swift Package Manager 不支持警告

### 5.1 问题现象

```
The following plugins do not support Swift Package Manager for ios:
  - flutter_tts
  - flutter_secure_storage
  - flutter_pcm_player
This will become an error in a future version of Flutter.
```

### 5.2 说明

这是 Flutter 的渐进式迁移提示。当前项目使用的插件（flutter_tts、flutter_secure_storage、flutter_pcm_player）尚未适配 Swift Package Manager。

### 5.3 应对策略

- **当前**: 忽略此警告，不影响构建
- **未来**: 当 Flutter 将此变为 error 时，需要：
  1. 等待插件作者适配 SPM
  2. 或 fork 插件自行添加 SPM 支持
  3. 或寻找替代插件

---

## 六、B05: Gradle 发行版下载慢/失败

### 6.1 问题现象

```
Downloading https://services.gradle.org/distributions/gradle-9.1.0-all.zip
# 长时间无响应或超时
```

### 6.2 根因分析

Android 构建需要 Gradle 发行版（~217MB），首次构建或更换设备时从 `services.gradle.org` 下载，国内网络可能很慢。

Gradle wrapper 的工作机制：
```
android/gradle/wrapper/gradle-wrapper.properties
  → distributionUrl=https://services.gradle.org/distributions/gradle-9.1.0-all.zip
  → Gradle 计算URL哈希 → ~/.gradle/wrapper/dists/gradle-9.1.0-all/{hash}/
  → 检查 zip 是否存在 → 不存在则下载 → 解压
```

### 6.3 解决方案：pods-cache 本地缓存

项目在 `pods-cache/gradle/` 目录维护了 Gradle 发行版 zip 的本地副本。

```bash
# 使用统一恢复脚本
./scripts/restore_build_cache.sh --android

# 或手动复制
# 找到哈希目录（从 gradle-wrapper.properties 的 URL 计算）
GRADLE_HASH_DIR=$(ls -d ~/.gradle/wrapper/dists/gradle-9.1.0-all/*/ 2>/dev/null | head -1)
cp pods-cache/gradle/gradle-9.1.0-all.zip "${GRADLE_HASH_DIR}"
```
### 6.4 Gradle 版本升级时的操作

当 `android/gradle/wrapper/gradle-wrapper.properties` 中的 `distributionUrl` 变更时：

1. **下载新版本**:
   ```bash
   # 从 distributionUrl 获取下载地址
   grep distributionUrl android/gradle/wrapper/gradle-wrapper.properties
   # 下载到 pods-cache
   curl -L -o pods-cache/gradle/gradle-{新版本}-all.zip "{新URL}"
   ```

2. **删除旧版本缓存**:
   ```bash
   rm pods-cache/gradle/gradle-{旧版本}-all.zip
   ```

3. **执行恢复脚本**

---

## 六B、B06: Gradle Maven 依赖下载失败

### 6B.1 问题现象

```
Could not resolve all files for configuration ':classpath'.
> Could not download xxx.jar
> Could not GET 'https://xxx'
```

### 6B.2 解决方案

#### 方式一：确认阿里云镜像已配置

项目已在 `android/settings.gradle.kts` 中配置阿里云镜像：

```kotlin
// android/settings.gradle.kts
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://maven.aliyun.com/repository/jcenter") }
        google()
        mavenCentral()
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
        maven { url = uri("https://storage.flutter-io.cn/download.flutter.io") }
    }
}
```

> Maven 依赖通过阿里云镜像下载，通常不需要额外缓存。仅在网络完全不可用时才会出问题。

#### 方式二：清理 Gradle 缓存

```bash
cd android
./gradlew clean
cd ..

# 如果仍然失败，清除 Gradle 模块缓存（不影响发行版）
rm -rf ~/.gradle/caches/modules-2/

# 重新同步
flutter clean && flutter pub get
cd android && ./gradlew assembleDebug --stacktrace && cd ..
```

---

## 七、B07: Android SDK License 未接受

### 7.1 问题现象

```
FAILURE: Build failed with an exception.
* What went wrong:
You have not accepted the license agreements of the following SDK components
```

### 7.2 解决方案

```bash
# 接受所有 SDK 许可证
flutter doctor --android-licenses

# 或者手动
yes | sdkmanager --licenses
```

---

## 八、B08: MissingPluginException

### 8.1 问题现象

```
MissingPluginException(No implementation found for method xxx on channel xxx)
```

### 8.2 原因

插件代码已添加到 `pubspec.yaml`，但原生侧未正确注册。

### 8.3 解决方案

```bash
# 完整重置构建
flutter clean
flutter pub get

# iOS
cd ios && rm -rf Pods Podfile.lock && pod install --repo-update && cd ..

# Android
cd android && ./gradlew clean && cd ..

# 重新运行
flutter run
```

---

## 九、flutter clean 后的标准恢复流程

当执行 `flutter clean` 或手动删除 `.dart_tool/` 后，按以下顺序恢复：

```bash
#!/bin/bash
# flutter clean 后的标准恢复流程

# 1. 恢复 Flutter 依赖
flutter pub get

# 2. 恢复所有构建缓存（iOS sqlite3 + Android Gradle）
./scripts/restore_build_cache.sh

# 3. 恢复 iOS CocoaPods
cd ios && pod install --repo-update && cd ..

# 4. 验证
flutter doctor
flutter devices

# 5. 运行
flutter run -d <device-id>
```

### 9.1 更换设备时的完整环境搭建流程

```bash
#!/bin/bash
# 新设备环境搭建流程（假设 Flutter SDK / Xcode / Android Studio 已安装）

# 0. 确认环境
flutter doctor

# 1. 获取项目代码
git clone <repository-url> cd vidlang

# 2. 恢复 Flutter 依赖
flutter pub get

# 3. 恢复构建缓存（需要 pods-cache 目录，从旧设备复制或网盘下载）
./scripts/restore_build_cache.sh

# 4. iOS: 安装 CocoaPods 依赖
cd ios && pod install --repo-update && cd ..

# 5. Android: 接受 SDK 许可证（首次）
flutter doctor --android-licenses

# 6. 验证并运行
flutter doctor
flutter run -d <device-id>
```

> **重要**: `pods-cache/` 目录不在 Git 中（.gitignore 排除）。更换设备时需从旧设备复制或从网盘下载。

---

## 十、pods-cache 目录说明

### 10.1 目录结构

```
pods-cache/                    # 本地缓存（.gitignore 排除，不提交到 Git）
├── sqlite3/                   # iOS: sqlite3 预编译 dylib（来自 GitHub Releases）
│   ├── libsqlite3.arm64.ios.dylib       # iOS 真机 arm64（~1.6MB）
│   └── libsqlite3.arm64.ios_sim.dylib   # iOS 模拟器 arm64（~1.7MB）
└── gradle/                    # Android: Gradle 发行版 zip（来自 services.gradle.org）
    └── gradle-9.1.0-all.zip             # Gradle 9.1.0 完整发行版（~217MB）
```

### 10.2 网络依赖分析表

| 依赖项 | 平台 | 下载来源 | 大小 | 网络风险 | 是否缓存 | 缓存位置 |
|--------|------|---------|------|---------|---------|----------|
| sqlite3 dylibs | iOS | GitHub Releases | ~3.2MB | 🔴 高（超时） | ✅ 是 | `pods-cache/sqlite3/` |
| Gradle 发行版 | Android | services.gradle.org | ~217MB | 🟡 中（慢） | ✅ 是 | `pods-cache/gradle/` |
| CocoaPods 依赖 | iOS | CDN (cocoapods.org) | ~180MB | 🟢 低 | ❌ 否 | CDN 通常可用，`pod install` 自动处理 |
| Maven 依赖 (JAR/AAR) | Android | 阿里云镜像 | 分散 | 🟢 低 | ❌ 否 | 镜像已配，Gradle 自动处理 |
| Flutter SDK | 系统 | flutter.dev | ~1.5GB | N/A | ❌ 否 | 属于系统安装 |
| Android SDK | 系统 | developer.android.com | ~3GB | N/A | ❌ 否 | 属于系统安装 |

### 10.3 为什么需要 pods-cache

| 场景 | 不使用 pods-cache | 使用 pods-cache |
|------|------------------|----------------|
| `flutter clean` 后首次构建 | 从 GitHub 下载（可能超时） | 从本地复制（秒级完成） |
| 网络不稳定时构建 | 构建失败 | 正常构建 |
| 更换设备搭建环境 | 依赖网络质量，可能反复失败 | 复制 pods-cache + 一条命令恢复 |
| 新成员入职 | 依赖网络质量 | 从共享网盘下载 pods-cache 即可 |

### 10.4 缓存与运行时目录的关系

```
pods-cache/                              ← 持久化备份（手动维护，.gitignore排除）
├── sqlite3/
│   ├── libsqlite3.arm64.ios.dylib         原始文件名
│   └── libsqlite3.arm64.ios_sim.dylib
└── gradle/
    └── gradle-9.1.0-all.zip

.dart_tool/hooks_runner/shared/sqlite3/build/  ← iOS 运行时缓存（flutter clean 删除）
  ├── download-14ddadc3/                        以 SHA256 前8位命名
  │   └── libsqlite3.dylib                       统一文件名
  └── download-1ef1f54d/
      └── libsqlite3.dylib

~/.gradle/wrapper/dists/gradle-9.1.0-all/  ← Android 运行时缓存（全局，不随项目删除）
  └── {hash}/                                   URL哈希目录
      ├── gradle-9.1.0-all.zip                   发行版 zip
      └── gradle-9.1.0/                          解压后的目录
```

- `pods-cache/` 是**手动维护的备份**，类似于携带的“离线安装包”
- `.dart_tool/hooks_runner/` 是 **Hooks 机制自动管理的缓存**，`flutter clean` 会删除它
- `~/.gradle/` 是 **Gradle 全局缓存**，不随项目删除，但更换设备时不存在
- 恢复脚本的作用就是从 `pods-cache/` 复制到对应的运行时缓存位置

### 10.5 验证测试检查清单

- [ ] 验证 `pods-cache/sqlite3/` 中的文件哈希是否与 `asset_hashes.dart` 一致
- [ ] 验证 `pods-cache/gradle/` 中的 zip 版本与 `gradle-wrapper.properties` 一致
- [ ] 验证 `restore_build_cache.sh` 能正确恢复 iOS 和 Android 缓存
- [ ] 验证 `flutter clean` + 脚本恢复后，`flutter build ios --debug` 能成功
- [ ] 验证 `flutter clean` + 脚本恢复后，`flutter build apk --debug` 能成功
- [ ] 验证 iOS 真机和模拟器两种构建场景均能通过

---

## 十一、关键文件索引

| 文件 | 路径 | 说明 |
|------|------|------|
| **恢复脚本** | `scripts/restore_build_cache.sh` | **统一缓存恢复脚本（iOS + Android）** |
| **本地缓存** | `pods-cache/` | 所有缓存文件的持久化备份 |
| sqlite3 构建钩子 | `~/.pub-cache/hosted/pub.flutter-io.cn/sqlite3-3.5.0/hook/build.dart` | Hooks 构建逻辑入口 |
| sqlite3 资源哈希 | `~/.pub-cache/hosted/pub.flutter-io.cn/sqlite3-3.5.0/lib/src/hook/asset_hashes.dart` | 所有预编译库的 SHA256 |
| sqlite3 下载逻辑 | `~/.pub-cache/hosted/pub.flutter-io.cn/sqlite3-3.5.0/lib/src/hook/compile/description.dart` | 下载与缓存逻辑 |
| Gradle wrapper 配置 | `android/gradle/wrapper/gradle-wrapper.properties` | Gradle 版本和下载 URL |
| Android 仓库镜像 | `android/settings.gradle.kts` | 阿里云 Maven 镜像配置 |
| iOS 运行时缓存 | `.dart_tool/hooks_runner/shared/sqlite3/build/` | Hooks 自动管理的缓存 |
| Android 运行时缓存 | `~/.gradle/wrapper/dists/` | Gradle 全局缓存 |
| Hooks user_defines | `pubspec.yaml` → `hooks.user_defines` | 可配置 sqlite3 的下载源 |

---

## 十二、可选方案：通过 pubspec.yaml 配置 sqlite3 源

sqlite3 包支持通过 `pubspec.yaml` 的 `hooks.user_defines` 字段配置二进制来源：

```yaml
# pubspec.yaml（项目根目录）
hooks:
  user_defines:
    sqlite3:
      # 可选值: sqlite3 (默认), sqlite3mc, sqlcipher, system, process, executable, source
      source: sqlite3

      # 自定义下载 URL 模式（可使用代理）
      # url_pattern: "https://ghproxy.net/https://github.com/simolus3/sqlite3.dart/releases/download/$RELEASE_TAG/$FILENAME"

      # 使用系统库（不推荐，功能可能不全）
      # source: system
      # name: sqlite3
```

> **注意**: 此配置在 Flutter 3.13+ 的 hooks_runner 中支持。修改后需执行 `flutter clean && flutter pub get`。

---

## 十三、Git 提交规范

涉及构建环境修复的提交信息格式：

```
fix(global): 修复 sqlite3 dylib 下载超时问题
docs: 更新构建环境排查知识库至 V2.0（新增 Android 缓存）
chore(scripts): 添加统一构建缓存恢复脚本
```

---

## 十四、恢复脚本使用说明

### 14.1 命令参数

```bash
# 恢复全部缓存（iOS + Android）
./scripts/restore_build_cache.sh

# 仅恢复 iOS 缓存
./scripts/restore_build_cache.sh --ios

# 仅恢复 Android 缓存
./scripts/restore_build_cache.sh --android

# 仅检查缓存状态（不执行恢复）
./scripts/restore_build_cache.sh --check
```

### 14.2 输出示例

```
========================================
  VidLang 构建缓存恢复工具
========================================
  项目路径: /path/to/vidlang
  缓存路径: /path/to/vidlang/pods-cache

[STEP] 恢复 iOS: sqlite3 预编译 dylib
[INFO] 恢复成功: libsqlite3.arm64.ios.dylib → download-14ddadc3/
[INFO] 恢复成功: libsqlite3.arm64.ios_sim.dylib → download-1ef1f54d/
[INFO] iOS sqlite3: 2 个文件已恢复, 0 个文件已存在

[STEP] 恢复 Android: Gradle 发行版
[INFO] 恢复成功: gradle-9.1.0-all.zip → ~/.gradle/wrapper/dists/...

========================================
[STEP] 恢复完成
========================================

后续步骤:
  1. flutter pub get
  2. cd ios && pod install --repo-update && cd ..  (iOS CocoaPods)
  3. cd android && ./gradlew --version && cd ..    (Android Gradle)
  4. flutter run -d <device-id>
```

---

**文档结束**
