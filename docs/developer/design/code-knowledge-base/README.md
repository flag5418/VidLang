# VidLang - 代码知识库

## 版本记录
| 版本 | 日期 | 修改内容 | 修改人 |
|------|------|----------|--------|
| V1 | 2026-07-12 | 初始版本 | AI助手 |

---

## 一、知识库概述

### 1.1 知识库目的

本知识库旨在为 VidLang 项目的开发提供全面的技术参考，包括 Flutter 代码结构、数据库设计、服务层架构、UI 组件库使用、Supabase 集成等内容。

### 1.2 适用范围

- Flutter 开发人员（前端）
- Supabase 后端开发人员
- 测试人员（QA）
- 项目管理人员（PM）
- AI 辅助开发工具（Cursor / CatPaw）

### 1.3 项目信息

| 项目 | 详情 |
|------|------|
| **项目名称** | VidLang（视频语言学习） |
| **技术栈** | Flutter 3.x + Riverpod + SQLite + Supabase |
| **UI 组件库** | TDesign Flutter（腾讯） |
| **视频播放** | OmniPlayer（自研） |
| **AI 服务** | DeepSeek API（通过 Supabase Edge Functions） |
| **开源协议** | 私有（暂不开源） |

---

## 二、知识库目录

### 2.1 文档列表

| 序号 | 文档名称 | 说明 | 路径 |
|------|----------|------|------|
| 1 | **Flutter 代码结构详解** | lib/ 目录组织、各层职责、关键类说明 | [flutter-code-structure.md](flutter-code-structure.md) |
| 2 | **数据库设计** | SQLite 表结构、字段规范、FTS5 全文检索 | [database-design.md](database-design.md) |
| 3 | **服务层架构** | Services 层设计模式、依赖注入、异常处理 | [services-architecture.md](services-architecture.md) |
| 4 | **状态管理指南** | Riverpod 使用规范、Provider 类型选择、最佳实践 | [state-management-guide.md](state-management-guide.md) |
| 5 | **TDesign 组件库使用** | TDesign Flutter 组件列表、使用示例、定制化 | [tdesign-components.md](tdesign-components.md) |
| 6 | **OmniPlayer 播放器集成** | 自研播放器接口、生命周期、字幕同步 | [omni-player-integration.md](omni-player-integration.md) |
| 7 | **Supabase 集成指南** | Auth、Storage、Edge Functions、Realtime | [supabase-integration.md](supabase-integration.md) |
| 8 | **AI 服务集成** | DeepSeek API 调用、Prompt 设计、错误处理 | [ai-service-integration.md](ai-service-integration.md) |
| 9 | **主题系统详解** | AppTheme、DesignTokens、双主题适配 | [theme-system.md](theme-system.md) |
| 10 | **开发环境配置** | 环境搭建、调试技巧、常用命令 | [development-setup.md](development-setup.md) |

### 2.2 文档关系图

```
code-knowledge-base/
├── README.md                        # 本文件
├── flutter-code-structure.md        # Flutter 代码结构
├── database-design.md               # 数据库设计
├── services-architecture.md         # 服务层架构
├── state-management-guide.md        # 状态管理指南
├── tdesign-components.md            # TDesign 组件库
├── omni-player-integration.md       # OmniPlayer 集成
├── supabase-integration.md          # Supabase 集成
├── ai-service-integration.md        # AI 服务集成
├── theme-system.md                  # 主题系统
└── development-setup.md             # 开发环境配置
```

---

## 三、快速入门

### 3.1 新手入门路径

**推荐学习顺序：**

1. **阅读本文档** - 了解知识库整体结构
2. **阅读 Flutter 代码结构** - 了解项目代码组织
3. **阅读数据库设计** - 了解数据模型和表结构
4. **阅读服务层架构** - 了解业务逻辑层设计
5. **阅读状态管理指南** - 了解 Riverpod 使用方式
6. **阅读 TDesign 组件库** - 了解 UI 组件使用
7. **阅读开发环境配置** - 搭建开发环境

### 3.2 不同角色的学习路径

#### 🎨 UI 开发者

```
Flutter 代码结构 → TDesign 组件库 → 主题系统 → 状态管理指南
```

重点掌握：
- `lib/components/` 和 `lib/widgets/` 的组件使用
- `lib/theme/` 的 DesignTokens 和 AppTheme
- Riverpod 如何驱动 UI 更新

#### 🔧 后端/逻辑开发者

```
数据库设计 → 服务层架构 → Supabase 集成 → AI 服务集成
```

重点掌握：
- `lib/models/` 的模型定义和 CRUD 操作
- `lib/services/` 的业务逻辑封装
- Supabase Edge Functions 的开发和部署
- DeepSeek API 的调用和 Prompt 设计

