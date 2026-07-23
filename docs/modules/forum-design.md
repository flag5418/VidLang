# VidLang 论坛功能设计

> **版本**: V2.0 | **日期**: 2026-07-23
> **状态**: 📋 设计确认，待实施
> **适用范围**: Flutter 客户端 + Supabase Edge Functions + Storage
>
> **V2.0 重大变更（相比 V1.1）**：
> - **移除板块概念**：论坛不再分板块，改为纯标签体系组织帖子
> - **标签一对一**：每个帖子只绑定一个标签，标签由管理员在后台统一管理
> - **单层回复**：去掉嵌套回复（parent_id），所有回复平级展示
> - **新增「我的」页面**：我的关注、我的收藏、反馈入口
> - **新增收藏/关注**：用户可收藏帖子、关注用户、关注标签
> - **今日头条式标签栏**：首页顶部标签 Tab，含「关注」Tab 用于只看关注标签的帖子

---

### 版本更新记录

| 版本 | 日期 | 更新人 | 更新摘要 |
|------|------|--------|---------|
| V2.0 | 2026-07-23 | AI 协作 | 移除板块，标签一对一，单层回复，新增收藏/关注/标签关注/我的页面/反馈，今日头条式标签栏 |
| V1.1 | 2026-07-22 | AI 协作 | 补充自定义域名与 Cloudflare 代理方案、扩展 ICP/iOS 审核细节 |
| V1.0 | 2026-07-22 | — | 初始版本，论坛功能完整设计 |

---

## 一、论坛定位与核心原则

### 1.1 定位

VidLang 论坛是一个面向英语学习社群的**轻量级交流社区**。不做重型功能（无板块、无嵌套回复、无富文本编辑器），通过标签体系组织内容，保持交互简洁。

### 1.2 核心原则

| 原则 | 说明 |
|------|------|
| **标签驱动** | 帖子通过标签归类，用户关注感兴趣的标签来定制信息流 |
| **轻量克制** | 仅支持文本 + 图片，单层回复，不做复杂社交功能 |
| **审核后置** | 用户发帖/回复即时可见，违规内容通过举报机制后置处理 |
| **隐私优先** | 不暴露用户邮箱/手机号，仅展示昵称和头像 |
| **合规内置** | 举报、封禁、内容删除等管理能力内建于 Edge Function |

---

## 二、信息架构

### 2.1 标签体系（替代 V1.1 板块概念）

论坛不设板块，通过标签组织帖子。标签由管理员在后台统一管理（增删改），存 Supabase `forum_tags` 表。每个帖子发布时必选一个标签。

```
论坛首页
├── 顶部标签 Tab 栏（今日头条风格）
│   ├── 关注   （只看我关注的标签下的帖子）
│   ├── 标签A
│   ├── 标签B
│   ├── 标签C
│   └── ...    （管理员可动态增减）
├── 帖子列表（按发布时间倒序）
│   └── 帖子卡片：标题、作者头像+昵称、发布时间、标签、点赞数、回复数
└── 发帖按钮（入口）
```

### 2.2 导航入口

```
App 底部 Tab → 社区 → 论坛首页
我的 → 我的关注 / 我的收藏 / 反馈
论坛首页 → 发帖按钮 → 发帖页面
帖子卡片 → 帖子详情页（正文 + 回复列表 + 点赞/收藏/关注）
```

---

## 三、核心功能清单

### 3.1 用户端功能

#### 3.1.1 论坛首页（标签 Tab 栏）

| 功能 | 说明 |
|------|------|
| 标签 Tab | 顶部横向滚动 Tab 栏，首个 Tab 为「关注」，后续为全部标签 |
| 关注 Tab | 仅展示用户关注的标签下的帖子；若未关注任何标签，提示引导关注 |
| 全部 Tab | 默认展示全部帖子，按发布时间倒序 |
| 帖子卡片 | 标题（截取前 80 字）、作者头像+昵称、发布时间、标签名、点赞数、回复数 |
| 分页加载 | 每页 20 条 |
| 搜索 | 按关键词搜索帖子标题和内容 |

#### 3.1.2 发帖

