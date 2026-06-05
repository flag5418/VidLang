# VidLang 项目文档

> **AI / 协作者速查**：请先读 [`AGENT_CONTEXT.md`](./AGENT_CONTEXT.md)（实现进度、缺口、真实目录），再读本文件细节。

## 项目概述

VidLang 是一款面向全年龄段的英语学习应用，通过视频辅助用户学习英语。应用提供专业的学习工具，帮助用户轻松愉快地学习。

## 技术架构

### 核心技术栈

- **前端框架**: Flutter 3.x
- **状态管理**: Riverpod
- **本地数据库**: SQLite (sqflite)
- **视频播放**: Better Player
- **视频缩略图**: video_thumbnail
- **文件选择**: file_picker

### 项目结构

```
lib/
├── main.dart                    # 应用入口
├── models/                      # 数据模型
│   ├── base_entity.dart        # 实体基类
│   ├── video_info.dart         # 视频信息
│   ├── video_folder.dart       # 文件夹
│   ├── study_record.dart       # 学习记录
│   ├── subtitles.dart          # 字幕
│   └── participle.dart         # 分词
├── providers/                   # 状态管理
│   └── file_provider.dart      # 文件管理状态
├── services/                    # 服务层
│   ├── database_service.dart   # 数据库服务
│   ├── thumbnail_service.dart  # 缩略图服务
│   └── file_picker_service.dart # 文件选择服务
├── views/                       # 页面
│   └── files/                  # 文件管理模块
│       ├── file_list_page.dart # 首页
│       └── folder_detail_page.dart # 文件夹详情
└── components/                 # 组件
    ├── main_video_card.dart    # 主视频卡片
    └── video_card.dart        # 视频卡片
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
