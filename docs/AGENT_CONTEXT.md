# VidLang — AI 上下文速查（优先读此文件）

> **用途**：供 Cursor/Agent 快速恢复项目认知，避免每次重读全库。  
> **维护**：功能/架构有实质变化时由开发者或 Agent 增量更新本节。  
> **最后核对**：2026-05-20（含产品方确认的文件夹模型、主题、路线图）

---

## 1. 产品是什么

**VidLang**：通过**本地视频 + 字幕**学习英语的工具（非简单播放器）。字幕是核心依赖——无字幕则测试、滑词、单句暂停、变速等均不可用；允许用户**手动为视频选择字幕文件**。

核心学习闭环（目标态）：

```
视频集管理 → 播放（断点、片头片尾）→ 字幕/分词存储 → 滑词/单句暂停/变速
→ 单集测试 / 视频集综合评测 → 学习记录
```

**视觉**：汽水音乐 + 腾讯 Lemon——干净、层级清晰、**图标统一**（`lib/theme/app_icons.dart`，Material rounded 线性风格）。  
**主题（已确认）**：
- 深色背景主色：`#2E302A`（黑绿灰，非纯黑）
- 浅色：以白色为主
- 两套主题都要保留

详见 `design-style-guide.md`（待按上表更新）、`pages/files.md`。

---

## 1.1 视频集（文件夹）两种类型 — 产品定义

| 类型 | 用户说法 | 行为 | 存储 |
|------|----------|------|------|
| **虚拟视频集** | 首屏创建、导入本地文件夹 | 按用户磁盘上**文件夹名**在 App 内建一条记录；**视频/字幕文件不拷入应用目录**（省空间）；`VideoFolder.path` 指向源目录；详情**只列视频**，不展示同目录下的字幕/图片/文本等文件条目 | 元数据在 SQLite；媒体路径在设备原位置 |
| **真实视频集** | WiFi 传输模块（后续） | 设备开 WiFi 服务，电脑浏览器上传/管理；App 内创建的真实目录；文件默认进应用目录（**可讨论**是否改为系统可访问路径，便于用系统文件管理器管理） | 后续实现 |

**与当前代码的差异（待修）**：
- 导入用了 `VideoFolderType.local`，产品语义应为**虚拟集**（绑定外部 `path`）。
- `VideoInfo` **缺少 `filePath`（或等价字段）**，导入后未持久化视频原路径 → 播放前必须补。
- `file_picker_service` 注释写「复制到应用目录」，实际 `_importLocalVideo` **未调用** `copyFileToAppDirectory`（与「不搬家」一致，但缺路径字段是 bug）。
- 手动「新建文件夹」`createFolder` 用了 `local`，应为 **virtual**（空集，待用户导入或加视频）。

**枚举建议映射**（实现时统一命名）：
- `VideoFolderType.virtual` → 绑定外部路径的视频集（导入/手动空集）
- `VideoFolderType.local`（或改名 `managed`）→ WiFi/App 托管目录的视频集

---

## 2. 技术栈（以 `pubspec.yaml` 为准）

| 领域 | 选用 |
|------|------|
| 框架 | Flutter 3.x（SDK `^3.13.0` beta） |
| 状态 | `flutter_riverpod`（`StateNotifierProvider` + `FileNotifier`） |
| 数据库 | `sqflite`，库名 `vidlang.db`，实体注册式建表 |
| 缩略图 | `flutter_video_thumbnail_plus` |
| 选文件 | `file_picker` |
| 取时长 | `video_player`（仅导入时探测，**非播放页**） |
| 布局 | `flutter_screenutil`（设计稿 375×812） |
| 弹窗/动效 | `awesome_dialog`、`lottie` |

**文档过时注意**：`docs/README.md` 仍写 Better Player / `video_thumbnail`，实际依赖已换，以上表为准。

---

## 3. 代码结构（实际 `lib/`）