| 功能 | 说明 |
|------|------|
| 标题 | 必填，2-80 字 |
| 正文 | 必填，纯文本，1-5000 字 |
| 图片 | 可选，最多 9 张，从相册选择或拍照 |
| 标签 | 必选，从现有标签中单选一个 |
| 发布后 | 立即出现在对应标签的信息流中 |

#### 3.1.3 帖子详情

| 功能 | 说明 |
|------|------|
| 帖子正文 | 纯文本 + 配图（网格/轮播），图片点击放大 |
| 标签展示 | 显示帖子所属标签 |
| 底部操作栏 | **点赞**（toggle）、**收藏**（toggle）、**关注作者**（toggle）、评论入口 |
| 回复列表 | 单层结构，按发布时间正序排列，分页加载 |

#### 3.1.4 回复

| 功能 | 说明 |
|------|------|
| 结构 | **单层**，不支持回复回复（无嵌套） |
| 内容 | 纯文本，1-500 字 |
| 排序 | 按发布时间正序 |
| 点赞 | 支持点赞回复 |

#### 3.1.5 点赞

| 功能 | 说明 |
|------|------|
| 范围 | 帖子 + 回复 |
| 规则 | 同一用户对同一对象只能点赞一次，再次点击取消 |
| 计数 | 实时更新 |

#### 3.1.6 收藏帖子

| 功能 | 说明 |
|------|------|
| 入口 | 帖子详情页底部操作栏 |
| 规则 | 收藏/取消收藏 toggle |
| 查看 | 「我的」→ 我的收藏，支持取消收藏 |

#### 3.1.7 关注用户

| 功能 | 说明 |
|------|------|
| 入口 | 帖子详情页 / 帖子卡片作者头像旁 |
| 规则 | 关注/取消关注 toggle，不能关注自己 |
| 查看 | 「我的」→ 我的关注，支持取消关注 |

#### 3.1.8 关注标签

| 功能 | 说明 |
|------|------|
| 入口 | 标签 Tab 栏长按或标签旁关注按钮 |
| 效果 | 关注后，首页「关注」Tab 中展示该标签下的帖子 |
| 管理 | 「我的」→ 关注标签管理（可选）或直接在标签栏操作 |

#### 3.1.9 举报

| 功能 | 说明 |
|------|------|
| 范围 | 帖子 + 回复 |
| 原因 | 色情低俗 / 垃圾广告 / 辱骂攻击 / 其他 |
| 处理 | 提交后进入管理后台待处理队列 |

### 3.2 「我的」页面

| 模块 | 说明 |
|------|------|
| **我的关注** | 关注的用户列表，可取消关注 |
| **我的收藏** | 收藏的帖子列表，可取消收藏 |
| **反馈** | 提交 bug/建议，查看历史反馈及管理员回复状态 |
| 我的帖子 | 我发布的帖子列表 |
| 我的回复 | 我发布的回复列表 |

### 3.3 反馈模块

| 字段 | 说明 |
|------|------|
| 类型 | bug / 建议 / 其他 |
| 内容 | 必填，纯文本 |
| 截图 | 可选，最多 3 张 |
| 状态 | 待处理 / 处理中 / 已回复 / 已关闭 |
| 管理员回复 | 管理员在后台回复，用户收到通知 |

### 3.4 通知模块

统一收口，类型如下：

| 通知类型 | 触发条件 |
|---------|---------|
| 回复通知 | 有人回复了我的帖子 |
| 点赞通知 | 有人点赞了我的帖子或回复 |
| 收藏通知 | 有人收藏了我的帖子 |
| 关注通知 | 有人关注了我 |
| 帖子被下架 | 管理员下架我的帖子 |
| 被禁言 | 管理员禁言我 |
| 反馈被回复 | 管理员回复了我的反馈 |
| 系统通知 | 版本更新、维护公告等 |

### 3.5 管理后台功能

