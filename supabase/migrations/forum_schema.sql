-- ============================================================
-- VidLang 论坛系统 V1.1 完整数据库迁移
-- 设计文档: docs/modules/forum-design.md V1.1
-- 创建时间：2026-07-22
-- ============================================================

-- ============================================================
-- 第一部分：11 张表的完整 DDL
-- ============================================================

-- 1. 板块定义
CREATE TABLE IF NOT EXISTS forum_boards (
    id          SERIAL PRIMARY KEY,
    name        TEXT NOT NULL,
    slug        TEXT NOT NULL UNIQUE,
    description TEXT DEFAULT '',
    sort_order  INT DEFAULT 0,
    is_active   BOOLEAN DEFAULT TRUE,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 2. 帖子主表
CREATE TABLE IF NOT EXISTS forum_posts (
    id              BIGSERIAL PRIMARY KEY,
    board_id        INT NOT NULL REFERENCES forum_boards(id),
    author_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title           TEXT NOT NULL,
    content         TEXT NOT NULL,
    resource_type   TEXT DEFAULT NULL,
    resource_code   TEXT DEFAULT NULL,
    image_urls      JSONB DEFAULT '[]'::jsonb,
    view_count      INT DEFAULT 0,
    reply_count     INT DEFAULT 0,
    like_count      INT DEFAULT 0,
    is_pinned       BOOLEAN DEFAULT FALSE,
    is_featured     BOOLEAN DEFAULT FALSE,
    is_deleted      BOOLEAN DEFAULT FALSE,
    deleted_reason  TEXT DEFAULT NULL,
    deleted_by      UUID DEFAULT NULL REFERENCES auth.users(id),
    deleted_at      TIMESTAMPTZ DEFAULT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- 3. 回复表
CREATE TABLE IF NOT EXISTS forum_replies (
    id              BIGSERIAL PRIMARY KEY,
    post_id         BIGINT NOT NULL REFERENCES forum_posts(id) ON DELETE CASCADE,
    author_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    parent_id       BIGINT DEFAULT NULL REFERENCES forum_replies(id) ON DELETE CASCADE,
    content         TEXT NOT NULL,
    image_urls      JSONB DEFAULT '[]'::jsonb,
    like_count      INT DEFAULT 0,
    is_deleted      BOOLEAN DEFAULT FALSE,
    deleted_reason  TEXT DEFAULT NULL,
    deleted_by      UUID DEFAULT NULL REFERENCES auth.users(id),
    deleted_at      TIMESTAMPTZ DEFAULT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- 4. 点赞记录
CREATE TABLE IF NOT EXISTS forum_likes (
    id          BIGSERIAL PRIMARY KEY,
    user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    target_type TEXT NOT NULL CHECK (target_type IN ('post', 'reply')),
    target_id   BIGINT NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (user_id, target_type, target_id)
);

-- 5. 举报记录
CREATE TABLE IF NOT EXISTS forum_reports (
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

-- 6. 通知记录
CREATE TABLE IF NOT EXISTS forum_notifications (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type            TEXT NOT NULL CHECK (type IN ('reply', 'mention', 'like', 'system', 'report_result')),
    title           TEXT NOT NULL,
    body            TEXT NOT NULL,
    metadata        JSONB DEFAULT '{}'::jsonb,
    is_read         BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- 7. 标签定义
CREATE TABLE IF NOT EXISTS forum_tags (
    id          SERIAL PRIMARY KEY,
    name        TEXT NOT NULL UNIQUE,
    slug        TEXT NOT NULL UNIQUE,
    color       TEXT DEFAULT '#6366F1',
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 8. 帖子-标签关联
CREATE TABLE IF NOT EXISTS forum_post_tags (
    post_id BIGINT NOT NULL REFERENCES forum_posts(id) ON DELETE CASCADE,
    tag_id  INT NOT NULL REFERENCES forum_tags(id) ON DELETE CASCADE,
    PRIMARY KEY (post_id, tag_id)
);

-- 9. 用户角色
CREATE TABLE IF NOT EXISTS user_roles (
    id          SERIAL PRIMARY KEY,
    user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
    role        TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'moderator', 'admin')),
    granted_by  UUID DEFAULT NULL REFERENCES auth.users(id),
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 10. 封禁记录
CREATE TABLE IF NOT EXISTS user_bans (
    id          SERIAL PRIMARY KEY,
    user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reason      TEXT NOT NULL,
    banned_by   UUID NOT NULL REFERENCES auth.users(id),
    banned_at   TIMESTAMPTZ DEFAULT NOW(),
    expires_at  TIMESTAMPTZ DEFAULT NULL,
    is_active   BOOLEAN DEFAULT TRUE
);

-- 11. 用户反馈
CREATE TABLE IF NOT EXISTS forum_feedback (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type            TEXT NOT NULL CHECK (type IN ('bug', 'feature', 'other')),
    title           TEXT NOT NULL,
    content         TEXT NOT NULL,
    image_urls      JSONB DEFAULT '[]'::jsonb,
    status          TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'resolved', 'closed')),
    admin_reply     TEXT DEFAULT NULL,
    replied_by      UUID DEFAULT NULL REFERENCES auth.users(id),
    replied_at      TIMESTAMPTZ DEFAULT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);


-- ============================================================
-- 第二部分：所有索引
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_v2_forum_posts_board_id ON forum_posts(board_id, is_deleted, is_pinned DESC, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_v2_forum_posts_author_id ON forum_posts(author_id, is_deleted, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_v2_forum_posts_resource ON forum_posts(resource_type, resource_code) WHERE resource_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_v2_forum_posts_search ON forum_posts USING GIN (to_tsvector('simple', title || ' ' || content));

CREATE INDEX IF NOT EXISTS idx_v2_forum_replies_post_id ON forum_replies(post_id, is_deleted, created_at);
CREATE INDEX IF NOT EXISTS idx_v2_forum_replies_author_id ON forum_replies(author_id, is_deleted, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_v2_forum_likes_target ON forum_likes(target_type, target_id);

CREATE INDEX IF NOT EXISTS idx_v2_forum_reports_status ON forum_reports(status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_v2_forum_notifications_user ON forum_notifications(user_id, is_read, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_v2_user_roles_role ON user_roles(role);

CREATE INDEX IF NOT EXISTS idx_v2_user_bans_active ON user_bans(user_id, is_active);

CREATE INDEX IF NOT EXISTS idx_v2_forum_feedback_user ON forum_feedback(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_v2_forum_feedback_status ON forum_feedback(status, created_at DESC);


-- ============================================================
-- 第三部分：RLS 策略（ENABLE + 所有 CREATE POLICY）
-- ============================================================

ALTER TABLE forum_boards ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_replies ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_post_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_bans ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_feedback ENABLE ROW LEVEL SECURITY;

-- forum_boards: 所有人可读
CREATE POLICY "Boards are viewable by everyone" ON forum_boards
    FOR SELECT USING (is_active = TRUE);

-- forum_posts: 所有人可读（不含已删除），作者和管理员可更新
CREATE POLICY "Posts are viewable by everyone" ON forum_posts
    FOR SELECT USING (is_deleted = FALSE);

CREATE POLICY "Posts can be created by authenticated users" ON forum_posts
    FOR INSERT WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Posts can be updated by author or admin" ON forum_posts
    FOR UPDATE USING (
        auth.uid() = author_id
        OR EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND role IN ('moderator', 'admin'))
    );

-- forum_replies: 同上
CREATE POLICY "Replies are viewable by everyone" ON forum_replies
    FOR SELECT USING (is_deleted = FALSE);

CREATE POLICY "Replies can be created by authenticated users" ON forum_replies
    FOR INSERT WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Replies can be updated by author or admin" ON forum_replies
    FOR UPDATE USING (
        auth.uid() = author_id
        OR EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND role IN ('moderator', 'admin'))
    );

-- forum_likes: 公开可读，用户管理自己的点赞
CREATE POLICY "Likes are viewable by everyone" ON forum_likes
    FOR SELECT USING (TRUE);

CREATE POLICY "Users can manage their own likes" ON forum_likes
    FOR ALL USING (auth.uid() = user_id);

-- forum_reports: 仅举报者和管理员可读
CREATE POLICY "Reports viewable by reporter and admin" ON forum_reports
    FOR SELECT USING (
        auth.uid() = reporter_id
        OR EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND role IN ('moderator', 'admin'))
    );

CREATE POLICY "Reports can be created by authenticated users" ON forum_reports
    FOR INSERT WITH CHECK (auth.uid() = reporter_id);

-- forum_notifications: 仅通知接收者可读写
CREATE POLICY "Notifications viewable by owner" ON forum_notifications
    FOR ALL USING (auth.uid() = user_id);

-- forum_tags: 所有人可读
CREATE POLICY "Tags are viewable by everyone" ON forum_tags
    FOR SELECT USING (TRUE);

-- forum_post_tags: 所有人可读
CREATE POLICY "Post tags are viewable by everyone" ON forum_post_tags
    FOR SELECT USING (TRUE);

-- user_roles: 所有人可读
CREATE POLICY "Roles viewable by everyone" ON user_roles
    FOR SELECT USING (TRUE);

-- user_bans: 所有人可读
CREATE POLICY "Bans viewable by everyone" ON user_bans
    FOR SELECT USING (TRUE);

-- forum_feedback: 提交者可读自己的，管理员可读全部
CREATE POLICY "Feedback viewable by owner and admin" ON forum_feedback
    FOR SELECT USING (
        auth.uid() = user_id
        OR EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND role IN ('moderator', 'admin'))
    );

CREATE POLICY "Feedback can be created by authenticated users" ON forum_feedback
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Feedback can be updated by admin" ON forum_feedback
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND role IN ('moderator', 'admin'))
    );


-- ============================================================
-- 第四部分：触发器（自动更新计数器）
-- ============================================================

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

DROP TRIGGER IF EXISTS trigger_update_post_reply_count ON forum_replies;
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

DROP TRIGGER IF EXISTS trigger_update_like_count ON forum_likes;
CREATE TRIGGER trigger_update_like_count
    AFTER INSERT OR DELETE ON forum_likes
    FOR EACH ROW EXECUTE FUNCTION update_like_count();

-- 帖子 updated_at 自动更新
CREATE OR REPLACE FUNCTION update_post_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_post_timestamp ON forum_posts;
CREATE TRIGGER trigger_update_post_timestamp
    BEFORE UPDATE ON forum_posts
    FOR EACH ROW EXECUTE FUNCTION update_post_timestamp();


-- ============================================================
-- 第五部分：种子数据
-- ============================================================

-- 板块种子数据
INSERT INTO forum_boards (name, slug, description, sort_order) VALUES
    ('综合讨论', 'general', '不限主题的自由讨论区', 1),
    ('学习问答', 'qa', '学习方法、语法疑问、资源推荐', 2),
    ('功能反馈', 'feedback', 'Bug 报告、功能建议', 3),
    ('官方公告', 'announcement', '系统更新、规则变更（仅管理员可发帖）', 4)
ON CONFLICT (slug) DO NOTHING;

-- 标签种子数据
INSERT INTO forum_tags (name, slug, color) VALUES
    ('资源', 'resource', '#10B981'),
    ('求助', 'help', '#F59E0B'),
    ('经验', 'experience', '#3B82F6'),
    ('打卡', 'checkin', '#8B5CF6'),
    ('交友', 'social', '#EC4899'),
    ('闲聊', 'chat', '#6B7280')
ON CONFLICT (slug) DO NOTHING;
