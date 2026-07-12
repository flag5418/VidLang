# VidLang 项目文档

> **AI / 协作者速查**：请先读 [`AGENT_CONTEXT.md`](./AGENT_CONTEXT.md)（实现进度、缺口、真实目录），再读本文件细节。
>
> 📋 **完整文档索引**：请查看 [`DOCUMENTATION_INDEX.md`](./DOCUMENTATION_INDEX.md) 获取所有文档的导航。
>
> 📖 **项目全局规则**（⭐ 最高优先级）：请阅读 [`/项目全局规则.md`](../项目全局规则.md)，了解目录结构、命名规范、开发流程。
>
> 📚 **代码知识库**（⭐ 技术参考）：请查看 [`developer/design/code-knowledge-base/README.md`](./developer/design/code-knowledge-base/README.md) 获取结构化技术知识库。

---

## 项目概述

VidLang 是一款面向全年龄段的英语学习应用，通过视频辅助用户学习英语。应用提供专业的学习工具，帮助用户轻松愉快地学习。

**核心特点**：
- 🎬 通过**本地视频 + 字幕**学习英语（非简单播放器）
- 📚 支持**视频、文章、歌曲**三种学习媒介（三引擎架构）
- 🔍 字幕查词、跟读评分、测试、单词本等**完整学习闭环**
- ☁️ 本地 SQLite + Supabase 云端同步（离线优先）

---

## 快速导航

### 📋 必读文档（按顺序阅读）

| 序号 | 文档 | 用途 | 路径 |
|------|------|------|------|
| 1 | ⭐ **项目全局规则** | 最高规范，必须遵守 | `../项目全局规则.md` |
| 2 | ⭐ **AI 上下文速查** | AI/Cursor 快速恢复认知 | `AGENT_CONTEXT.md` |
| 3 | ⭐ **代码知识库** | 结构化技术参考 | `developer/design/code-knowledge-base/` |
| 4 | **开发规范** | 注释、命名、Git 规范 | `DEVELOPMENT.md` |
| 5 | **整体架构** | 产品定位、三引擎架构 | `overall-architecture.md` |
| 6 | **设计风格指南** | UI/UX 视觉规范 | `design-style-guide.md` |

### 🗂️ 文档分类

#### 💻 开发相关
- [`DEVELOPMENT.md`](./DEVELOPMENT.md) - 代码规范和最佳实践
- [`AGENT_CONTEXT.md`](./AGENT_CONTEXT.md) - AI 辅助开发上下文
- [`developer/design/code-knowledge-base/`](./developer/design/code-knowledge-base/) - 代码知识库（核心技术文档）

#### 🏗️ 架构与设计
- [`overall-architecture.md`](./overall-architecture.md) - 整体架构与产品设计
- [`design-style-guide.md`](./design-style-guide.md) - 设计风格指南
- [`designs/`](./designs/) - UI 设计稿（Pencil 格式）
- [`detailed-design/`](./detailed-design/) - 详细设计文档
- [`pages/`](./pages/) - 页面交互说明

#### 🤖 AI 相关
- [`ai-prompt-optimization-v2.md`](./ai-prompt-optimization-v2.md) - Prompt 优化
- [`ai-test-plan-v4-redesign.md`](./ai-test-plan-v4-redesign.md) - AI 测试计划
- [`AI 计费体系与 Edge Function 架构设计.md`](./AI 计费体系与 Edge Function 架构设计.md) - 后端架构

#### 📊 业务与运营
- [`strategic-guideline.md`](./strategic-guideline.md) - 战略指导方针
- [`market-analysis-priority.md`](./market-analysis-priority.md) - 市场分析
- [`用户与计费体系.md`](./用户与计费体系.md) - 付费模式设计
- [`支付与上架准备.md`](./支付与上架准备.md) - 上架清单

#### 🔧 技术实现
- [`word-cache-implementation.md`](./word-cache-implementation.md) - 单词缓存实现
- [`phase2-word-cache-extension.md`](./phase2-word-cache-extension.md) - Phase 2 规划
- [`video-playback-evaluation.md`](./video-playback-evaluation.md) - 播放器评估

---

## 技术架构（更新版）⚠️

> ⚠️ **注意**：以下技术栈为当前实际使用版本，旧文档可能有过时信息。以本节为准。

### 核心技术栈