| 功能 | 说明 |
|------|------|
| 仪表盘 | 今日帖子数/回复数/举报数、活跃用户数 |
| 帖子管理 | 帖子列表、下架/恢复、置顶/取消置顶 |
| 标签管理 | 标签增删改（论坛标签体系） |
| 举报处理 | 举报列表、下架内容或忽略 |
| 用户管理 | 用户列表、禁言/解封、设置角色 |
| 反馈管理 | 反馈列表、状态变更、管理员回复 |

---

## 四、数据库表设计

### 4.1 表清单

| 表名 | 说明 |
|------|------|
| `forum_tags` | 标签定义（管理员管理） |
| `forum_posts` | 帖子主表 |
| `forum_replies` | 回复表（单层，无 parent_id） |
| `forum_likes` | 点赞记录 |
| `forum_favorites` | 收藏记录 |
| `forum_follows` | 关注用户记录 |
| `forum_user_tag_follows` | 用户关注标签记录 |
| `forum_reports` | 举报记录 |
| `forum_notifications` | 通知记录 |
| `forum_feedback` | 用户反馈 |
| `user_roles` | 用户角色表 |
| `user_bans` | 封禁记录 |

> **相比 V1.1 变更**：删除 `forum_boards`、`forum_post_tags`；`forum_posts` 用 `tag_id` 替代 `board_id`；`forum_replies` 去掉 `parent_id`；新增 `forum_favorites`、`forum_follows`、`forum_user_tag_follows`。

### 4.2 DDL