#### 🤖 AI 辅助开发者（Cursor/CatPaw）

```
AGENT_CONTEXT.md（优先）→ Flutter 代码结构 → 数据库设计 → 全局规则
```

重点掌握：
- `docs/AGENT_CONTEXT.md` 是最高优先级的上下文文档
- `项目全局规则.md` 是必须遵守的规范
- 本知识库提供详细的技术细节

### 3.3 标准开发流程

**从需求到上线的完整流程：**

1. **需求分析** - 明确业务需求和用户场景
2. **数据库设计** - 设计/修改数据模型（`lib/models/`）
3. **服务层开发** - 实现业务逻辑（`lib/services/`）
4. **状态管理** - 定义 Provider 和 State（`lib/providers/`）
5. **UI 开发** - 实现页面和组件（`lib/views/`, `lib/components/`）
6. **单元测试** - 编写测试用例（`test/`）
7. **集成测试** - 测试完整流程
8. **文档更新** - 同步更新相关文档
9. **Code Review** - 提交 PR 进行审查
10. **合并发布** - 合并到主分支，准备发布

---

## 四、核心概念速查

### 4.1 数据流

```
用户操作
    ↓
Widget (views/)
    ↓
Provider (providers/) ← 触发状态变更
    ↓
Service (services/)   ← 执行业务逻辑
    ↓
Model (models/)       ← 数据映射
    ↓
Database (SQLite)     ← 持久化存储
    ↓
[异步] Sync Service   ← 可选：同步到 Supabase
```

### 4.2 关键设计模式

| 模式 | 应用场景 | 示例 |
|------|----------|------|
| **Repository** | 数据访问抽象 | `DatabaseService` 封装所有 DB 操作 |
| **Provider** | 状态管理和依赖注入 | `fileProvider` 管理文件域状态 |
| **Observer** | 响应式 UI 更新 | `Consumer<FileState>` 或 `ref.watch()` |
| **Singleton** | 全局单例服务 | `DatabaseService`, `AuthService` |
| **Factory** | 动态创建对象 | `BaseEntity.fromMap()` 工厂方法 |

### 4.3 常用工具类

| 类名 | 路径 | 用途 |
|------|------|------|
| `DurationHelper` | `lib/models/video_info.dart` | 时长格式化（毫秒 ↔ MM:SS） |
| `AppColors` | `lib/theme/app_colors.dart` | 颜色常量 |
| `AppIcons` | `lib/theme/app_icons.dart` | 统一图标 |
| `DesignTokens` | `lib/theme/design_tokens.dart` | 间距、圆角、阴影 |
| `BaseEntity` | `lib/models/base_entity.dart` | 实体基类（软删除、审计字段） |

---

## 五、常见问题

### Q1: 如何添加新的数据模型？

**A:**
1. 在 `lib/models/` 下创建新文件（如 `article.dart`）
2. 继承 `BaseEntity`，实现 `tableName`, `toMap()`, `fromMap()`
3. 在 `lib/main.dart` 的 `DatabaseService.registerEntities()` 中注册
4. 运行应用，表会自动创建
5. 更新本文档和 `AGENT_CONTEXT.md`

**示例：**
```dart
class Article extends BaseEntity {
  String title;
  String content;
  
  Article({
    this.title = '',
    this.content = '',
  });
  
  @override
  String get tableName => 'article';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      ...super.toMap(),
    };
  }
  
  @override
  BaseEntity fromMap(Map<String, dynamic> map) {
    return Article(
      title: map['title'] ?? '',
      content: map['content'] ?? '',
    )..fromBaseEntity(map);
  }
}
```

### Q2: 如何在页面中使用 Provider？

**A:**
```dart
class MyPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. 监听状态
    final fileState = ref.watch(fileProvider);
    
    // 2. 调用方法
    final fileNotifier = ref.read(fileProvider.notifier);
    
    return Scaffold(
      body: fileState.isLoading
        ? CircularProgressIndicator()
        : ListView.builder(
            itemCount: fileState.folders.length,
            itemBuilder: (context, index) {
              final folder = fileState.folders[index];
              return Text(folder.name);
            },
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => fileNotifier.loadFolders(),
        child: Icon(Icons.refresh),
      ),
    );
  }
}
```

### Q3: 如何处理异步操作和错误？

**A:**
```dart
Future<void> loadData() async {
  state = state.copyWith(isLoading: true, error: null);
  try {
    final data = await _service.fetchData();
    state = state.copyWith(data: data, isLoading: false);
  } catch (e) {
    state = state.copyWith(
      isLoading: false,
      error: e.toString(),
    );
    // 可选：显示错误提示
    showErrorSnackBar('加载失败: $e');
  }
}
```