| 领域 | 技术 | 版本要求 | 说明 |
|------|------|----------|------|
| **前端框架** | Flutter | ^3.13.0 beta | 跨平台 UI 框架 |
| **状态管理** | flutter_riverpod | latest | StateNotifierProvider 模式 |
| **本地数据库** | SQLite (sqflite) | latest | FTS5 全文检索 |
| **视频播放** | OmniPlayer（自研） | plugs/omni_player | iOS IJK + Android Texture |
| **音频播放** | just_audio | latest | 歌曲播放 / TTS |
| **UI 组件库** | tdesign_flutter | plugs/tdesign_flutter | 腾讯 TDesign Flutter 版 |
| **屏幕适配** | flutter_screenutil | latest | 设计稿 375×812 |
| **后端服务** | Supabase | latest | Auth + Storage + Edge Functions |
| **AI 服务** | DeepSeek API | via Edge Functions | 查词 / 翻译 / 对话 |

### 项目结构（详细版）

```
vidlang/
├── lib/                           ← Flutter 源代码
│   ├── main.dart                  # 应用入口（注册 DB 实体、主题、路由）
│   │
│   ├── models/                    ← 数据模型（BaseEntity 子类）
│   │   ├── base_entity.dart       # 实体基类（软删除、审计字段）
│   │   ├── video_folder.dart      # 视频集/文件夹
│   │   ├── video_info.dart        # 视频信息 + DurationHelper
│   │   ├── subtitles.dart         # 字幕行（FTS5 全文检索）
│   │   ├── participle.dart        # 分词（FTS5 全文检索）
│   │   ├── study_record.dart      # 学习记录（⚠️ 未注册）
│   │   ├── user.dart              # 用户模型
│   │   └── config.dart            # 系统配置（KV 模型）
│   │
│   ├── providers/                 ← 状态管理（Riverpod）
│   │   ├── file_provider.dart     # 文件域状态（⭐ 核心 Provider）
│   │   ├── navigation_provider.dart
│   │   └── user_provider.dart
│   │
│   ├── services/                  ← 服务层（业务逻辑）
│   │   ├── database_service.dart  # 数据库服务（⭐ 核心）
│   │   ├── file_picker_service.dart
│   │   ├── thumbnail_service.dart
│   │   ├── ai_service.dart        # AI 查询（DeepSeek）
│   │   └── ...
│   │
│   ├── views/                     ← 页面（按功能模块划分）
│   │   ├── main/main_page.dart    # 主页面（底部导航）
│   │   ├── files/                 # 文件管理模块
│   │   ├── home/home_page.dart    # 首页（Learn Tab）
│   │   ├── profile/profile_page.dart
│   │   └── test/                  # 测试模块
│   │
│   ├── components/                ← 公共 UI 组件（可复用）
│   │   ├── folder_card.dart
│   │   ├── video_card.dart
│   │   └── ...
│   │
│   ├── widgets/                   ← 业务组件（特定场景）
│   │   └── word_card.dart
│   │
│   └── theme/                     ← 主题系统
│       ├── app_theme.dart         # AppTheme 定义
│       ├── app_colors.dart        # 颜色常量
│       ├── app_icons.dart         # 统一图标
│       └── design_tokens.dart     # 设计令牌
│
├── plugs/                         ← 本地插件（自研/修改的第三方）
│   ├── omni_player/              # 视频播放内核
│   ├── tdesign_flutter/           # TDesign 组件库
│   └── tdesign_flutter_adaptation/
│
├── supabase/                      ← Supabase 后端
│   ├── functions/                 # Edge Functions
│   └── migrations/                # 数据库迁移脚本
│
├── docs/                          ← 项目文档
│   ├── AGENT_CONTEXT.md          # ⭐ AI 上下文速查
│   ├── DEVELOPMENT.md             # 开发规范
│   ├── overall-architecture.md    # 整体架构
│   ├── design-style-guide.md      # 设计风格指南
│   ├── DOCUMENTATION_INDEX.md     # 📋 文档索引（本文档）
│   └── developer/design/code-knowledge-base/  # 📚 代码知识库
│
└── 项目全局规则.md                # ⭐⭐ 最高优先级规范
```

## 数据模型

### VideoFolder（视频文件夹）