```sql
-- 标签定义（管理员管理）
CREATE TABLE forum_tags (
    id          SERIAL PRIMARY KEY,
    name        TEXT NOT NULL UNIQUE,
    color       TEXT DEFAULT '#6366F1',
    sort_order  INT DEFAULT 0,
    is_active   BOOLEAN DEFAULT TRUE,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 帖子主表
CREATE TABLE forum_posts (
    id              BIGSERIAL PRIMARY KEY,
    tag_id          INT NOT NULL REFERENCES forum_tags(id),
    author_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title           TEXT NOT NULL,
    content         TEXT NOT NULL,
    image_urls      JSONB DEFAULT '[]'::jsonb,
    view_count      INT DEFAULT 0,
    reply_count     INT DEFAULT 0,
    like_count      INT DEFAULT 0,
    favorite_count  INT DEFAULT 0,
    is_pinned       BOOLEAN DEFAULT FALSE,
    is_deleted      BOOLEAN DEFAULT FALSE,
    deleted_reason  TEXT DEFAULT NULL,
    deleted_by      UUID DEFAULT NULL REFERENCES auth.users(id),
    deleted_at      TIMESTAMPTZ DEFAULT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_forum_posts_tag_id ON forum_posts(tag_id, is_deleted, is_pinned DESC, created_at DESC);
CREATE INDEX idx_forum_posts_author_id ON forum_posts(author_id, is_deleted, created_at DESC);
CREATE INDEX idx_forum_posts_search ON forum_posts USING GIN (to_tsvector('simple', title || ' ' || content));

-- 回复表（单层）
CREATE TABLE forum_replies (
    id              BIGSERIAL PRIMARY KEY,
    post_id         BIGINT NOT NULL REFERENCES forum_posts(id) ON DELETE CASCADE,
    author_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content         TEXT NOT NULL,
    like_count      INT DEFAULT 0,
    is_deleted      BOOLEAN DEFAULT FALSE,
    deleted_reason  TEXT DEFAULT NULL,
    deleted_by      UUID DEFAULT NULL REFERENCES auth.users(id),
    deleted_at      TIMESTAMPTZ DEFAULT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_forum_replies_post_id ON forum_replies(post_id, is_deleted, created_at);
CREATE INDEX idx_forum_replies_author_id ON forum_replies(author_id, is_deleted, created_at DESC);

-- 点赞记录
CREATE TABLE forum_likes (
    id          BIGSERIAL PRIMARY KEY,
    user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    target_type TEXT NOT NULL CHECK (target_type IN ('post', 'reply')),
    target_id   BIGINT NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (user_id, target_type, target_id)
);

CREATE INDEX idx_forum_likes_target ON forum_likes(target_type, target_id);

-- 收藏记录
CREATE TABLE forum_favorites (
    id        BIGSERIAL PRIMARY KEY,
    user_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    post_id   BIGINT NOT NULL REFERENCES forum_posts(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (user_id, post_id)
);

CREATE INDEX idx_forum_favorites_user_id ON forum_favorites(user_id, created_at DESC);

-- 关注用户记录
CREATE TABLE forum_follows (
    id            BIGSERIAL PRIMARY KEY,
    follower_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    following_id  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at    TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (follower_id, following_id),
    CHECK (follower_id <> following_id)
);

CREATE INDEX idx_forum_follows_follower ON forum_follows(follower_id);
CREATE INDEX idx_forum_follows_following ON forum_follows(following_id);

-- 用户关注标签记录
CREATE TABLE forum_user_tag_follows (
    id        BIGSERIAL PRIMARY KEY,
    user_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    tag_id    INT NOT NULL REFERENCES forum_tags(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (user_id, tag_id)
);

CREATE INDEX idx_forum_user_tag_follows_user ON forum_user_tag_follows(user_id);

-- 举报记录
CREATE TABLE forum_reports (
    id              BIGSERIAL PRIMARY KEY,
    reporter_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    target_type     TEXT NOT NULL CHECK (target_type IN ('post', 'reply')),
    target_id       BIGINT NOT NULL,
    reason          TEXT NOT NULL CHECK (reason IN ('spam', 'harassment', 'inappropriate', 'other')),
    detail          TEXT DEFAULT '',
    status          TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'resolved', 'dismissed')),
    handled_by      UUID DEFAULT NULL REFERENCES auth.users(id),
    handled_at      TIMESTAMPTZ DEFAULT NULL,
    handle_note     TEXT DEFAULT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (reporter_id, target_type, target_id)
);

CREATE INDEX idx_forum_reports_status ON forum_reports(status, created_at DESC);

-- 通知记录
CREATE TABLE forum_notifications (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type            TEXT NOT NULL CHECK (type IN (
                        'reply', 'like', 'favorite', 'follow',
                        'post_removed', 'user_muted', 'feedback_replied', 'system'
                    )),
    title           TEXT NOT NULL,
    body            TEXT NOT NULL,
    metadata        JSONB DEFAULT '{}'::jsonb,
    is_read         BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_forum_notifications_user ON forum_notifications(user_id, is_read, created_at DESC);

-- 用户反馈
CREATE TABLE forum_feedback (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type            TEXT NOT NULL CHECK (type IN ('bug', 'feature', 'other')),
    title           TEXT NOT NULL,
    content         TEXT NOT NULL,
    image_urls      JSONB DEFAULT '[]'::jsonb,
    status          TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'replied', 'closed')),
    admin_reply     TEXT DEFAULT NULL,
    replied_by      UUID DEFAULT NULL REFERENCES auth.users(id),
    replied_at      TIMESTAMPTZ DEFAULT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_forum_feedback_user ON forum_feedback(user_id, created_at DESC);
CREATE INDEX idx_forum_feedback_status ON forum_feedback(status, created_at DESC);

-- 用户角色
CREATE TABLE user_roles (
    id          SERIAL PRIMARY KEY,
    user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
    role        TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'moderator', 'admin')),
    granted_by  UUID DEFAULT NULL REFERENCES auth.users(id),
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_user_roles_role ON user_roles(role);

-- 封禁记录
CREATE TABLE user_bans (
    id          SERIAL PRIMARY KEY,
    user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reason      TEXT NOT NULL,
    banned_by   UUID NOT NULL REFERENCES auth.users(id),
    banned_at   TIMESTAMPTZ DEFAULT NOW(),
    expires_at  TIMESTAMPTZ DEFAULT NULL,
    is_active   BOOLEAN DEFAULT TRUE
);

CREATE INDEX idx_user_bans_active ON user_bans(user_id, is_active);
```

### 4.3 RLS 策略

