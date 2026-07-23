import { serve } from "https://deno.land/std@0.224.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { corsHeaders } from '../_shared/cors.ts'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE);

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    if (req.method !== 'GET') {
      return Response.json({ error: 'Method not allowed' }, { status: 405, headers: corsHeaders });
    }

    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);

    // 获取所有板块
    const { data: boards, error: boardsError } = await supabase
      .from('forum_boards')
      .select('id, name, slug')
      .eq('is_active', true)
      .order('sort_order');

    if (boardsError) throw boardsError;

    const result = [];
    for (const board of boards) {
      // 板块帖子数
      const { count: postCount } = await supabase
        .from('forum_posts')
        .select('id', { count: 'exact', head: true })
        .eq('board_id', board.id)
        .eq('is_deleted', false);

      // 今日新增帖子
      const { count: todayPostCount } = await supabase
        .from('forum_posts')
        .select('id', { count: 'exact', head: true })
        .eq('board_id', board.id)
        .eq('is_deleted', false)
        .gte('created_at', todayStart.toISOString());

      // 今日新增回复（关联帖子）：先查出板块下帖子 ID，再查回复
      const { data: postIds } = await supabase
        .from('forum_posts')
        .select('id')
        .eq('board_id', board.id)
        .eq('is_deleted', false);

      let todayReplyCount = 0;
      if (postIds && postIds.length > 0) {
        const ids = postIds.map((p: any) => p.id);
        const { count } = await supabase
          .from('forum_replies')
          .select('id', { count: 'exact', head: true })
          .in('post_id', ids)
          .eq('is_deleted', false)
          .gte('created_at', todayStart.toISOString());
        todayReplyCount = count || 0;
      }

      result.push({
        board_id: board.id,
        name: board.name,
        slug: board.slug,
        post_count: postCount || 0,
        today_post_count: todayPostCount || 0,
        today_reply_count: todayReplyCount,
      });
    }

    return Response.json({ data: result }, { headers: corsHeaders });

  } catch (error) {
    console.error('forum-board-stats error:', error);
    return Response.json({ error: 'Internal server error' }, { status: 500, headers: corsHeaders });
  }
});