```
lib/
├── main.dart                 # 注册 DB 实体、ScreenUtil、主题、MainPage
├── models/
│   ├── base_entity.dart      # 软删除、审计字段、扩展 CRUD
│   ├── video_folder.dart     # 文件夹（片头片尾跳过、封面时间点等）
│   ├── video_info.dart       # 视频元数据 + DurationHelper
│   ├── study_record.dart     # 学习记录（模型存在，见 §6 缺口）
│   ├── subtitles.dart        # 字幕（FTS）
│   ├── participle.dart       # 分词（FTS）
│   ├── user.dart / config.dart
├── providers/
│   ├── file_provider.dart    # 文件夹/视频 CRUD、播放状态、学习记录 API
│   ├── navigation_provider.dart
│   └── user_provider.dart
├── services/
│   ├── database_service.dart # 注册实体、自动建表/迁移、FTS5
│   ├── file_picker_service.dart  # 导入视频/字幕、扫描、复制到应用目录
│   ├── thumbnail_service.dart
│   └── file_manager_service.dart # 物理目录 CRUD（与 DB 文件夹并行）
├── views/
│   ├── main/main_page.dart   # 底部栏：视频 | 我的（仅 2 Tab）
│   ├── files/
│   │   ├── file_list_page.dart    # 「我的视频」文件夹网格
│   │   └── folder_detail_page.dart # 顶部大卡片 + 九宫格视频
│   ├── home/home_page.dart   # 占位，未接入主导航
│   ├── profile/profile_page.dart # 占位
│   └── login/index.dart      # 存在，未在 main 路由使用
├── components/
│   ├── folder_card.dart / main_video_card.dart / video_card.dart
│   └── import_progress_dialog.dart
└── theme/                    # AppTheme、DesignTokens、颜色/间距/圆角
```

---

## 4. 数据库实体（`main.dart` 已注册）

| tableName | FTS | 说明 |
|-----------|-----|------|
| `video_folder` | 否 | 逻辑文件夹，含 `skip_opening/ending`、`thumbnail_time` |
| `video_info` | 否 | 视频；时长/进度均为**毫秒** |
| `subtitles` | 是 | 字幕行，按 `video_code` 关联 |
| `participle` | 是 | 分词，供检索 |
| `config` | 否 | 系统配置（含 current_user_code） |
| `user` | 否 | 用户 |

**未注册但已有模型**：`study_record`（`file_provider` 会 insert/query，表可能不存在 → 运行时风险）。

---

## 5. 当前实现进度

### 产品方确认的首页 / 详情行为

**首页（视频集列表，类似播放器库）：**
- 列表项 = 视频集；**第一项 = 最近播放的视频集**（按 `last_play_date` 等排序）
- 每项：封面、总集数、已播完集数、**整体播放进度**
- 封面规则：默认 = 第一集封面；该集有播放后 = **最后一次播放视频的截图**（`currentCover` / 播放截图逻辑）
- 搜索：**仅按视频集名称**过滤（视频集多时）
- WiFi 入口在首页菜单（后续开发）

**详情页：**
- 顶部：**最后一次播放**的那一集（大卡）
- 下方：同集内其他视频——状态（未播放 / 播放中 / 正在播放 / 已播完）、进度、**字幕状态**、名称
- 视频集级：**综合评测**（后做）；单视频：**单元测试**（后做，有字幕才可测）

### 已完成 / 可用

- 文件列表 + 详情 UI 骨架、导入扫描视频+字幕入库、缩略图、`fileProvider` 基础 CRUD
- 主题令牌半完成（**编译断裂**，见 §6）
- `AppIcons` 统一 Material rounded 图标

### 未实现 / 占位

| 模块 | 状态 |
|------|------|
| 主题编译修复 + 双色 `#2E302A` / 白 | **阻塞** |
| 首页排序/封面/进度/真搜索 | 部分有字段，逻辑/UI 未对齐产品 |
| `VideoInfo.filePath`、虚拟/真实类型修正 | **数据模型缺口** |
| 手动选择字幕文件 UI | 未做 |
| WiFi 真实视频集 | 后续 |
| 视频播放页 | **最后做**；播放前需敲定截图、字幕、分词存储 |
| 单元测试 / 综合评测 | 后续 |
| `StudyRecord` 表注册 | 未注册 |

