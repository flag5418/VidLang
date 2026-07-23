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

    const url = new URL(req.url);
    const id = parseInt(url.searchParams.get('id') || '0');
    if (!id) {
      return Response.json({ error: 'Missing id parameter' }, { status: 400, headers: corsHeaders });
    }

    // 获取帖子详情
    const { data: post, error } = await supabase
      .from('forum_posts')
      .select(`
        *,
        tag:forum_tags(id, name, color),
        author:user_profiles!forum_posts_author_id_fkey(id, raw_user_meta_data)
      `)
      .eq('id', id)
      .eq('is_deleted', false)
      .single();

    if (error || !post) {
      return Response.json({ error: 'Post not found' }, { status: 404, headers: corsHeaders });
    }

    // 增加浏览量
    await supabase
      .from('forum_posts')
      .update({ view_count: (post.view_count || 0) + 1 })
      .eq('id', id);

    return Response.json({ data: post }, { headers: corsHeaders });

  } catch (error) {
    console.error('forum-post-detail error:', error);
    return Response.json({ error: 'Internal server error' }, { status: 500, headers: corsHeaders });
  }
});
