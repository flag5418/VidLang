# VidLang 详细设计 — 文件夹统一模型

## 一、文件夹作为核心管理单位

所有资源（视频/MTV/文章）都必须归属于一个文件夹。文件夹是用户组织、管理、测试的基本单元。

### 1.1 文件夹类型扩展

现有 VideoFolder 的 type 字段从 VideoFolderType（virtual/real）扩展为包含内容类型：

```dart
enum FolderType {
  video,    // 视频文件夹
  article,  // 文章文件夹
  music,    // 歌曲/MTV文件夹
}

// 原有 virtual/real 改为 storageType
enum StorageType {
  virtual,  // 原位置引用（不拷贝文件）
  managed,  // App 托管目录
}
```

### 1.2 模型设计（建议改名为 ResourceFolder）

```dart
class ResourceFolder extends BaseEntity {
  String name;
  FolderType folderType;        // video / article / music
  StorageType storageType;      // virtual / managed

  // 原有字段保留
  String? path;                 // 文件夹路径（virtual类型使用）
  String? parentCode;           // 父文件夹（支持层级）

  // 统计
  int resourceCount;            // 资源总数
  int completedCount;           // 已完成数
  String? cover;                // 封面

  // 最后学习
  String? lastResourceCode;     // 最后学习的资源 code
  DateTime? lastStudyDate;      // 最后学习时间
  int lastStudyDuration;        // 最后学习进度（毫秒）

  // 播放设置（视频/MTV适用）
  bool skipOpening;
  int skipOpeningDuration;
  bool skipEnding;
  int skipEndingDuration;

  // 排序
  int orderIndex;
}
```

### 1.3 文件夹层级

```
分组（parentCode = null）
├── 叶子文件夹 video（parentCode = 分组code）
│   ├── 视频 A
│   ├── 视频 B
│   └── ...
├── 叶子文件夹 article
│   ├── 文章 1
│   └── 文章 2
└── 叶子文件夹 music
    └── 歌曲 X
```

规则：
- **分组**：parentCode == null，纯容器
- **叶子文件夹**：parentCode != null，实际包含资源
- 资源始终挂在**叶子文件夹**下，一个叶子文件夹只包含同一类型资源

### 1.4 首页展示

| 类型 | 卡片 | 点击进入 |
|------|------|---------|
| video | 视频封面+进度条 | 视频列表页 |
| article | 文章封面+进度条 | 文章列表页 |
| music | 专辑封面+进度条 | 歌曲列表页 |
