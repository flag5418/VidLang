-- ============================================================
-- 修复 V2.0 迁移遗留问题：将 tag_id 为 NULL 的帖子分配到现有标签
-- ============================================================

BEGIN;

-- 将无标签帖子随机散布到 6 个活跃标签
UPDATE forum_posts
SET tag_id = (
    SELECT id FROM forum_tags
    WHERE is_active = TRUE
    ORDER BY RANDOM()
    LIMIT 1
)
WHERE tag_id IS NULL;

-- 验证
DO $$
DECLARE
    null_count INT;
BEGIN
    SELECT COUNT(*) INTO null_count FROM forum_posts WHERE tag_id IS NULL;
    IF null_count > 0 THEN
        RAISE WARNING '仍有 % 条帖子 tag_id 为 NULL', null_count;
    ELSE
        RAISE NOTICE '全部帖子已分配标签';
    END IF;
END $$;

COMMIT;