```sql
ALTER TABLE forum_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_replies ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_user_tag_follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_bans ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_tags ENABLE ROW LEVEL SECURITY;

-- forum_posts
CREATE POLICY "Posts are viewable by everyone"
    ON forum_posts FOR SELECT
    USING (is_deleted = FALSE);

CREATE POLICY "Posts can be created by authenticated users"
    ON forum_posts FOR INSERT
    WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Posts can be updated by author or admin"
    ON forum_posts FOR UPDATE
    USING (auth.uid() = author_id OR EXISTS (
        SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND role IN ('moderator', 'admin')
    ));

-- forum_replies
CREATE POLICY "Replies are viewable by everyone"
    ON forum_replies FOR SELECT
    USING (is_deleted = FALSE);

CREATE POLICY "Replies can be created by authenticated users"
    ON forum_replies FOR INSERT
    WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Replies can be updated by author or admin"
    ON forum_replies FOR UPDATE
    USING (auth.uid() = author_id OR EXISTS (
        SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND role IN ('moderator', 'admin')
    ));

-- forum_likes
CREATE POLICY "Likes are viewable by everyone"
    ON forum_likes FOR SELECT USING (TRUE);

CREATE POLICY "Users can manage own likes"
    ON forum_likes FOR ALL USING (auth.uid() = user_id);

-- forum_favorites
CREATE POLICY "Favorites viewable by owner"
    ON forum_favorites FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own favorites"
    ON forum_favorites FOR ALL USING (auth.uid() = user_id);

-- forum_follows
CREATE POLICY "Follows are viewable by everyone"
    ON forum_follows FOR SELECT USING (TRUE);

CREATE POLICY "Users can manage own follows"
    ON forum_follows FOR ALL USING (auth.uid() = follower_id);

-- forum_user_tag_follows
CREATE POLICY "Tag follows viewable by owner"
    ON forum_user_tag_follows FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own tag follows"
    ON forum_user_tag_follows FOR ALL USING (auth.uid() = user_id);

-- forum_tags
CREATE POLICY "Tags are viewable by everyone"
    ON forum_tags FOR SELECT USING (is_active = TRUE);

CREATE POLICY "Admins can manage tags"
    ON forum_tags FOR ALL USING (EXISTS (
        SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND role IN ('moderator', 'admin')
    ));

-- forum_reports
CREATE POLICY "Reports viewable by reporter and admin"
    ON forum_reports FOR SELECT
    USING (auth.uid() = reporter_id OR EXISTS (
        SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND role IN ('moderator', 'admin')
    ));

CREATE POLICY "Reports can be created by authenticated users"
    ON forum_reports FOR INSERT
    WITH CHECK (auth.uid() = reporter_id);

-- forum_notifications
CREATE POLICY "Notifications viewable by owner"
    ON forum_notifications FOR ALL
    USING (auth.uid() = user_id);

-- forum_feedback
CREATE POLICY "Feedback viewable by owner and admin"
    ON forum_feedback FOR SELECT
    USING (auth.uid() = user_id OR EXISTS (
        SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND role IN ('moderator', 'admin')
    ));

CREATE POLICY "Feedback can be created by authenticated users"
    ON forum_feedback FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can update feedback"
    ON forum_feedback FOR UPDATE
    USING (EXISTS (
        SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND role IN ('moderator', 'admin')
    ));

-- user_roles
CREATE POLICY "Roles viewable by everyone"
    ON user_roles FOR SELECT USING (TRUE);

-- user_bans
CREATE POLICY "Bans viewable by everyone"
    ON user_bans FOR SELECT USING (TRUE);
```

### 4.4 触发器：自动更新计数器

