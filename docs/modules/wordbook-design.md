# VidLang 详细设计 — 生词本

## 一、整体页面布局

```
┌──────────────────────────────────────────────┐
│  ← 生词本  128词        [📝测试] [🔄复习]    │  ← AppBar: 标题 + 数量 + 操作按钮
├──────────────────────────────────────────────┤
│  🔍 查词输入框...          │  📷 翻译        │  ← 查词 + 翻译（一行）
├────────┬─────────────────────────────────────┤
│  导航栏 │  单词卡片列表                       │
│        │                                     │
│ ▾ 生词  │  ┌─────────────────────────────┐  │
│  全部   │  │ unprecedented        🎬     │  │
│  GRE   │  │ /ʌnˈpresɪdentɪd/            │  │
│  日常   │  │ adj. 史无前例的 [GRE][高频]  │  │
│  高频   │  └─────────────────────────────┘  │
│        │  ┌─────────────────────────────┐  │
│ ▾ 已掌握│  │ elaborate             📄    │  │
│  全部   │  │ /ɪˈlæbərət/               │  │
│  工作   │  │ adj. 精心制作的 [工作]       │  │
│        │  └─────────────────────────────┘  │
│        │  ...                               │
├────────┴─────────────────────────────────────┤
│  (选择模式下) 已选 3 词  [全选] [开始测试 ▸]  │  ← 底部操作栏
└──────────────────────────────────────────────┘
```

### 1.1 区域划分

| 区域 | 说明 |
|------|------|
| AppBar | 标题「生词本」+ 单词总数 + 测试/复习按钮（右侧） |
| 查词栏 | 左侧搜索输入框（常驻），右侧拍照翻译按钮（仅 iPhone 显示） |
| 左侧导航 | 两大分类「生词」「已掌握」，各含「全部」和用户标签列表 |
| 右侧列表 | 当前分类/标签下的单词卡片列表（上下两行布局） |
| 底部栏 | 正常模式隐藏；选择模式下显示已选数量 + 全选 + 开始按钮 |

### 1.2 响应式适配

| 设备 | 布局 |
|------|------|
| iPad / 横屏 | 左右分栏常驻，左侧导航始终可见 |
| iPhone 竖屏 | 左侧导航变为可收起的抽屉（Drawer），默认显示右侧列表 |

### 1.3 左侧导航规则

- 标签文字**最多 4 个字符**，超出显示省略号（如 `TOEFL...`）
- 每个标签右侧显示该标签下的单词数量
- 点击标签筛选右侧列表
- 长按标签可编辑/删除

```
导航结构：
▾ 生词 (86)
    全部 (86)
    GRE (12)
    日常 (34)
    高频 (8)

▾ 已掌握 (42)
    全部 (42)
    工作 (15)
    日常 (27)
```

---

## 二、查词与翻译

### 2.1 查词功能

| 平台 | 方案 |
|------|------|
| Android | 内置 stardict.db 离线词典 |
| iPhone | 调用系统词典 UIReferenceLibraryViewController |

- 搜索框输入单词后实时查询
- 查词结果如果已在生词本中，显示「已收藏」标识，可直接跳转详情
- 查词结果页面包含：释义、音标、例句、词形变化、助记

### 2.2 拍照翻译（仅 iPhone）

- 调用 VNDocumentCameraViewController 拍照
- Vision OCR 识别文字
- 翻译后展示结果，支持收藏其中的单词

### 2.3 查词结果页

```
┌──────────────────────────────────────────────┐
│  unprecedented                               │
│  /ʌnˈpresɪdentɪd/     🔊                      │
│                                              │
│  adj. 史无前例的，空前的                       │
│    • an unprecedented success                │
│      空前的成功                               │
│    • unprecedented economic growth           │
│      前所未有的经济增长                        │
│                                              │
│  ── 词形变化 ──                                │
│  比较级: more unprecedented                   │
│  最高级: most unprecedented                   │
│                                              │
│  ── 助记 ──                                   │
│  un-(不) + precede(先于) + -ent(形容词后缀)  │
│  → 前面没有过的 → 史无前例的                  │
│                                              │
│  [☆ 加入生词本]  [标签: +添加]               │
│  （已收藏时显示 ✓ 已收藏，点击可跳转详情）     │
└──────────────────────────────────────────────┘
```