### 开发顺序（产品方）

1. **现在**：优化显示、修 bug、图标/主题统一  
2. **测试稳定后**：WiFi 传输  
3. **最后**：视频播放；播放前完善截图、字幕、分词存储（滑词、单句暂停、慢→快）

---

## 6. 已知缺口与不一致（改代码时优先处理）

1. **`app_colors.dart` ↔ `app_theme.dart` 断裂** → 60+ 编译错误；深色应用 `#2E302A` 未落地。
2. **`VideoInfo` 无媒体路径字段** → 虚拟集无法从原路径播放。
3. **文件夹类型语义**：导入/新建与 `VideoFolderType` 枚举不一致（见 §1.1）。
4. **`StudyRecord` 未在 `main.dart` 注册**。
5. **`completedCount`**：导入里曾错误写成 `hasSubtitles` 计数，应与「播完集数」区分。
6. **播放状态**：产品四态需在 UI 层由 `isCurrentPlaying` + `currentPosition`/`duration` 计算；可抽 `PlayStatus` 工具。
7. **字幕**：导入会解析入库，但需支持手动重选字幕文件；`hasSubtitles` 为关键 UI 状态。

---

## 7. 关键业务流程（简图）

### 启动

`main()` → `DatabaseService.registerEntities(...)` → `ProviderScope` → `VidLangApp` → `MainPage` → 默认 `FileListPage`。

### 打开文件夹

`FileListPage` tap → `FolderDetailPage(folderCode)` → `loadVideos` → 取 `isCurrentPlaying` 或列表首项为 `currentVideo`。

### 导入视频（详情或列表）

`FilePickerService` → DB insert `VideoInfo`（及字幕）→ `fileProvider.loadVideos` / `loadFolders`。

### 切换当前集（详情九宫格）

`setCurrentVideo` / `selectVideo` → 批量更新 `is_current_playing` → 更新文件夹 `last_video_code` 等。

---

## 8. 页面与路由（现状）

无命名路由表；均为 `Navigator.push`：

- `MainPage` → `FileListPage` | `ProfilePage`
- `FileListPage` → `FolderDetailPage`
- **尚无** → 播放页

规划路由见 `design-style-guide.md` §5.2：`/`、`/files`、`/play`、`/study`、`/profile`。

---

## 9. 文件管理 UI 要点（实现对照 `pages/files.md`）

- **首页**：3 列文件夹卡片；角标 `completedCount/videoCount`；末尾「新建」卡片；`+` 菜单：导入文件、WiFi（未做）
- **详情**：顶部大卡（封面、播放钮、进度条、字幕图标、名称）；下方 4 列九宫格；点击格子切换当前集
- **字幕**：有字幕才可「测试」；无字幕菜单无测试项
- **播放四种态**：○ 未播放 / ◐ 部分 / ▶ 当前 / ✓ 完成 — 需在组件层用 `VideoInfo` 字段计算

---

## 10. 后续路线图（产品方确认）

**阶段 A（当前）**：修编译/主题；首页与详情显示对齐 §5；`filePath` + 虚拟集类型；真搜索；图标统一；不启动播放页。

**阶段 B**：WiFi 真实视频集（存储策略可选：应用私有 vs 用户可见目录）。

**阶段 C**：播放前设计——截图路径、字幕表、分词表、手动字幕选择、为滑词/单句暂停/变速预留字段。

**阶段 D**：播放器 + 学习记录 + 单集测试 + 综合评测。

---

## 11. 配置体系：全局 vs 视频集 vs 多级文件夹

### 11.1 已有数据能力

| 层级 | 存储 | 字段（播放相关） |
|------|------|------------------|
| **全局默认** | `config` 表，`category` + `key` + `value` + `value_type` | 待约定键名（见下） |
| **视频集/文件夹** | `video_folder` 表 | `skip_opening`, `skip_opening_duration`, `skip_ending`, `skip_ending_duration`, `thumbnail_time` |
| **层级** | `video_folder.parent_code` | 已建字段；**UI/查询未实现**（当前 `loadFolders` 拉全表扁平列表） |