```sql
-- 帖子回复数自动更新
CREATE OR REPLACE FUNCTION update_post_reply_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' AND NEW.is_deleted = FALSE THEN
        UPDATE forum_posts SET reply_count = reply_count + 1, updated_at = NOW()
        WHERE id = NEW.post_id;
    ELSIF TG_OP = 'UPDATE' AND OLD.is_deleted = FALSE AND NEW.is_deleted = TRUE THEN
        UPDATE forum_posts SET reply_count = GREATEST(reply_count - 1, 0)
        WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' AND OLD.is_deleted = FALSE THEN
        UPDATE forum_posts SET reply_count = GREATEST(reply_count - 1, 0)
        WHERE id = OLD.post_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_post_reply_count
    AFTER INSERT OR UPDATE OR DELETE ON forum_replies
    FOR EACH ROW EXECUTE FUNCTION update_post_reply_count();

-- 点赞数自动更新
CREATE OR REPLACE FUNCTION update_like_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.target_type = 'post' THEN
            UPDATE forum_posts SET like_count = like_count + 1 WHERE id = NEW.target_id;
        ELSE
            UPDATE forum_replies SET like_count = like_count + 1 WHERE id = NEW.target_id;
        END IF;
    ELSIF TG_OP = 'DELETE' THEN
        IF OLD.target_type = 'post' THEN
            UPDATE forum_posts SET like_count = GREATEST(like_count - 1, 0) WHERE id = OLD.target_id;
        ELSE
            UPDATE forum_replies SET like_count = GREATEST(like_count - 1, 0) WHERE id = OLD.target_id;
        END IF;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_like_count
    AFTER INSERT OR DELETE ON forum_likes
    FOR EACH ROW EXECUTE FUNCTION update_like_count();

-- 收藏数自动更新
CREATE OR REPLACE FUNCTION update_favorite_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE forum_posts SET favorite_count = favorite_count + 1 WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE forum_posts SET favorite_count = GREATEST(favorite_count - 1, 0) WHERE id = OLD.post_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_favorite_count
    AFTER INSERT OR DELETE ON forum_favorites
    FOR EACH ROW EXECUTE FUNCTION update_favorite_count();
```

---

## 五、接口设计（Edge Functions）

### 5.1 函数总览

共 **18 个 Edge Function**（相比 V1.1 减少 4 个：移除 `forum-board-stats`、`forum-admin-boards`，合并帖子 CRUD，新增 `forum-favorites`、`forum-follows`、`forum-tag-follows`）。

| # | 函数名 | 职责 | 类别 |
|---|--------|------|------|
| 1 | `forum-posts` | 帖子 CRUD + 列表查询（标签筛选/关注标签筛选） | 用户端 |
| 2 | `forum-replies` | 回复 CRUD + 列表查询 | 用户端 |
| 3 | `forum-likes` | 点赞/取消点赞 | 用户端 |
| 4 | `forum-favorites` | 收藏/取消收藏 + 我的收藏列表 | 用户端 |
| 5 | `forum-follows` | 关注/取消关注用户 + 关注列表 | 用户端 |
| 6 | `forum-tag-follows` | 关注/取消关注标签 + 关注标签列表 | 用户端 |
| 7 | `forum-reports` | 创建举报 | 用户端 |
| 8 | `forum-notifications` | 通知列表 + 已读标记 | 用户端 |
| 9 | `forum-search` | 全文搜索帖子 | 用户端 |
| 10 | `forum-upload` | 图片上传到 Storage | 用户端 |
| 11 | `forum-feedback` | 用户反馈提交 + 我的反馈列表 | 用户端 |
| 12 | `forum-tags` | 标签列表 | 用户端 |
| 13 | `forum-admin-posts` | 管理后台：帖子管理 | 管理后台 |
| 14 | `forum-admin-tags` | 管理后台：标签管理（增删改） | 管理后台 |
| 15 | `forum-admin-reports` | 管理后台：举报处理 | 管理后台 |
| 16 | `forum-admin-users` | 管理后台：用户管理 + 封禁 | 管理后台 |
| 17 | `forum-admin-feedback` | 管理后台：反馈管理 | 管理后台 |
| 18 | `forum-admin` | 管理后台 HTML 页面渲染 + 仪表盘统计 | 页面渲染 |

### 5.2 用户端接口详情

#### 5.2.1 `forum-posts`

| 方法 | 路径 | 说明 | 鉴权 |
|------|------|------|------|
| GET | `/forum-posts?tag_id=1&page=1&limit=20` | 按标签获取帖子列表 | 否 |
| GET | `/forum-posts?followed=1&page=1&limit=20` | 获取关注标签的帖子 | 是 |
| POST | `/forum-posts` | 创建帖子 | 是 |
| PUT | `/forum-posts/:id` | 编辑帖子（仅作者） | 是 |
| DELETE | `/forum-posts/:id` | 软删除帖子 | 是 |

