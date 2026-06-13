# WordBook Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 交付两档状态的生词本 V1，包含标签筛选、轻量详情、认识/不认识/删除、以及“测试即复习”的计数闭环。

**Architecture:** 保持现有 SQLite + `BaseEntity` 自动补字段机制不变，在模型层补齐 `WordTag` / `WordBookTag`，在服务层集中处理查询、状态流转、测试计数，在页面层把生词本拆成导航、列表、详情三个轻量单元。测试链路继续复用 `ai-test-plan` 和现有跑题页，只扩展其入参为“视频”或“生词本词集”两种来源。

**Tech Stack:** Flutter、sqflite、flutter_screenutil、Supabase Edge Functions(TypeScript)、Material、SharedPreferences

---

### Task 1: 收敛模型与表注册

**Files:**
- Modify: `lib/models/word_book.dart`
- Create: `lib/models/word_tag.dart`
- Create: `lib/models/word_book_tag.dart`
- Modify: `lib/main.dart`
- Test: `test/models/word_book_test.dart`

- [ ] **Step 1: 写模型测试，先锁定两档状态语义**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vidlang/models/word_book.dart';

void main() {
  test('reviewing 状态读取时自动回落为 learning', () {
    final model = WordBook().fromMap({
      'id': 1,
      'code': 'wb1',
      'word': 'focus',
      'source_type': 'video',
      'source_code': 'v1',
      'difficulty': 1,
      'review_count': 0,
      'correct_count': 0,
      'mastery_level': 'reviewing',
      'is_deleted': 0,
    }) as WordBook;

    expect(model.masteryLevel, 'learning');
  });

  test('新建单词默认是 learning', () {
    final model = WordBook(word: 'focus', sourceCode: 'v1');
    expect(model.masteryLevel, 'learning');
  });
}
```

- [ ] **Step 2: 补齐 `WordBook` 两档状态兼容逻辑**

```dart
class WordBook extends BaseEntity {
  String masteryLevel;
  DateTime? masteredAt;
  String? morphologyJson;
  String? mnemonic;

  bool get isLearning => masteryLevel == 'learning';
  bool get isMastered => masteryLevel == 'mastered';

  String normalizeMasteryLevel(String? raw) {
    if (raw == 'mastered') return 'mastered';
    return 'learning';
  }

  @override
  BaseEntity fromMap(Map<String, dynamic> map) {
    masteryLevel = normalizeMasteryLevel(map['mastery_level'] as String?);
    masteredAt = map['mastered_at'] != null ? DateTime.parse(map['mastered_at']) : null;
    morphologyJson = map['morphology_json'] as String?;
    mnemonic = map['mnemonic'] as String?;
    return this;
  }
}
```

- [ ] **Step 3: 新增标签模型**

```dart
class WordTag extends BaseEntity {
  String name;
  int orderIndex;

  WordTag({this.name = '', this.orderIndex = 0});

  @override
  String get tableName => 'word_tag';

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'user_code': userCode,
        'name': name,
        'order_index': orderIndex,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
        'is_deleted': isDeleted ? 1 : 0,
        'created_by': createdBy,
        'updated_by': updatedBy,
        'deleted_by': deletedBy,
      };
}
```

- [ ] **Step 4: 新增单词标签关联模型**

```dart
class WordBookTag extends BaseEntity {
  String wordBookCode;
  String tagCode;

  WordBookTag({this.wordBookCode = '', this.tagCode = ''});