---

## 三、两档记忆评估体系

### 3.1 核心规则

| 操作 | 效果 |
|------|------|
| 点击「认识」 | 单词从「生词」移入「已掌握」，设置 `masteredAt` 时间 |
| 点击「不认识」 | 单词保留在「生词」中，持续出现 |
| 已掌握词点「不认识」 | 单词从「已掌握」移回「生词」 |
| 已掌握词「删除」 | 软删除，单词不再显示 |

**关键**：两档可双向切换，不存在"不可逆"操作。

### 3.2 WordBook 模型扩展

```dart
class WordBook extends BaseEntity {
  String word;                  // 单词
  String sourceType;            // 'video' / 'article' / 'music'
  String sourceCode;            // 来源资源 code
  String? sourceTitle;          // 来源标题
  String? segmentCode;          // 句子/字幕 code
  String? contextSentence;      // 上下文句子原文
  String? screenshotPath;       // 截图路径

  // 词典查询结果（缓存）
  String? definitionsJson;      // 释义 JSON（含词性、释义、例句）
  String? phoneticUk;           // 英式音标
  String? phoneticUs;           // 美式音标
  String? morphologyJson;       // 词形变化 JSON
  String? mnemonic;             // 助记方法

  // 学习状态
  String masteryLevel;          // 'learning' / 'mastered'
  DateTime? masteredAt;         // 掌握时间
  int reviewCount;              // 复习次数
  int correctCount;             // 答对次数
  DateTime? lastReviewAt;       // 最后复习时间
  DateTime? nextReviewAt;       // 下次复习时间
}
```

### 3.3 masteryLevel 状态流转

```
收藏单词 → masteryLevel = 'learning'（生词）
点击认识 → masteryLevel = 'mastered'（已掌握）
已掌握点击不认识 → masteryLevel = 'learning'（回到生词）
已掌握点击删除 → isDeleted = true（软删除，不再显示）
```

### 3.4 复习次数统计

- 单词参与一次测试，即累计一次 `reviewCount`
- 同一场测试中同一单词即使出现多题，也只累计一次复习
- 单词答对时累计一次 `correctCount`
- `lastReviewAt` 在该单词所在测试完成后更新
- `nextReviewAt` 首期保留为推荐字段，不作为主流程门槛

---

## 四、标签系统

### 4.1 数据模型

```dart
// 标签表
class WordTag extends BaseEntity {
  String name;       // 标签名（建议 ≤ 10 字符，导航显示截断为 4 字符）
  int orderIndex;    // 排序索引
}

// 单词-标签关联表（多对多）
class WordBookTag extends BaseEntity {
  String wordBookCode;  // word_book.code
  String tagCode;       // word_tag.code
}
```

### 4.2 标签管理

- **添加标签**：单词详情页 / 查词结果页，点击「+添加」弹出标签选择器
- **删除标签**：单词上点击标签旁的 ✕，移除该单词与标签的关联
- **管理标签**：导航栏底部「管理标签」入口，可新建/编辑/删除标签

### 4.3 标签选择器（使用 TDesign Dialog）

```
┌────────────────────────────────┐
│  管理标签                       │
│                                │
│  当前: [GRE] [高频] [✕]       │
│                                │
│  ☑ GRE                         │
│  ☑ 高频                        │
│  ☐ 日常                        │
│  ☐ 工作                        │
│  ☐ TOEFL                       │
│                                │
│  [+ 新建标签]                   │
│                                │
│         [取消]    [确定]        │
└────────────────────────────────┘
```

所有弹出组件统一使用 **TDesign Flutter** 组件库：
- 对话框：`TDialog`
- 底部弹出：`TBottomSheet`
- 确认操作：`TDialog.confirm()`
- 标签组件：`TTag`

---

## 五、单词卡片列表