请求体（POST）：
```json
{
    "tag_id": 1,
    "title": "如何提高听力水平？",
    "content": "最近在练习听力...",
    "image_urls": ["https://xxx/storage/v1/object/public/forum-images/xxx.jpg"]
}
```

#### 5.2.2 `forum-replies`

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/forum-replies?post_id=123&page=1&limit=20` | 回复列表 |
| POST | `/forum-replies` | 创建回复 |
| DELETE | `/forum-replies/:id` | 软删除回复 |

#### 5.2.3 `forum-likes`

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/forum-likes` | 点赞/取消（toggle） |

#### 5.2.4 `forum-favorites`

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/forum-favorites` | 收藏/取消（toggle） |
| GET | `/forum-favorites/my?page=1` | 我的收藏列表 |

#### 5.2.5 `forum-follows`

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/forum-follows` | 关注/取消关注（toggle） |
| GET | `/forum-follows/my` | 我的关注列表 |

#### 5.2.6 `forum-tag-follows`

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/forum-tag-follows` | 关注/取消关注标签（toggle） |
| GET | `/forum-tag-follows/my` | 我关注的标签列表 |

#### 5.2.7 `forum-reports`

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/forum-reports` | 创建举报 |

#### 5.2.8 `forum-notifications`

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/forum-notifications?page=1&limit=20` | 通知列表 |
| GET | `/forum-notifications/unread-count` | 未读通知数 |
| PUT | `/forum-notifications/read-all` | 全部标记已读 |
| PUT | `/forum-notifications/:id/read` | 单条标记已读 |

#### 5.2.9 `forum-search`

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/forum-search?q=听力&page=1` | 全文搜索 |

#### 5.2.10 `forum-upload`

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/forum-upload` | 上传图片（multipart/form-data） |

限制：单张最大 5MB，仅允许 jpg/png/webp/heic/heif，返回公开 URL。

#### 5.2.11 `forum-feedback`

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/forum-feedback` | 提交反馈 |
| GET | `/forum-feedback/my?page=1` | 我的反馈列表 |

#### 5.2.12 `forum-tags`

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/forum-tags` | 全部活跃标签列表 |

### 5.3 管理后台接口详情

#### 5.3.1 `forum-admin`

一个 Edge Function 根据 URL path 路由到不同管理页面，返回完整 HTML。

| URL Path | 说明 |
|----------|------|
| `/forum-admin/login` | 登录页 |
| `/forum-admin/dashboard` | 仪表盘（今日帖数/回复数/举报数/活跃用户） |
| `/forum-admin/posts` | 帖子管理（列表、下架/恢复、置顶/取消置顶） |
| `/forum-admin/tags` | 标签管理（增删改） |
| `/forum-admin/reports` | 举报处理 |
| `/forum-admin/users` | 用户管理（列表、禁言/解封、设置角色） |
| `/forum-admin/feedback` | 反馈管理（状态变更、回复） |
| `/forum-admin/logout` | 登出 |

#### 5.3.2 管理后台 API

| 函数 | 核心功能 |
|------|---------|
| `forum-admin-posts` | GET — 帖子列表；PUT — 编辑（置顶/下架）；DELETE — 软删除 |
| `forum-admin-tags` | GET — 标签列表；POST — 创建标签；PUT — 编辑；DELETE — 删除 |
| `forum-admin-reports` | GET — 举报列表；PUT — 处理举报 |
| `forum-admin-users` | GET — 用户列表；POST /ban — 封禁；DELETE /ban — 解封；PUT /role — 设角色 |
| `forum-admin-feedback` | GET — 反馈列表；PUT — 回复 + 状态变更 |

---

## 六、文件存储策略

### 6.1 Supabase Storage 桶

| 桶名称 | 用途 | 公开访问 | 文件类型 | 大小限制 |
|--------|------|---------|---------|---------|
| `forum-images` | 帖子配图 | 是 | jpg, png, webp, heic, heif | 单张 5MB |

### 6.2 上传流程

```
App → forum-upload Edge Function
    1. 验证 JWT
    2. 校验文件类型（MIME + 扩展名）
    3. 校验文件大小（≤ 5MB）
    4. 生成唯一文件名：{user_id}/{uuid}.{ext}
    5. 上传到 forum-images 桶
    6. 返回公开 URL
