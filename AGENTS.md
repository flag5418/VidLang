# AGENTS.md - VidLang 项目 AI 协作规范

> **版本**: V1.0 | **日期**: 2026-07-12
> **优先级**: AI 自动加载，每次会话必须遵守

---

## 一、项目概述

**VidLang** - Flutter 语言学习应用，三引擎架构（视频+文章+歌曲），本地 SQLite + Supabase 云服务。

**核心功能**：字幕查词、跟读评分、测试、单词本、AI 问答、收藏本、生词本。

---

## 二、技术栈（必须遵循）

| 层级 | 技术 |
|------|------|
| 前端框架 | Flutter 3.x (SDK ^3.13.0) |
| 状态管理 | flutter_riverpod (StateNotifierProvider) |
| 本地数据库 | SQLite (sqflite) + FTS5 |
| 视频播放 | OmniPlayer（自研） |
| 音频播放 | just_audio |
| UI 组件库 | tdesign_flutter |
| 屏幕适配 | flutter_screenutil（375×812） |
| 后端服务 | Supabase (PostgreSQL + Auth + Storage + Edge Functions) |
| AI 服务 | DeepSeek API |

---

## 三、目录结构（必须遵循）

```
lib/
├── main.dart              # 应用入口
├── models/                # 数据模型（继承 BaseEntity）
├── providers/             # Riverpod 状态管理
├── services/              # 服务层（DB、文件、网络、AI）
├── views/                 # 页面（按功能模块划分）
├── components/            # 公共 UI 组件
├── widgets/               # 业务组件
├── theme/                 # 主题系统
└── utils/                 # 工具类

plugs/                     # 自研/修改的第三方插件
├── omni_player/           # 视频播放内核
├── tdesign_flutter/       # TDesign 组件库
└── tdesign_flutter_adaptation/

supabase/                  # Supabase 后端
├── functions/             # Edge Functions
└── migrations/            # 数据库迁移脚本

docs/                      # 项目文档
```

---

## 四、文件存放决策树

```
新增文件？
│
├─ 是源代码吗？
│  ├─ 数据模型？       → lib/models/{name}.dart
│  ├─ 状态管理？       → lib/providers/{name}_provider.dart
│  ├─ 服务层？         → lib/services/{name}_service.dart
│  ├─ 页面？           → lib/views/{模块}/{name}_page.dart
│  ├─ 公共组件？       → lib/components/{name}.dart
│  ├─ 业务组件？       → lib/widgets/{name}.dart
│  ├─ 主题相关？       → lib/theme/{name}.dart
│  └─ 工具类？         → lib/utils/{name}.dart
│
├─ 是本地插件吗？
│  └─ 自研/修改的插件？ → plugs/{插件名}/
│
├─ 是后端代码吗？
│  ├─ Edge Function？  → supabase/functions/{name}/
│  └─ 数据库迁移？     → supabase/migrations/{timestamp}_{name}.sql
│
└─ 是文档吗？
   ├─ 架构设计？       → docs/developer/architecture/
   ├─ 代码知识库？     → docs/developer/design/code-knowledge-base/
   └─ 其他？           → 按类型归入对应子目录
```

---

## 五、命名规范

### Dart 代码

| 类型 | 规范 | 示例 |
|------|------|------|
| 类/枚举 | PascalCase | `VideoFolder` |
| 文件名 | snake_case.dart | `video_folder.dart` |
| 方法/变量 | camelCase | `videoList`, `loadVideos()` |
| 常量 | k + PascalCase | `kDefaultDuration` |
| 私有成员 | _ + camelCase | `_internalState` |
| 数据库表名 | snake_case | `video_info` |
| 数据库字段 | snake_case | `folder_code` |

### 目录命名

| 场景 | 规范 | 示例 |
|------|------|------|
| 源码目录 | snake_case | `lib/views/files/` |
| 插件目录 | kebab-case 或 snake_case | `omni_player/` |

---

## 六、核心代码规范

### 6.1 数据模型（必须继承 BaseEntity）

```dart
class VideoInfo extends BaseEntity {
  String name;
  String folderCode;
  
  VideoInfo({this.name = '', this.folderCode = ''});
  
  @override
  String get tableName => 'video_info';
  
  @override
  Map<String, dynamic> toMap() => {'name': name, 'folder_code': folderCode};
  
  @override
  BaseEntity fromMap(Map<String, dynamic> map) => VideoInfo(
    name: map['name'] ?? '',
    folderCode: map['folder_code'] ?? '',
  );
}
```

### 6.2 状态管理（Riverpod StateNotifierProvider）

```dart
// State
class FileState {
  final List<VideoFolder> folders;
  final bool isLoading;
  final String? error;
  
  FileState({this.folders = const [], this.isLoading = false, this.error});
}

// Notifier
class FileNotifier extends StateNotifier<FileState> {
  FileNotifier(this._fileService) : super(FileState());
  
  Future<void> loadFolders() async {
    state = state.copyWith(isLoading: true);
    try {
      final folders = await _fileService.getAllFolders();
      state = state.copyWith(folders: folders, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

// Provider
final fileProvider = StateNotifierProvider<FileNotifier, FileState>((ref) {
  return FileNotifier(ref.watch(fileServiceProvider));
});
```

### 6.3 时间字段规范

- **数据库存储**：ISO8601 格式字符串
- **时长字段**：
  - 视频相关（duration/position）：**毫秒**
  - 学习记录（StudyRecord.duration）：**秒**
- **显示转换**：使用 `DurationHelper` 工具类

### 6.4 主题规范