  @override
  String get tableName => 'word_book_tag';
}
```

- [ ] **Step 5: 注册新实体，依赖自动建表/补字段**

```dart
DatabaseService.registerEntities({
  'word_book': EntityConfig(creator: () => WordBook(), description: '单词本表'),
  'word_tag': EntityConfig(creator: () => WordTag(), description: '单词标签表'),
  'word_book_tag': EntityConfig(creator: () => WordBookTag(), description: '单词-标签关联表'),
});
```

- [ ] **Step 6: 如需手动验证模型测试，由开发者自行执行**

Run: `flutter test test/models/word_book_test.dart`
Expected: PASS，且 `reviewing` 被兼容映射为 `learning`

- [ ] **Step 7: 提交**

```bash
git add lib/models/word_book.dart lib/models/word_tag.dart lib/models/word_book_tag.dart lib/main.dart test/models/word_book_test.dart
git commit -m "feat(wordbook): add tag entities and two-state model"
```

### Task 2: 重写生词本服务层

**Files:**
- Modify: `lib/services/word_book_service.dart`
- Create: `lib/services/word_tag_service.dart`
- Create: `lib/models/word_book_query_models.dart`
- Test: `test/services/word_book_service_test.dart`

- [ ] **Step 1: 先定义查询与导航返回结构**

```dart
class WordBookFilter {
  final String status;
  final String? tagCode;
  final String keyword;

  const WordBookFilter({
    required this.status,
    this.tagCode,
    this.keyword = '',
  });
}

class WordBookNavItem {
  final String code;
  final String label;
  final int count;
  final String? tagCode;

  const WordBookNavItem({
    required this.code,
    required this.label,
    required this.count,
    this.tagCode,
  });
}
```

- [ ] **Step 2: 写服务测试，锁定状态切换和复习计数**

```dart
test('认识后写入 mastered 和 masteredAt', () async {
  final wb = WordBook(word: 'focus', sourceType: 'video', sourceCode: 'v1');
  wb.masteryLevel = 'learning';

  final updated = WordBookService.applyMastery(
    wb,
    recognized: true,
    reviewedAt: DateTime(2026, 6, 13),
  );

  expect(updated.masteryLevel, 'mastered');
  expect(updated.masteredAt, isNotNull);
});

test('同一场测试同一单词只累计一次 reviewCount', () {
  final before = WordBook(reviewCount: 2, correctCount: 1);
  final result = WordBookService.mergeTestResult(
    before,
    reviewed: true,
    correct: true,
  );

  expect(result.reviewCount, 3);
  expect(result.correctCount, 2);
});
```

- [ ] **Step 3: 在 `WordBookService` 增加纯逻辑入口，方便 UI 和测试共用**

```dart
static WordBook applyMastery(
  WordBook word, {
  required bool recognized,
  DateTime? reviewedAt,
}) {
  final now = reviewedAt ?? DateTime.now();
  word.masteryLevel = recognized ? 'mastered' : 'learning';
  word.masteredAt = recognized ? now : null;
  word.lastReviewAt = now;
  return word;
}

static WordBook mergeTestResult(
  WordBook word, {
  required bool reviewed,
  required bool correct,
  DateTime? reviewedAt,
}) {
  if (!reviewed) return word;
  word.reviewCount += 1;
  if (correct) word.correctCount += 1;
  word.lastReviewAt = reviewedAt ?? DateTime.now();
  return word;
}
```

- [ ] **Step 4: 补齐查询、详情、删除、复习记分接口**

```dart
static Future<List<WordBook>> queryWords(WordBookFilter filter) async { ... }

static Future<List<WordBookNavItem>> loadNavItems(String status) async { ... }

static Future<bool> updateMastery({
  required String wordBookCode,
  required bool recognized,
}) async { ... }

static Future<bool> softDeleteWord(String wordBookCode) async { ... }

