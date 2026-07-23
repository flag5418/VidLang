# VidLang 测试规范

> **版本**: V1.0 | **日期**: 2026-07-22
> **优先级**: 所有 AI 生成代码时**必须同步生成对应测试**

---

## 一、测试哲学

### 核心原则

1. **测试不是可选项** — 没有测试的代码视为未完成
2. **先写测试再写代码（TDD）** — 红-绿-重构循环
3. **测试是活的文档** — 测试用例描述系统行为，比注释更可靠
4. **测试速度决定测试频率** — 单元测试要快（ms级），集成测试要少

### 测试金字塔（VidLang 适用版）

```
        ⬆  E2E (5%)     — 关键用户流程
      ⬆⬆⬆  Integration (15%)  — 数据库、服务、API
    ⬆⬆⬆⬆⬆⬆⬆  Widget (30%)    — UI 组件交互
  ⬆⬆⬆⬆⬆⬆⬆⬆⬆⬆⬆⬆⬆⬆  Unit (50%)     — 模型、工具类、逻辑
```

| 层级 | 速度 | 数量目标 | 职责 |
|------|------|---------|------|
| Unit | <10ms/个 | 50%+ | 纯逻辑：模型、工具函数、状态变更 |
| Widget | <100ms/个 | 30% | 组件渲染、用户交互、状态展示 |
| Integration | <1s/个 | 15% | DB 读写、服务协作、API 调用 |
| E2E | >5s/个 | 5% | 核心用户旅程（播放→查词→收藏） |

---

## 二、技术选型

| 场景 | 技术 | 理由 |
|------|------|------|
| 测试框架 | `flutter_test` | Flutter SDK 内置，无需额外依赖 |
| 集成测试 | `integration_test` | Flutter 官方方案 |
| Mock | **`mocktail`** | 无需代码生成，零配置，类型安全 |
| 数据库测试 | `sqflite_common_ffi` | 已在用，桌面环境运行 SQLite |
| 测试覆盖率 | `flutter test --coverage` + `lcov` | 生成 HTML 报告 |
| CI | **GitHub Actions** | 免费、与仓库集成、社区成熟 |
| 断言风格 | `shouldly` / 原生 `expect` | 保持 Flutter 原生 `expect` |

### Mocktail 入门

```yaml
# pubspec.yaml dev_dependencies
dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.4
```

```dart
// 定义 Mock
class MockDatabaseService extends Mock implements DatabaseService {}

// 使用
final mockDb = MockDatabaseService();
when(() => mockDb.getVideoFolders()).thenAnswer((_) async => []);
```

---

## 三、测试文件组织

### 目录结构

```
test/
├── widget_test.dart                  # 基础 smoke test
├── models/                           # 对应 lib/models/
├── services/                         # 对应 lib/services/
├── views/                            # 对应 lib/views/
│   └── {module}/
│       ├── providers/                # 模块 provider 测试
│       └── widgets/                  # 模块 widget 测试
├── integration/                      # 跨服务/跨模块集成测试
└── e2e/                              # 完整用户旅程
```

### 文件名规则

```
test/{对应目录}/{file_name}_test.dart
```

示例：
- `lib/models/video_folder.dart` → `test/models/video_folder_test.dart`
- `lib/services/database_service.dart` → `test/services/database_service_test.dart`
- `lib/views/player/unified/providers/player_engine_provider.dart` → `test/views/player/unified/providers/player_engine_provider_test.dart`

---

## 四、测试编写规范

### 4.1 命名规范

```
<方法/组件名>：<场景> → <期望行为>
```

```dart
// ✅ 好
test('VideoFolder.fromMap: 有效数据 → 正确解析所有字段', () { ... });
test('Subtitles.search: 空查询 → 返回空列表', () { ... });
testWidgets('WordCard: 点击收藏按钮 → 切换收藏状态', (tester) async { ... });

// ❌ 差
test('test1', () { ... });
test('folder test', () { ... });
```

### 4.2 结构规范（AAA 模式）

每个测试用例遵循 Arrange-Act-Assert：

```dart
test('DatabaseService.getFolders: 查询成功 → 返回文件夹列表', () async {
  // Arrange
  final db = await _createTestDatabase();
  await db.insert('video_folder', {'name': 'test', 'code': 't1'});
  
  // Act
  final folders = await DatabaseService(db).getAllFolders();
  
  // Assert
  expect(folders.length, 1);
  expect(folders.first.name, 'test');
});
```

### 4.3 数据库测试规范

```dart
// 每个测试独立数据库，避免状态污染
setUp(() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  db = await databaseFactory.openDatabase(':memory:');
  await db.execute('CREATE TABLE ...');
});

tearDown(() async {
  await db.close();
});
```

### 4.4 Widget 测试规范

```dart
testWidgets('WordCard: 渲染收藏状态 → 显示对应图标', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: WordCard(
        word: WordDetail(word: 'hello'),
        isBookmarked: true,
        onToggleBookmark: () {},
      ),
    ),
  );
  
  expect(find.byIcon(Icons.bookmark), findsOneWidget);
  expect(find.byIcon(Icons.bookmark_border), findsNothing);
});
```

### 4.5 Provider 测试规范

```dart
test('FileNotifier: loadFolders 异常 → error 状态设置', () async {
  // 注入失败的 mock
  final mockService = MockFileService();
  when(() => mockService.getAllFolders()).thenThrow(Exception('DB error'));
  
  final notifier = FileNotifier(mockService);
  expect(notifier.state.isLoading, false);
  
  await notifier.loadFolders();
  
  expect(notifier.state.isLoading, false);
  expect(notifier.state.error, contains('DB error'));
});
```

