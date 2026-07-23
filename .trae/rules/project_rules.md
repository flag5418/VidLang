# VidLang Project Rules

> **入口**: AGENTS.md 是本项目 AI 协作规范的**单一事实来源**，本文件为 Trae 适配入口。

---

## 一、项目概述

Flutter 语言学习应用，三引擎架构（视频+文章+歌曲），本地 SQLite + Supabase 云服务。

## 二、技术栈

| 层级 | 技术 |
|------|------|
| 前端框架 | Flutter 3.x (SDK ^3.13.0) |
| 状态管理 | flutter_riverpod (StateNotifierProvider) |
| 本地数据库 | SQLite (sqflite) + FTS5 |
| UI 组件库 | tdesign_flutter |
| 屏幕适配 | flutter_screenutil（375×812） |
| 后端服务 | Supabase (PostgreSQL + Auth + Storage + Edge Functions) |
| AI 服务 | DeepSeek API |

## 三、核心规范摘要

### 目录结构
```
lib/
├── main.dart
├── models/           # 数据模型（继承 BaseEntity）
├── providers/        # 仅4个全局 Provider
├── services/         # 服务层
├── views/{module}/   # 模块自包含（page + logic + providers + widgets）
├── components/       # 全局 UI 组件（ui/ + dialogs/）
├── theme/            # 主题系统
└── utils/            # 工具类
```

### 命名规范
- 类/枚举: PascalCase
- 文件名/DB表/字段: snake_case
- 方法/变量: camelCase
- 常量: k + PascalCase

### 关键规则
- **所有数据模型继承 BaseEntity**（提供 `tableName`, `toMap()`, `fromMap()`）
- **所有颜色从 AppColors 获取，禁止硬编码**
- **视频相关时长为毫秒，学习记录时长为秒**
- **主页面超过 800 行必须拆分 logic 和 widgets/**

## 四、完整规则

请参阅项目根目录的 `AGENTS.md` 获取完整开发规范，包括：
- 文件存放决策树（文件应该放哪里）
- 组件规范（全局 vs 模块私有）
- 新增模块操作清单（11步）
- 自适应开发规范（flutter_screenutil 使用原则）
- 禁止事项

## 五、相关文档索引

| 文档 | 路径 |
|------|------|
| AI 协作规范（权威） | `AGENTS.md` |
| 架构总览 | `docs/architecture/overview-V1.1.md` |
| 数据库设计 | `docs/architecture/database-schema-V2.0.md` |
| 文档索引 | `docs/DOCUMENTATION_INDEX.md` |
| 知识库索引 | `docs/knowledge-base-index.yaml` |