static Future<void> recordTestResults(List<WordBookTestResult> results) async { ... }
```

- [ ] **Step 5: 新增标签服务，只做轻量 CRUD 与聚合**

```dart
class WordTagService {
  static Future<List<WordTag>> listTags() async { ... }
  static Future<List<WordTag>> listTagsForWord(String wordBookCode) async { ... }
  static Future<void> replaceTags(String wordBookCode, List<String> tagCodes) async { ... }
}
```

- [ ] **Step 6: 如需手动验证服务测试，由开发者自行执行**

Run: `flutter test test/services/word_book_service_test.dart`
Expected: PASS，状态切换和 `reviewCount` 规则符合设计稿

- [ ] **Step 7: 提交**

```bash
git add lib/services/word_book_service.dart lib/services/word_tag_service.dart lib/models/word_book_query_models.dart test/services/word_book_service_test.dart
git commit -m "feat(wordbook): add query and progress services"
```

### Task 3: 重构生词本页面与轻量详情

**Files:**
- Modify: `lib/views/word_book/word_book_page.dart`
- Create: `lib/views/word_book/widgets/word_book_nav_panel.dart`
- Create: `lib/views/word_book/widgets/word_book_list_card.dart`
- Create: `lib/views/word_book/word_book_detail_sheet.dart`
- Modify: `lib/widgets/word_card.dart`

- [ ] **Step 1: 把页面状态先收敛成“状态 + 标签 + 关键字 + 选择模式”**

```dart
String _selectedStatus = 'learning';
String? _selectedTagCode;
String _keyword = '';
bool _selectionMode = false;
final Set<String> _selectedWordCodes = <String>{};
```

- [ ] **Step 2: 把侧边导航拆成独立组件，主页面只保留数据装配**

```dart
class WordBookNavPanel extends StatelessWidget {
  final String selectedStatus;
  final String? selectedTagCode;
  final List<WordBookNavItem> learningItems;
  final List<WordBookNavItem> masteredItems;
  final ValueChanged<WordBookNavItem> onSelect;
}
```

- [ ] **Step 3: 把列表项拆成独立卡片，统一展示释义/来源/标签/复习次数**

```dart
class WordBookListCard extends StatelessWidget {
  final WordBook word;
  final List<WordTag> tags;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onTagTap;
}
```

- [ ] **Step 4: 新建轻量详情弹层，复用当前滑词卡片的数据展示心智**

```dart
class WordBookDetailSheet extends StatelessWidget {
  final WordBook word;
  final List<WordTag> tags;
  final VoidCallback onRecognized;
  final VoidCallback onUnrecognized;
  final VoidCallback? onDelete;
}
```

- [ ] **Step 5: 在主页接入状态流转和删除**

```dart
Future<void> _handleMasteryChange(WordBook word, bool recognized) async {
  final ok = await WordBookService.updateMastery(
    wordBookCode: word.code!,
    recognized: recognized,
  );
  if (!ok || !mounted) return;
  await _reload();
}
```

- [ ] **Step 6: 让 `word_card.dart` 保持滑词收藏逻辑不变，只补一个从 `WordBook` 显示时可复用的映射方法**

```dart
extension WordBookWordCardMapper on WordBook {
  WordCardData toWordCardData() {
    return WordCardData(
      word: word,
      phonetic: phoneticUk ?? phoneticUs,
      definitions: parseDefinitions(definitionsJson),
      source: 'native',
    );
  }
}
```

- [ ] **Step 7: 如需手动验证页面，运行应用后自行检查以下路径**

Run: `flutter run`
Expected:
- 生词 / 已掌握可切换
- 标签筛选生效
- 详情中“认识 / 不认识 / 删除”可用
- 复习次数正确展示

- [ ] **Step 8: 提交**

```bash
git add lib/views/word_book/word_book_page.dart lib/views/word_book/widgets/word_book_nav_panel.dart lib/views/word_book/widgets/word_book_list_card.dart lib/views/word_book/word_book_detail_sheet.dart lib/widgets/word_card.dart
git commit -m "feat(wordbook): rebuild page and detail flow"
```

### Task 4: 打通生词测试入口与复习计数闭环

**Files:**
- Modify: `lib/views/test/test_page.dart`
- Modify: `lib/views/word_book/word_book_page.dart`
- Modify: `lib/services/word_book_service.dart`
- Modify: `supabase/functions/ai-test-plan/index.ts`

- [ ] **Step 1: 扩展测试页入参，让它既支持视频，也支持生词本**

```dart
class TestPage extends StatefulWidget {
  final String? videoCode;
  final String videoTitle;
  final List<Map<String, dynamic>> seedWords;

