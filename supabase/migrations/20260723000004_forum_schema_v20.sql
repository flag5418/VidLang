-- ============================================================
-- VidLang 论坛 V2.0 数据库迁移
-- 变更：板块→标签驱动，删除 forum_boards / forum_post_tags
-- 新增：forum_favorites / forum_follows / forum_user_tag_follows
-- 简化：forum_posts（tag_id替代board_id）forum_replies（单层结构）
-- ============================================================

BEGIN;

-- ──────────────────────────────────────────────────────
-- 1. 删除 V1.1 遗留表
-- ──────────────────────────────────────────────────────
DROP TABLE IF EXISTS forum_board_stickers CASCADE;
DROP TABLE IF EXISTS forum_post_tags CASCADE;
DROP TABLE IF EXISTS forum_boards CASCADE;

-- ──────────────────────────────────────────────────────
-- 2. 重建 forum_tags（删 slug，加 sort_order/is_active）
-- ──────────────────────────────────────────────────────
-- 先备份旧标签数据
CREATE TEMP TABLE _forum_tags_backup AS SELECT * FROM forum_tags;

-- 删旧表
DROP TABLE IF EXISTS forum_tags CASCADE;

CREATE TABLE forum_tags (
    id          SERIAL PRIMARY KEY,
    name        TEXT NOT NULL UNIQUE,
    color       TEXT DEFAULT '#4ADE80',
    sort_order  INT DEFAULT 0,
    is_active   BOOLEAN DEFAULT TRUE,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 恢复标签数据
INSERT INTO forum_tags (id, name, color, created_at)
SELECT id, name, COALESCE(color, '#4ADE80'), created_at
FROM _forum_tags_backup;

DROP TABLE _forum_tags_backup;

-- ──────────────────────────────────────────────────────
-- 3. 重建 forum_posts
-- ──────────────────────────────────────────────────────
CREATE TEMP TABLE _forum_posts_backup AS
SELECT id, author_id, title, content, image_urls,
       view_count, reply_count, like_count,
       is_pinned, is_deleted, deleted_reason,
       deleted_by, deleted_at, created_at, updated_at,
       board_id
FROM forum_posts;

DROP TABLE IF EXISTS forum_posts CASCADE;

CREATE TABLE forum_posts (
    id              BIGSERIAL PRIMARY KEY,
    tag_id          INT DEFAULT NULL REFERENCES forum_tags(id),
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

-- 恢复帖子数据（tag_id 设为 NULL，后续可通过管理后台关联标签）
INSERT INTO forum_posts (id, author_id, title, content, image_urls,
    view_count, reply_count, like_count, is_pinned, is_deleted,
    deleted_reason, deleted_by, deleted_at, created_at, updated_at)
SELECT id, author_id, title, content, image_urls,
       view_count, reply_count, like_count, is_pinned, is_deleted,
       deleted_reason, deleted_by, deleted_at, created_at, updated_at
FROM _forum_posts_backup;

DROP TABLE _forum_posts_backup;

-- 重置序列
SELECT setval('forum_posts_id_seq', COALESCE((SELECT MAX(id) FROM forum_posts), 1));

-- ──────────────────────────────────────────────────────
-- 4. 重建 forum_replies（去 parent_id / image_urls）
-- ──────────────────────────────────────────────────────
CREATE TEMP TABLE _forum_replies_backup AS
SELECT id, post_id, author_id, content, like_count,
       is_deleted, deleted_reason, deleted_by, deleted_at, created_at
FROM forum_replies;

DROP TABLE IF EXISTS forum_replies CASCADE;

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

INSERT INTO forum_replies (id, post_id, author_id, content, like_count,
    is_deleted, deleted_reason, deleted_by, deleted_at, created_at)
SELECT id, post_id, author_id, content, like_count,
       is_deleted, deleted_reason, deleted_by, deleted_at, created_at
FROM _forum_replies_backup;

DROP TABLE _forum_replies_backup;

SELECT setval('forum_replies_id_seq', COALESCE((SELECT MAX(id) FROM forum_replies), 1));

-- ──────────────────────────────────────────────────────
-- 5. 重建 forum_notifications（扩展 type CHECK）
-- ──────────────────────────────────────────────────────
ALTER TABLE forum_notifications
DROP CONSTRAINT IF EXISTS forum_notifications_type_check;

ALTER TABLE forum_notifications
ADD CONSTRAINT forum_notifications_type_check
CHECK (type IN ('reply', 'like', 'favorite', 'follow',
                'post_removed', 'user_muted', 'feedback_replied', 'system'));

-- ──────────────────────────────────────────────────────
-- 6. 更新 forum_feedback status CHECK
-- ──────────────────────────────────────────────────────
ALTER TABLE forum_feedback
DROP CONSTRAINT IF EXISTS forum_feedback_status_check;

ALTER TABLE forum_feedback
ADD CONSTRAINT forum_feedback_status_check
CHECK (status IN ('pending', 'processing', 'replied', 'closed'));

-- ──────────────────────────────────────────────────────
-- 7. 新建 forum_favorites
-- ──────────────────────────────────────────────────────
CREATE TABLE forum_favorites (
    id        BIGSERIAL PRIMARY KEY,
    user_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    post_id   BIGINT NOT NULL REFERENCES forum_posts(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (user_id, post_id)
);

CREATE INDEX idx_forum_favorites_user_id ON forum_favorites(user_id, created_at DESC);

-- ──────────────────────────────────────────────────────
-- 8. 新建 forum_follows
-- ──────────────────────────────────────────────────────
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

-- ──────────────────────────────────────────────────────
-- 9. 新建 forum_user_tag_follows
-- ──────────────────────────────────────────────────────
CREATE TABLE forum_user_tag_follows (
    id        BIGSERIAL PRIMARY KEY,
    user_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    tag_id    INT NOT NULL REFERENCES forum_tags(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (user_id, tag_id)
);

CREATE INDEX idx_forum_user_tag_follows_user ON forum_user_tag_follows(user_id);

-- ──────────────────────────────────────────────────────
-- 10. RLS 策略
-- ──────────────────────────────────────────────────────

-- 启用所有表的 RLS
ALTER TABLE forum_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_replies ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_user_tag_follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_tags ENABLE ROW LEVEL SECURITY;

-- 先删除可能存在的旧策略（避免重复错误）
DO $$
BEGIN
    EXECUTE (
        SELECT string_agg('DROP POLICY IF EXISTS ' || quote_ident(policyname) || ' ON ' || quote_ident(tablename) || ';', ' ')
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename IN (
              'forum_posts','forum_replies','forum_likes','forum_favorites',
              'forum_follows','forum_user_tag_follows','forum_reports',
              'forum_notifications','forum_feedback','forum_tags'
          )
    );
END $$;

-- forum_tags
CREATE POLICY "Tags are viewable by everyone"
    ON forum_tags FOR SELECT USING (is_active = TRUE);

CREATE POLICY "Admins can manage tags"
    ON forum_tags FOR ALL USING (EXISTS (
        SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND role IN ('moderator', 'admin')
    ));

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

-- ──────────────────────────────────────────────────────
-- 11. 收藏数触发器
-- ──────────────────────────────────────────────────────
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

DROP TRIGGER IF EXISTS trigger_update_favorite_count ON forum_favorites;
CREATE TRIGGER trigger_update_favorite_count
    AFTER INSERT OR DELETE ON forum_favorites
    FOR EACH ROW EXECUTE FUNCTION update_favorite_count();

-- ──────────────────────────────────────────────────────
-- 12. 重新创建现有触发器（表重建后需重新绑定）
-- ──────────────────────────────────────────────────────
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

COMMIT;