- 双主题支持：亮色 + 暗色（`#2E302A` 黑绿灰）
- 所有颜色从 `AppColors` 获取，禁止硬编码
- 图标统一使用 `AppIcons`（Material rounded 线性风格）
- 间距/圆角使用 `DesignTokens` 常量

### 6.5 文档版本命名规范

- 所有文档文件名必须包含版本号：`{name}-V{major}.md`
- 版本号从 V1.0 开始，每次重大更新递增主版本号
- 过期文档移入 `docs/expired/` 目录，保留原文件名不变
- 示例：`database-schema-V2.0.md`, `overview-V1.0.md`
- **禁止**在文档内容中标注「旧版」「迁移中」「废弃中」等过渡性文字——只记录当前有效状态

### 6.6 组件规范

- 公共组件 → `lib/components/`
- 业务组件 → `lib/widgets/`
- 最小点击区域 48×48 dp
- 支持主题适配

---

## 七、开发流程（必须遵循）

### 7.1 新增模块操作清单

- [ ] 1. 在 `lib/models/` 下创建新模型（继承 BaseEntity）
- [ ] 2. 在 `lib/main.dart` 注册新实体到 DatabaseService
- [ ] 3. 在 `lib/services/` 下创建对应的服务类
- [ ] 4. 在 `lib/providers/` 下创建状态管理
- [ ] 5. 在 `lib/views/` 下创建页面目录和页面文件
- [ ] 6. 如有新组件，在 `lib/components/` 或 `lib/widgets/` 下创建
    - [ ] 7. 更新本文档中的目录结构
    - [ ] 8. 更新 `docs/AGENT_CONTEXT.md`
    - [ ] 9. 更新 `docs/developer/design/code-knowledge-base/` 知识库
    - [ ] 10. 文档文件名带版本号（如 `xxx-V2.0.md`）
    - [ ] 11. 提交 Commit：`chore(structure): 新增 {模块名} 模块`

### 7.2 Git 提交信息

```
<type>(<范围>): <描述>

类型：feat, fix, docs, style, refactor, test, chore
范围：models, services, views, theme, docs, structure, global

示例：
feat(services): 添加 AI 查询服务
fix(views): 修复文件夹详情页封面显示问题
docs: 更新 AGENT_CONTEXT.md 至 V2
chore(structure): 重组 docs 目录结构
```

---

## 八、禁止事项

- ❌ 在项目根目录放置源代码文件（除 main.dart 和配置文件）
- ❌ 在 `lib/` 根目录散落非标准目录的文件
- ❌ 将 `node_modules/`、`.dart_tool/`、`build/` 提交到 Git
- ❌ 在 `plugs/` 中提交 `build/`、`.pub-cache/` 等构建产物
- ❌ 在代码中硬编码颜色值
- ❌ 混淆视频时长（毫秒）和学习记录时长（秒）
- ❌ 随意更新 `plugs/` 下的插件
- ❌ 机械替换函数（如把 `20.w` 直接替换成 `Adaptive.w(context, 20)` 而不思考设计意图）

---

## 九、自适应开发规范

### 9.1 Adaptive 使用原则

**核心原则：不是所有值都需要缩放，要根据设计意图决定**

| 场景 | 是否缩放 | 原因 |
|------|---------|------|
| 页面内边距 | ✅ 是 | 不同设备需要不同留白 |
| 卡片内部间距 | ❌ 否 | 卡片已在外层容器中，内部元素保持固定 |
| 文字大小 | ✅ 是 | 保证可读性 |
| 图标大小 | ✅ 是 | 与文字协调 |
| 固定布局结构 | ❌ 否 | 如 iPhone/iPad 布局切换时的结构差异 |

### 9.2 修改前检查清单

在进行大规模替换前，必须：

1. **理解设计意图**：这个值在什么场景下使用？是否应该随设备缩放？
2. **列出影响范围**：哪些文件会受影响？是否有边界情况？
3. **创建测试页面**：验证缩放效果，不要让用户当测试者
4. **添加调试日志**：输出缩放过程，便于验证

### 9.3 验证流程

1. 修改完成后，先在测试页面验证缩放系数
2. 检查调试日志确认缩放过程正确
3. 在模拟器/真机上验证布局效果
4. 提供验证结果截图或日志

---

## 十、知识库索引

> **文档已精简重构（2026-07-13）**，详见 `docs/DOCUMENTATION_INDEX.md`

| 文档 | 路径 | 说明 |
|------|------|------|
| 文档总索引 | `docs/DOCUMENTATION_INDEX.md` | **首选入口**：目录结构 + 快速查找指南 |
| AI 上下文速查 | `docs/AGENT_CONTEXT.md` | AI 快速恢复认知 |
| **架构总览** | `docs/architecture/overview-V1.1.md` | 产品定位 + 导航(4Tab) + 技术栈 + 开发阶段 + AI多通道架构 |
| **数据库设计** | `docs/architecture/database-schema-V2.0.md` | SQLite 20表 + Supabase 云端表 + DDL + 字段规范 |
| 代码结构 | `docs/reference/flutter-code-structure.md` | Flutter 代码目录详解 |
| 服务架构 | `docs/reference/services-architecture.md` | 服务层架构（51个服务） |
| Supabase 集成 | `docs/reference/supabase-integration.md` | 云端同步 |
| AI 集成 | `docs/reference/ai-service-integration.md` | DeepSeek 集成 |
| TDesign 组件 | `docs/reference/tdesign-components.md` | UI 组件库 |

---

**文档版本**：V1.1
**更新时间**：2026-07-13
**变更**: 知识库路径同步至精简后的 docs/ 新结构
**来源**：从 `项目全局规则.md` 提取核心规则，供 AI 自动加载