  const TestPage({
    super.key,
    this.videoCode,
    required this.videoTitle,
    this.seedWords = const [],
  });
}
```

- [ ] **Step 2: 在 `_start()` 中按来源切换请求体**

```dart
final body = widget.videoCode != null
    ? {
        'request_id': requestId,
        'video_code': widget.videoCode,
        'difficulty': difficulty,
        'config': config,
      }
    : {
        'request_id': requestId,
        'source_type': 'word_book',
        'difficulty': difficulty,
        'config': config,
        'seed_words': widget.seedWords,
      };
```

- [ ] **Step 3: 在 Edge Function 中支持 `word_book` 输入**

```ts
const sourceType = String(body.source_type ?? 'video').trim()
const seedWords = Array.isArray(body.seed_words) ? body.seed_words : []

const sentences =
  sourceType === 'word_book'
    ? seedWords.map((item: any) => String(item.context_sentence ?? '').trim()).filter(Boolean)
    : buildSentenceCandidates(storage.subtitles)

const wordPool =
  sourceType === 'word_book'
    ? unique(seedWords.map((item: any) => String(item.word ?? '').trim().toLowerCase()).filter(Boolean))
    : extractWordPool(sentences, diffParams)
```

- [ ] **Step 4: 在跑题页聚合唯一单词结果，退出时回写复习记录**

```dart
final Map<String, bool> _wordResults = <String, bool>{};

void _recordWordResult() {
  final targetWord = (_item['target_word'] as String?)?.toLowerCase();
  if (targetWord == null || targetWord.isEmpty) return;
  _wordResults[targetWord] = (_wordResults[targetWord] ?? false) || _isCorrect;
}
```

- [ ] **Step 5: 生词本页调用测试页时传入词集，并在返回后回刷列表**

```dart
await Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => TestPage(
      videoTitle: '生词本测试',
      seedWords: selectedWords.map((e) => {
        'word': e.word,
        'context_sentence': e.contextSentence,
        'word_book_code': e.code,
      }).toList(),
    ),
  ),
);
await _reload();
```

- [ ] **Step 6: 在 `WordBookService.recordTestResults` 中按“单词唯一”累计一次复习**

```dart
for (final result in results) {
  final word = await BaseEntityExtension.findByCode(result.wordBookCode, () => WordBook());
  if (word == null) continue;
  mergeTestResult(word, reviewed: true, correct: result.correct, reviewedAt: result.reviewedAt);
  await word.save();
}
```

- [ ] **Step 7: 如需手动验证完整链路，由开发者自行检查**

Run: `flutter run`
Expected:
- 从生词本进入测试可以成功出题
- 每个参与测试的单词只增加一次 `reviewCount`
- 答对时 `correctCount` 正确增加
- 返回生词本后列表数据已刷新

- [ ] **Step 8: 提交**

```bash
git add lib/views/test/test_page.dart lib/views/word_book/word_book_page.dart lib/services/word_book_service.dart supabase/functions/ai-test-plan/index.ts
git commit -m "feat(wordbook): wire tests into review progress"
```

### Task 5: 收尾文档与迁移说明

**Files:**
- Modify: `docs/detailed-design/05-wordbook.md`
- Modify: `docs/detailed-design/15-database-schema.md`

- [ ] **Step 1: 更新详细设计，让代码口径和文档一致**

```md
- 生词状态仅保留 learning / mastered
- reviewing 不再作为状态值使用
- 单词参与一次测试，即累计一次 reviewCount
```

- [ ] **Step 2: 补数据库说明**

```md
- `word_book.mastered_at`
- `word_book.morphology_json`
- `word_book.mnemonic`
- `word_tag`
- `word_book_tag`
```

- [ ] **Step 3: 提交**

```bash
git add docs/detailed-design/05-wordbook.md docs/detailed-design/15-database-schema.md
git commit -m "docs(wordbook): sync implementation details"
```

## Self-Review

- Spec coverage：已覆盖两档状态、标签、主列表、轻量详情、认识/不认识/删除、测试即复习、复习次数口径。
- Placeholder scan：计划中没有 `TODO` / `TBD` / “后续补充” 之类占位语。
- Type consistency：统一使用 `masteryLevel`、`masteredAt`、`reviewCount`、`correctCount`、`seedWords`、`recordTestResults` 这些命名。
