# VidLang 文章阅读器 — 大纲侧边栏方案（v2 原型）

> 本文采用 ASCII 示意图展示大纲侧边栏方案的完整交互。
> 
> **状态：已确定为最终方案，已在 02-article-design.md 和 09-article-prototype.md 中完整记录。**
> 
> 本文作为补充，重点展示交互细节和手势操作。

---

## 一、核心交互原则

```
┌─────────────────────────────────────────────────────────────┐
│                                                              │
│  左：大纲侧边栏                 右：内容区                    │
│  ───────────────               ────────                     │
│  显示文章3层结构                Markdown 渲染                 │
│  当前章节自动展开               当前句高亮（白）              │
│  点击节点跳转                   划词查词                      │
│  每节点有播放/跟读按钮                                        │
│                                                              │
│  底：控制栏                                                   │
│  ─────────                                                    │
│  ◀◀ ◀ ▶ ▶▶ 短按=句 长按=章                                  │
│  速度/翻译/跟读/测试                                          │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 二、大纲侧边栏（左侧）

### 2.1 初始状态（默认）

```
┌──────────────────────┐
│  ☰ Climate Change    │ ← 文章标题（第1层）
│    and Its Impact    │
│                      │
│  ▶ 🌡️ Rising        │ ← 当前章节（高亮，展开句）
│     Temps            │
│     ○ S1 Climate     │
│     ● S2 This warm   │ ← 当前句（圆点）
│     ○ S3 Scientists  │
│     ○ S4 The rate    │
│     ○ S5 According   │
│                      │
│  ○ 📊 Key Statistics │ ← 其他章节（收起）
│                      │
│  ○ 🏭 Human Impact   │
│                      │
│  ○ 🌍 Solutions      │
│                      │
└──────────────────────┘
```

### 2.2 切换章节后的状态

```
┌──────────────────────┐
│  ☰ Climate Change    │
│                      │
│  ○ 🌡️ Rising        │ ← 原先的章节已收起
│     Temps            │
│                      │
│  ▶ 📊 Key            │ ← 新章节展开
│     Statistics       │
│     ○ S1 The data    │
│     ● S2 Scientists  │ ← 当前句
│     ○ S3 Arctic      │
│     ○ S4 CO2 levels  │
│                      │
│  ○ 🏭 Human Impact   │
│                      │
│  ○ 🌍 Solutions      │
│                      │
└──────────────────────┘
```

### 2.3 句子展开的视觉规则

```
每行句子在侧边栏中显示为：
[状态图标] [序号] [句子前几个单词...]

状态图标：
● = 正在播放的句子
○ = 未学习的句子
✓ = 已学完的句子

句子显示宽度：最多 20 个英文字符 + "..."
序号宽度：S1 ~ S999，固定 4 字符宽度
```

---

## 三、底部控制栏手势详解

### 3.1 长按手势

长按是此方案的核心创新——用户不需要打开大纲就能跳章节。

```
◀◀     ◀       ▶/⏸       ▶     ▶▶
Prev    Prev    Play/Pause Next   Next
Chap    Sent               Sent   Chap

长按 ◀ / ▶ 时的反馈流程：

1. 用户长按 ◀（约 300ms）
2. HapticFeedback.mediumImpact()（震动反馈）
3. 屏幕中间弹出提示："Jump to Chapter 2"
4. 内容区动画切换到上一章
5. 大纲侧边栏自动滚动到该章节
6. 该章节自动展开

同样：用户长按 ▶ → 跳转到下一章
```

### 3.2 所有按钮行为表

| 按钮 | 手势 | 行为 | 动画 | 反馈 |
|------|------|------|------|------|
| `◀◀` | 点击 | 上一章节 | 章节切换动画 | — |
| `◀` | 点击 | 上一句 | 句子滚动动画 | — |
| `◀` | 长按 | 上一章节 | 章节切换动画 | 震动+提示 |
| `▶/⏸` | 点击 | 播放/暂停 TTS | — | — |
| `▶` | 点击 | 下一句 | 句子滚动动画 | — |
| `▶` | 长按 | 下一章节 | 章节切换动画 | 震动+提示 |
| `▶▶` | 点击 | 下一章节 | 章节切换动画 | — |
| `x1.0` | 点击 | 弹出速度选择 | 浮层弹出 | — |
| `Tr` | 点击 | 翻译显隐切换 | 翻译淡入/出 | — |
| `Fol` | 点击 | 跟读面板展开 | 面板上滑 | — |
| `Quiz` | 点击 | 进入测试 | 页面跳转 | — |

---

## 四、同步滚动机制

### 4.1 三个方向的同步

```
播放位置变化
    ↓