### 5.1 卡片布局（上下两行）

```
┌─────────────────────────────────────┐
│ unprecedented              🎬 复习3│  ← 第一行：单词 + 来源图标 + 复习次数
│ /ʌnˈpresɪdentɪd/  adj. 史无前例的  │  ← 第二行：音标 + 简要释义
│ [GRE] [高频]                        │  ← 标签（可点击管理）
└─────────────────────────────────────┘
```

### 5.2 卡片交互

| 操作 | 效果 |
|------|------|
| 单击卡片 | 打开单词详情页 |
| 点击标签 | 弹出标签选择器（管理该单词的标签） |
| 选择模式下点击 | 勾选/取消勾选 |

---

## 六、单词详情页

```
┌──────────────────────────────────────────────┐
│  ← 单词详情                          ☆ 🗑    │  ← 收藏状态 + 删除（已掌握词可删）
├──────────────────────────────────────────────┤
│                                              │
│  unprecedented                               │
│  /ʌnˈpresɪdentɪd/     🔊                      │
│                                              │
│  ── 释义 ──                                   │
│  adj. 史无前例的，空前的                       │
│                                              │
│  ── 例句 ──                                   │
│  • an unprecedented success / 空前的成功      │
│  • unprecedented growth / 前所未有的增长       │
│                                              │
│  ── 词形变化 ──                                │
│  比较级: more unprecedented                   │
│  最高级: most unprecedented                   │
│                                              │
│  ── 助记 ──                                   │
│  un-(不) + precede(先于) + -ent              │
│  → 前面没有过的 → 史无前例的                  │
│                                              │
│  ── 标签 ──                                   │
│  [GRE] [高频] [✕]  [+ 添加]                  │
│                                              │
│  ── 来源上下文 ──                              │
│  📷 [截图]                                    │
│  "This warming is unprecedented"             │
│  来源: Climate Change (视频)                  │
│                                              │
│  ── 学习记录 ──                                │
│  复习 3 次 · 正确率 67%                       │
│  首次收藏: 2026-06-01                         │
│                                              │
├──────────────────────────────────────────────┤
│                                              │
│   ┌──────────────┐    ┌──────────────┐      │
│   │   ✕ 不认识    │    │   ✓ 认识     │      │
│   │  留在生词本   │    │  移入已掌握   │      │
│   └──────────────┘    └──────────────┘      │
│                                              │
└──────────────────────────────────────────────┘
```

---

## 七、测试与复习

### 7.1 操作流程

```
正常模式
  ↓ 点击 [📝测试] 或 [🔄复习]
选择模式（导航和列表出现勾选框）
  ↓ 用户在导航/列表中选择单词
底部栏变化：「已选 N 词」+「全选」+「开始测试/复习 ▸」
  ↓ 点击开始
进入测试/复习执行页面（复用统一测试体系 TestRunner）
```

### 7.2 选择模式下的导航增强

导航区在选择模式下增加智能推荐快捷项：

```
▾ 生词 (86)
    全部 (86)
    ☐ 需复习 (12)        ← nextReviewAt 已过
    ☐ 从未测试 (30)      ← reviewCount = 0
    ☐ 错误率高 (8)       ← 正确率 < 50%
    GRE (12)
    日常 (34)
```

### 7.3 测试配置（点击"开始测试"后弹出）

使用 TDesign Dialog 弹出测试设置：

```
┌────────────────────────────────┐
│  测试设置                       │
│                                │
│  已选单词: 5 个                 │
│                                │
│  题型选择                       │
│  ☑ 释义选择（四选一）           │
│  ☑ 拼写填空                     │
│  ☐ 例句填空                     │
│  ☐ 跟读评分                     │
│                                │
│  每词出题数: [1] [2] [3]       │
│  难度: [简单] [标准] [困难]     │
│                                │
│  预计: 5题 · 约2分钟            │
│                                │
│       [取消]    [开始]          │
└────────────────────────────────┘
```

### 7.4 复习模式

以卡片翻转形式展示：