`Config` 是通用 KV（`category`/`key`/`value`/`ValueType`），适合分类存：系统、外观、播放、网络等。  
目前代码里 `config` **仅用于** `DatabaseService` 的 `current_user_code` / `current_token`（`category = system`），**尚无**播放类全局配置的读写封装。

### 11.2 建议的全局键（`category: playback`）

| key | type | 含义 |
|-----|------|------|
| `skip_opening_enabled` | boolean | 默认是否跳过片头 |
| `skip_opening_seconds` | number | 默认片头秒数 |
| `skip_ending_enabled` | boolean | 默认是否跳过片尾 |
| `skip_ending_seconds` | number | 默认片尾秒数 |
| `thumbnail_time_seconds` | number | 默认封面截图时间点（秒） |

新建视频集时：**从全局拷贝**到 `VideoFolder` 各字段（用户再在集级修改）。  
导入时生成缩略图用该集的 `thumbnail_time`（无则回落全局）。

### 11.3 解析优先级（播放 / 完成判定 / 统计时用）

建议单一入口 `resolvePlaybackSettings(folder)`：

```
有效设置 = 当前视频集字段（已显式保存）
         → 若需支持多级：沿 parent_code 向上找祖先（可选：子覆盖父）
         → 全局 config 默认值
```

**与「播完」的关系**（播放阶段实现，逻辑要先定）：

- 有效时长 ≈ `duration - skipOpeningDuration - skipEndingDuration`（启用时）
- **播完**：`currentPosition` 达到有效终点（不是物理片尾）
- **完整播放次数**：一次会话内有效区间从头到尾算 1 次（跳过片头片尾后的区间）

### 11.4 UI 入口（阶段 A 可只做壳，阶段 D 接播放）

| 位置 | 操作 |
|------|------|
| **我的 / 设置** | 「播放与封面」→ 全局开关 + 秒数步进器 + 封面时间点 |
| **视频集详情 ··· 菜单** | 「播放设置」→ 同三项；保存写 `VideoFolder` |
| **视频集卡片长按**（可选） | 快捷进入播放设置 |
| **多级文件夹** | 首页只显示 `parent_code == null`；进入有子级的集 → 子文件夹列表 + 面包屑；**叶子集**才进现有「大卡+视频列表」详情 |

图标：统一 `AppIcons`（如 `settings`、`skipNext` 等 rounded 线性），与汽水/Lemon 一致。

### 11.5 已确认（2026-05-20）

1. **视频仅挂在叶子视频集**（二级结构：分组 `parent_code` 空 + 叶子 `parent_code` 非空）。  
2. **暂不做 3 级以上**；以后有需求再扩展。  
3. **首页只列叶子视频集**，按 `last_play_date` 倒序（未播放排后）。  
4. 播放设置：全局 `Config` + 视频集 `VideoFolder` 字段；新建集从全局拷贝。  
5. `SettingsService.ensureDefaultGroupCode()` 提供默认分组「未分组」。

---

## 12. 相关文档索引

| 文件 | 内容 |
|------|------|
| `README.md` | 模型字段、DB 规范、路线图（部分技术栈过时） |
| `DEVELOPMENT.md` | 注释/命名/Git 规范 |
| `design-style-guide.md` | 视觉与交互规范 |
| `pages/files.md` | 文件管理页交互与状态（最细） |
| `pages/files-v2.pen` | 设计稿（Pencil） |

---

## 12. 给 Agent 的工作约定

- 改 UI 前先对 `theme/` 与 `design-style-guide.md`
- 改数据先对 `BaseEntity` / `DatabaseService` / 是否需在 `main.dart` 注册新表
- 时长单位：**视频 duration/position = 毫秒**；`StudyRecord.duration` = **秒**
- 保持 Riverpod：`fileProvider` 为文件域单一事实来源
- 小步提交；用户未要求不 git commit