内容区：滚动到当前句位置   ← ScrollController.animateTo()
大纲区：展开所属章节       ← setState() 更新展开状态
大纲区：滚动到当前句节点   ← OutlineScrollController.animateTo()
```

### 4.2 实现要点

```dart
// 当前句变化时，三方同步
void _onCurrentSentenceChanged(int sentenceIndex) {
  // 1. 内容区滚动到当前句
  _contentScrollController.animateTo(
    _getSentencePosition(sentenceIndex),
    duration: Duration(milliseconds: 300),
    curve: Curves.easeInOut,
  );

  // 2. 大纲区展开所属章节
  final chapterIndex = _sentences[sentenceIndex].chapterIndex;
  setState(() {
    _expandedChapterIndex = chapterIndex;
  });

  // 3. 大纲区滚动到当前句子节点
  _outlineScrollController?.animateTo(
    _getOutlinePosition(chapterIndex, sentenceIndex),
    duration: Duration(milliseconds: 300),
    curve: Curves.easeInOut,
  );
}
```

---

## 五、底部控制栏组件树

```dart
BottomControlBar
├── Row
│   ├── _ChapterButton(
│   │   icon: Icons.skip_previous,
│   │   direction: Backward,
│   │   level: Chapter,
│   │   onTap: _previousChapter,
│   │ )
│   │
│   ├── _SentenceButton(
│   │   icon: Icons.chevron_left,
│   │   direction: Backward,
│   │   level: Sentence,
│   │   onTap: _previousSentence,
│   │   onLongPress: _previousChapter,  // 长按=章节
│   │ )
│   │
│   ├── _PlayButton(
│   │   icon: isPlaying ? Icons.pause : Icons.play_arrow,
│   │   onTap: _togglePlayPause,
│   │ )
│   │
│   ├── _SentenceLabel(
│   │   text: 'Sentence 12/48',  // 显示当前位置
│   │ )
│   │
│   ├── _SentenceButton(
│   │   icon: Icons.chevron_right,
│   │   direction: Forward,
│   │   level: Sentence,
│   │   onTap: _nextSentence,
│   │   onLongPress: _nextChapter,
│   │ )
│   │
│   ├── _ChapterButton(
│   │   icon: Icons.skip_next,
│   │   direction: Forward,
│   │   level: Chapter,
│   │   onTap: _nextChapter,
│   │ )
│   │
│   └── Spacer
│       ├── _SpeedButton(x1.0)
│       ├── _TrButton
│       ├── _FolButton
│       └── _QuizButton
```

---

## 六、和视频播放器的对比

| 维度 | Video PlayerPage | Article ReaderPage |
|------|-----------------|-------------------|
| 顶部 | 视频画面 + 返回 | 大纲侧边栏 + 内容区 |
| 底部 | 进度条 + 控制栏 | 控制栏（无进度条，大纲替代） |
| 句子切换 | ◀ ▶ | ◀ ▶（短按） |
| 段落切换 | 无 | 长按 ◀ ▶ 跳章节 |
| 跟读 | DubPanel（复读配音） | FollowPanel（跟读） |
| 查词 | 未实现 | 划词 WordCard |
| 测试 | 未实现 | Quiz 按钮入测试 |
| 进度可视化 | 进度条 | 大纲侧边栏 |
| 翻译 | 字幕翻译 | Tr 按钮切换 |
| 速度 | x1.0 按钮 | x1.0 按钮 |

**核心一致性：底部控制栏的布局和交互逻辑完全一致，用户切换视频/文章零学习成本。**