```

---

## 七、部署架构

三层部署，全部在 Supabase 生态内：

```
Cloudflare DNS (自定义域名 forum.vidlang.com)
    │
    ▼
Supabase 项目
├── PostgreSQL（数据库 + RLS）
├── Edge Functions（18 个，含管理后台 HTML 渲染）
└── Storage（forum-images 桶）
```

自定义域名方案详见 §7.3–§7.4（与 V1.1 一致，不再赘述）。

### 7.1 URL 示例

```
业务接口：
  https://forum.vidlang.com/functions/v1/forum-posts
  https://forum.vidlang.com/functions/v1/forum-replies?post_id=123

管理后台：
  https://forum.vidlang.com/functions/v1/forum-admin/login
  https://forum.vidlang.com/functions/v1/forum-admin/dashboard

存储：
  https://forum.vidlang.com/storage/v1/object/public/forum-images/xxx.jpg
```

---

## 八、合规要点

### 8.1 隐私政策 & 用户协议

（与 V1.1 一致，静态页面托管于 Storage `forum-pages` 桶）

### 8.2 内容审核策略

| 层级 | 机制 | 说明 |
|------|------|------|
| 预防 | 封禁检查 | 发帖/回复前检查 `user_bans` |
| 检测 | 用户举报 | 任何用户可举报帖子或回复 |
| 响应 | 管理后台处理 | 管理员审核 → 删除/驳回 |
| 惩戒 | 禁言 | 1天/3天/7天/30天/永久 |

---

## 九、通知触发逻辑

| 操作 | 通知接收者 | 通知类型 |
|------|-----------|---------|
| 回复帖子 | 帖子作者 | `reply` |
| 点赞帖子/回复 | 帖子/回复作者 | `like` |
| 收藏帖子 | 帖子作者 | `favorite` |
| 关注用户 | 被关注者 | `follow` |
| 管理员下架帖子 | 帖子作者 | `post_removed` |
| 管理员禁言 | 被禁言用户 | `user_muted` |
| 管理员回复反馈 | 反馈提交者 | `feedback_replied` |

---

## 十、迭代路线

### P0（核心可用）

- [ ] 数据库建表 + RLS + 触发器（12 张表）
- [ ] `forum-posts`：帖子 CRUD + 标签筛选 + 关注标签筛选
- [ ] `forum-replies`：单层回复 CRUD
- [ ] `forum-likes`：点赞/取消
- [ ] `forum-favorites`：收藏/取消 + 我的收藏
- [ ] `forum-follows`：关注/取消用户 + 我的关注
- [ ] `forum-tag-follows`：关注/取消标签
- [ ] `forum-tags`：标签列表
- [ ] `forum-upload`：图片上传
- [ ] `forum-feedback`：反馈提交 + 我的反馈
- [ ] App 端论坛首页（标签 Tab 栏 + 帖子列表 + 关注 Tab）
- [ ] App 端发帖页（标题 + 正文 + 图片 + 标签选择）
- [ ] App 端帖子详情 + 回复 + 点赞/收藏/关注
- [ ] App 端「我的」页面（关注/收藏/反馈入口）
- [ ] App 端通知中心
- [ ] 管理后台（`forum-admin` HTML 渲染 + 全部管理功能）

### P1（体验完善）

- [ ] `forum-reports`：举报功能 + 管理后台举报处理
- [ ] `forum-search`：全文搜索
- [ ] `forum-notifications`：通知聚合去重
- [ ] 静态政策页（privacy/terms/rules）
- [ ] Cloudflare 自定义域名配置

### P2（运营增强）

- [ ] 敏感词过滤
- [ ] 数据导出（GDPR）
- [ ] 帖子搜索增强（按标签/时间范围）
- [ ] 草稿箱
- [ ] 图片压缩优化

---

> **文档结束** — V2.0 定稿，后续开发以本文档为准。