| 字段 | 类型 | 说明 |
|------|------|------|
| code | String | 唯一标识符 |
| name | String | 文件夹名称 |
| type | VideoFolderType | 文件夹类型（本地/虚拟） |
| videoCount | int | 视频总数 |
| completedCount | int | 已完成视频数 |
| cover | String? | 文件夹封面 |
| lastVideoCode | String? | 最后播放视频code |
| lastPlayDate | DateTime? | 最后播放时间 |
| lastPlayDuration | int | 最后播放进度（毫秒） |
| skipOpening | bool | 是否跳过片头 |
| skipOpeningDuration | int | 片头跳过时长（秒） |
| thumbnailTime | int | 封面截图时间（秒） |
| skipEnding | bool | 是否跳过片尾 |
| skipEndingDuration | int | 片尾跳过时长（秒） |

### VideoInfo（视频信息）

| 字段 | 类型 | 说明 |
|------|------|------|
| code | String | 唯一标识符 |
| name | String | 视频名称 |
| folderCode | String | 所属文件夹code |
| duration | int | 总时长（毫秒） |
| cover | String? | 视频封面 |
| currentCover | String? | 当前播放截图 |
| currentPosition | int | 当前播放位置（毫秒） |
| isCurrentPlaying | bool | 是否正在播放 |
| hasSubtitles | bool | 是否有字幕 |
| playDate | DateTime? | 最后播放时间 |
| playCount | int | 总播放次数 |
| totalPlayDuration | int | 总学习时长（秒） |

### StudyRecord（学习记录）

| 字段 | 类型 | 说明 |
|------|------|------|
| videoCode | String | 视频code |
| date | DateTime | 学习日期 |
| startTime | DateTime | 开始时间 |
| endTime | DateTime? | 结束时间 |
| duration | int | 学习时长（秒） |
| playCount | int | 完整播放次数 |

## 数据库设计

### 字段命名规范

- 使用下划线命名法（snake_case）
- 主键：`id`
- 业务主键：`code`
- 外键：`xxx_code`
- 时间字段：使用 ISO8601 格式存储
- 布尔字段：使用整数 0/1 存储
- 时长字段：统一使用毫秒（视频相关）或秒（学习记录）

### 软删除

所有实体继承自 BaseEntity，支持软删除：
- `is_deleted`: 是否删除（0/1）
- `deleted_at`: 删除时间
- `deleted_by`: 删除人

### 自动字段

- `created_at`: 创建时间
- `updated_at`: 更新时间
- `created_by`: 创建人
- `updated_by`: 更新人
- `user_code`: 用户标识（支持多用户）

## 播放参数配置

### 片头跳过

```dart
folder.skipOpening = true;           // 启用片头跳过
folder.skipOpeningDuration = 30;     // 跳过30秒
```

### 片尾跳过

```dart
folder.skipEnding = true;            // 启用片尾跳过
folder.skipEndingDuration = 10;     // 跳过最后10秒
```

### 封面截图

```dart
folder.thumbnailTime = 15;           // 在第15秒截图（默认）
```

## 开发规范

### 代码注释

- 所有公共类和公开方法需要添加文档注释
- 字段需要添加注释说明其用途
- 复杂逻辑需要添加行内注释

### 命名规范

- 类名：大驼峰（PascalCase）
- 方法名：小驼峰（camelCase）
- 变量名：小驼峰（camelCase）
- 常量：全大写下划线分隔（SNAKE_CASE）
- 文件名：小写下划线分隔（snake_case.dart）

### 时间格式

| 场景 | 格式 | 说明 |
|------|------|------|
| 数据库存储 | ISO8601 | `DateTime.toIso8601String()` |
| 用户显示 | MM:SS / HH:MM:SS | 使用 `DurationHelper` 转换 |
| API交互 | 毫秒 | 内部统一使用 |

### 状态管理

使用 Riverpod 进行状态管理：
- Provider: 全局单例状态
- StateNotifier: 复杂状态管理
- FutureProvider: 异步数据加载

## 后续开发计划

- [ ] Web文件管理器（WiFi传输）
- [ ] 视频播放页面集成
- [ ] 字幕导入和管理
- [ ] 分词和全文检索
- [ ] 学习报告统计
- [ ] 测试功能集成

## 版本历史

### v0.1.0 (开发中)

- 实现文件夹和视频管理基础功能
- SQLite 数据库集成
- 视频缩略图生成
- 本地视频导入