---

## 五、Mock 策略

### 5.1 架构问题与改进方向

**当前问题**：`DatabaseService` 和 `AiService` 使用静态方法和单例，导致难以 mock。

```dart
// ❌ 当前：静态方法，无法 mock
class DatabaseService {
  static Database? _database;
  static Future<List<VideoFolder>> getAllFolders() async { ... }
}

// ✅ 改进：实例方法 + 依赖注入
class DatabaseService {
  final Database _db;
  DatabaseService(this._db);
  Future<List<VideoFolder>> getAllFolders() async { ... }
}
```

**渐进式改进**：在新模块和服务中优先使用构造函数注入，逐步重构旧代码。

### 5.2 Mock 类型选择

| 场景 | 方式 | 说明 |
|------|------|------|
| 纯接口 | `Mock implements Interface` | mocktail 自动实现 |
| 具体类 | `Mock extends Class` | 覆盖需要 mock 的方法 |
| 简单数据 | 手写 fake class | 适用于数据类、DTO |
| 静态方法 | **重构**为实例方法 | 静态方法无法 mock |

### 5.3 禁止事项

- ❌ 在测试中依赖真实网络请求
- ❌ 测试之间共享可变状态
- ❌ 依赖 `Future.delayed` 来等待异步操作（使用 `tester.pump()` 或 `fake_async`）
- ❌ 在单元测试中加载 `MaterialApp` 全量路由（使用 `MaterialApp` 的最小配置或 `TestWidgetsFlutterBinding`）

---

## 六、覆盖率目标

| 层级 | 当前 | 目标 | 测量方式 |
|------|------|------|---------|
| 数据模型（models/） | 低 | **90%+** | line coverage |
| 工具类（utils/） | 0% | **90%+** | line coverage |
| 服务层（services/） | 中 | **80%+** | line coverage |
| 状态管理（providers/） | 0% | **80%+** | line coverage |
| UI 组件（components/ + views/*/widgets/） | 0% | **60%+** | line coverage |
| 页面（views/*/pages/） | 0% | **40%+** | widget test coverage |
| **项目整体** | **~15%** | **70%+** | `flutter test --coverage` |

### 覆盖率命令

```bash
# 运行所有测试
flutter test

# 运行单个文件
flutter test test/models/video_folder_test.dart

# 带覆盖率报告
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html

# 按标签运行（需要配置 tags）
flutter test --tags=unit
flutter test --tags=integration
```

---

## 七、GitHub Actions CI 配置

在 `.github/workflows/` 下创建 `test.yml`：

```yaml
name: VidLang Test Suite
on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.27.0'
          channel: 'stable'
      
      - name: Install dependencies
        run: flutter pub get
      
      - name: Analyze
        run: flutter analyze
      
      - name: Run tests with coverage
        run: flutter test --coverage
      
      - name: Upload coverage
        uses: codecov/codecov-action@v4
```

---

## 八、Skill 集成 — 文档编写检查清单

当 AI 被要求编写文档时，**必须自动检查以下内容**：

```markdown
### 文档测试完整性检查
- [ ] 是否有对应的测试计划/测试场景？
- [ ] 是否描述了测试策略？
- [ ] 关键边界条件是否列出？
- [ ] Mock/Stub 策略是否说明？
- [ ] 是否包含验证标准（怎样算"完成"）？
```

将此检查清单作为 `docs/developer/testing-standards-V1.0.md` 的固定部分，AI 在编写任何设计文档时必须引用。

---

## 九、VidLang 特定测试场景

| 模块 | 测试重点 | 示例 |
|------|---------|------|
| **视频播放** | 播放状态转换、字幕同步、倍速 | 播放→暂停→seek→恢复 |
| **文章阅读** | 段落解析、查词交互、翻译显示 | 点击单词→显示释义 |
| **音频/歌曲** | LRC 解析、跟唱评分、歌词滚动 | LRC 时间轴→歌词同步 |
| **跟读评分** | 录音→评分算法、分数范围 | 满分→100分、静音→0分 |
| **单词本** | 收藏/取消、标签管理、复习抽卡 | 收藏→生词本出现 |
| **测试引擎** | 填空/选择/听写，答案校验 | 听力题→播放→选答案 |
| **AI 对话** | 消息发送/接收、流式展示、token 统计 | 发送→显示 loading→收到回复 |
| **计费/充值** | 余额变更、扣费逻辑、恢复购买 | 充值→余额增加→使用扣费 |
| **论坛** | 发帖/回帖、举报/审核、通知 | 发帖→列表可见→回帖→通知 |
| **数据库并发** | 多线程读写、事务回滚、迁移 | 200并发写入→数据不丢失 |

---

## 十、文献参考

本规范参考以下业界最佳实践：

- Google Testing Blog: "Just Say No to More End-to-End Tests"
- Flutter 官方测试文档: `docs.flutter.dev/testing`
- Martin Fowler: "TestPyramid" (martinfowler.com/bliki/TestPyramid.html)
- clean-code-typescript 测试章节
- Flutter Testing Guide (Vg麦库)

---

**文档版本**: V1.0
**更新时间**: 2026-07-22
**变更**: 初始版本，建立 VidLang 完整测试规范