```
┌──────────────────────────────────────────────┐
│  复习中 · 剩余 5 词                      ✕   │
├──────────────────────────────────────────────┤
│                                              │
│              unprecedented                   │
│          /ʌnˈpresɪdentɪd/                    │
│                 🔊                           │
│                                              │
│           [ 点击显示释义 ]                    │
│                                              │
├──────────────────────────────────────────────┤
│  （翻转后显示释义、例句、助记等）              │
│                                              │
│   ┌──────────────┐    ┌──────────────┐      │
│   │   ✕ 不认识    │    │   ✓ 认识     │      │
│   │  留在生词本   │    │  移入已掌握   │      │
│   └──────────────┘    └──────────────┘      │
│                                              │
└──────────────────────────────────────────────┘
```

### 7.5 适用范围

- 所有单词（生词 + 已掌握）均可参与测试
- 复习主要针对生词，但已掌握词也可被选入复习

---

## 八、已掌握单词的管理

### 8.1 操作

| 操作 | 说明 |
|------|------|
| 查看详情 | 与生词相同的详情页 |
| 点击「不认识」 | 移回生词分类 |
| 删除 | 软删除（`isDeleted = true`），单词不再在任何列表中显示 |

### 8.2 删除确认

使用 TDesign Dialog 确认：

```
┌────────────────────────────────┐
│  确认删除                       │
│                                │
│  删除后该单词将不再显示，       │
│  是否继续？                     │
│                                │
│       [取消]    [删除]          │
└────────────────────────────────┘
```

---

## 九、数据库变更

### 9.1 word_book 表扩展字段

```sql
-- 新增字段
ALTER TABLE word_book ADD COLUMN mastered_at TEXT;
ALTER TABLE word_book ADD COLUMN morphology_json TEXT;
ALTER TABLE word_book ADD COLUMN mnemonic TEXT;
```

### 9.2 新增 word_tag 表

```sql
CREATE TABLE IF NOT EXISTS word_tag (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT NOT NULL,
  user_code TEXT,
  name TEXT NOT NULL DEFAULT '',
  order_index INTEGER NOT NULL DEFAULT 0,
  created_at TEXT,
  updated_at TEXT,
  deleted_at TEXT,
  is_deleted INTEGER NOT NULL DEFAULT 0,
  created_by TEXT,
  updated_by TEXT,
  deleted_by TEXT
);
```

### 9.3 新增 word_book_tag 表

```sql
CREATE TABLE IF NOT EXISTS word_book_tag (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT NOT NULL,
  user_code TEXT,
  word_book_code TEXT NOT NULL,
  tag_code TEXT NOT NULL,
  created_at TEXT,
  updated_at TEXT,
  deleted_at TEXT,
  is_deleted INTEGER NOT NULL DEFAULT 0,
  created_by TEXT,
  updated_by TEXT,
  deleted_by TEXT
);
```

### 9.4 注册到 DatabaseService

```dart
'word_tag': EntityConfig(creator: () => WordTag(), description: '单词标签表'),
'word_book_tag': EntityConfig(creator: () => WordBookTag(), description: '单词-标签关联表'),
```

---

## 十、技术要点

### 10.1 组件库

所有弹出组件统一使用 **TDesign Flutter**（项目已集成 `plugs/tdesign_flutter`）：
- `TDialog` / `TDialog.confirm()` — 确认对话框
- `TBottomSheet` — 底部弹出面板
- `TTag` — 标签展示
- `TInput` — 搜索输入框
- `TCheckbox` — 选择模式勾选
- `TButton` — 操作按钮

### 10.2 查词平台适配

```dart
if (Platform.isAndroid) {
  // 使用内置 stardict.db 查询
} else if (Platform.isIOS) {
  // UIReferenceLibraryViewController 系统词典
  // VNDocumentCameraViewController 拍照翻译
}
```

### 10.3 收藏规则（不变）

- 仅单个单词可收藏（允许 don't 等带撇号）
- 视频/音频收藏时自动截图
- 存储上下文句子
- 同一用户 + 同一单词 + 同一来源不重复收藏
