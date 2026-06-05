# VidLang 详细设计文档索引

## 文档列表

| # | 文件 | 内容 |
|---|------|------|
| 01 | [01-folder-model.md](./01-folder-model.md) | 文件夹统一模型设计 |
| 02 | [02-article-design.md](./02-article-design.md) | 文章学习（Markdown/章节/多模式跟读） |
| 03 | [03-music-design.md](./03-music-design.md) | 歌曲/MTV 学习（务实的"不分离人声"方案） |
| 04 | [04-follow-scoring.md](./04-follow-scoring.md) | 统一跟读框架 + 录音 + 评分体系 |
| 05 | [05-wordbook.md](./05-wordbook.md) | 跨来源统一单词本 + 间隔复习 |
| 06 | [06-test-system.md](./06-test-system.md) | 双层测试体系（单资源 + 文件夹综合） |
| 07 | [07-homepage-nav.md](./07-homepage-nav.md) | 首页与导航设计（Learn/Words/Profile） |
| 08 | [08-business-model.md](./08-business-model.md) | 商业模式（Freemium + AI 计费）+ 数据同步 |

## 核心设计决策速查

### 文件夹统一模型

```
所有资源（视频/文章/歌曲）必须属于一个文件夹
ResourceFolder.folderType = video | article | music
文件夹支持层级（分组 + 叶子文件夹）
```

### MTV 学习的务实方案

```
MTV 学习 ≠ 卡拉OK（不分离人声）
MTV 学习 = 带歌词时间轴的视频学习
跟唱评分使用 英文发音评分（不是音乐评分）
同一 PlayerPage 切换 字幕模式 ↔ 歌词模式
```

### 文章 Markdown 存储

```
文章全文以 Markdown 格式存储
三种阅读模式：全文 / 章节 / 单句（和视频播放 UX 一致）
三种跟读粒度：全文 / 章节 / 单句
```

### 双层测试体系

```
单资源测试：基于当前视频/文章/歌曲的片段出题
文件夹综合测试：从文件夹内所有资源的随机片段出题
统一测试引擎：填空 / 听写 / 选择
```

### 免费+付费

```
免费：iOS原生能力（OCR/TTS/翻译）+ 本地录音+本地测试
付费：DeepSeek AI + 声通评分 + 云同步
订阅制 / AI Credits 按量计费
```