### Q4: 如何使用 TDesign 组件？

**A:**
```dart
import 'package:tdesign_flutter/tdesign.dart';

// 按钮
TDButton(
  text: '点击我',
  type: TDButtonType.fill,
  theme: TDButtonTheme.primary,
  onTap: () => print(' tapped'),
)

// 输入框
TDInput(
  hintText: '请输入...',
  onChanged: (value) => print(value),
)

// 对话框
TDDialog(
  title: '提示',
  content: '确定要删除吗？',
  onConfirm: () => confirmDelete(),
)
```

详细组件列表见 [TDesign 组件库使用](tdesign-components.md)

### Q5: 如何集成新的 Supabase Edge Function？

**A:**
1. 在 `supabase/functions/` 下创建新目录（如 `ai-query/`）
2. 创建 `index.ts`（Deno 运行时）
3. 编写业务逻辑（调用 DeepSeek API 等）
4. 本地测试：`supabase functions serve ai-query`
5. 部署：`supabase functions deploy ai-query`
6. 在 Flutter 端调用：

```dart
final response = await supabase.functions.invoke('ai-query', body: {
  'word': 'hello',
  'context': 'How are you?',
});
```

详细指南见 [Supabase 集成指南](supabase-integration.md)

---

## 六、开发环境要求

### 6.1 环境要求

| 环境 | 版本要求 | 说明 |
|------|----------|------|
| **操作系统** | macOS 12+ / Windows 10+ / Ubuntu 20.04+ | 跨平台支持 |
| **Flutter SDK** | ^3.13.0 beta | 稳定版也可 |
| **Dart** | 3.x | 与 Flutter SDK 匹配 |
| **IDE** | VS Code / Android Studio / Cursor | 推荐 Cursor（AI 辅助） |
| **Xcode** | 15+ | iOS 开发必需（macOS） |
| **Android SDK** | 34+ | Android 开发必需 |
| **Node.js** | 18+ | Supabase CLI（可选） |
| **Supabase CLI** | latest | Edge Functions 开发（可选） |

### 6.2 推荐的 VS Code 扩展

| 扩展名 | 用途 |
|--------|------|
| Dart | Flutter/Dart 语言支持 |
| Flutter | Flutter 工具链 |
| Flutter Widget Snippets | Widget 代码片段 |
| TDesign Flutter Snippets | TDesign 组件代码片段（如有） |
| Error Lens | 内联错误显示 |
| GitLens | Git 增强 |

---

## 七、参考资源

### 7.1 官方资源

| 资源 | 地址 |
|------|------|
| **Flutter 官方文档** | https://docs.flutter.dev/ |
| **Riverpod 文档** | https://riverpod.dev/ |
| **SQLite 文档** | https://www.sqlite.org/docs.html |
| **Supabase 文档** | https://supabase.com/docs |
| **TDesign Flutter** | https://github.com/Tencent/tdesign-flutter |
| **DeepSeek API** | https://platform.deepseek.com/api-docs |

### 7.2 项目内部文档

| 文档 | 路径 |
|------|------|
| **项目全局规则** | [../../../../../项目全局规则.md](../../../../../项目全局规则.md) |
| **AI 上下文速查** | [../../../../AGENT_CONTEXT.md](../../../../AGENT_CONTEXT.md) |
| **开发规范** | [../../../../DEVELOPMENT.md](../../../../DEVELOPMENT.md) |
| **整体架构** | [../../../../overall-architecture.md](../../../../overall-architecture.md) |
| **设计风格指南** | [../../../../design-style-guide.md](../../../../design-style-guide.md) |

---

## 八、更新日志

### 2026-07-12
- 创建代码知识库
- 添加 Flutter 代码结构文档
- 添加数据库设计文档
- 添加服务层架构文档
- 添加状态管理指南
- 添加 TDesign 组件库文档
- 添加 OmniPlayer 集成文档
- 添加 Supabase 集成文档
- 添加 AI 服务集成文档
- 添加主题系统文档
- 添加开发环境配置文档

---

## 九、贡献指南

### 9.1 如何贡献文档

1. Fork 本仓库（如果开源的话）
2. 在 `docs/developer/design/code-knowledge-base/` 下创建或修改文档
3. 遵循本文档的格式和风格
4. 更新版本记录
5. 提交 PR

### 9.2 文档风格要求

- 使用中文编写（面向国内团队）
- 代码示例使用英文（符合编码规范）
- 表格对齐整齐
- 标题层级清晰（最多 4 级）
- 提供完整的可运行示例

---

**最后更新**: 2026-07-12  
**维护者**: VidLang 开发团队  
**反馈渠道**: GitHub Issues / 内部沟通群
