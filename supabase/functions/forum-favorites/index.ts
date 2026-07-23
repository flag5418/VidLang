import { serve } from "https://deno.land/std@0.224.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { corsHeaders } from '../_shared/cors.ts'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE);

// forum-favorites — 收藏帖子
// POST   /forum-favorites          { post_id } — 切换收藏（幂等）
// GET    /forum-favorites?page=1   — 我的收藏列表
serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return Response.json({ error: 'Unauthorized' }, { status: 401, headers: corsHeaders });
    }
    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) {
      return Response.json({ error: 'Invalid token' }, { status: 401, headers: corsHeaders });
    }

    if (req.method === 'POST') return await toggleFavorite(req, user);
    if (req.method === 'GET') return await getMyFavorites(user, new URL(req.url));

    return Response.json({ error: 'Method not allowed' }, { status: 405, headers: corsHeaders });
  } catch (error) {
    console.error('forum-favorites error:', error);
    return Response.json({ error: 'Internal server error' }, { status: 500, headers: corsHeaders });
  }
});

async function toggleFavorite(req: Request, user: any) {
  const body = await req.json();
  const { post_id } = body;
  if (!post_id) {
    return Response.json({ error: 'Missing post_id' }, { status: 400, headers: corsHeaders });
  }

  const { data: post } = await supabase
    .from('forum_posts')
    .select('id, author_id, title')
    .eq('id', post_id)
    .eq('is_deleted', false)
    .single();
  if (!post) {
    return Response.json({ error: 'Post not found' }, { status: 404, headers: corsHeaders });
  }

  const { data: existing } = await supabase
    .from('forum_favorites')
    .select('id')
    .eq('user_id', user.id)
    .eq('post_id', post_id)
    .maybeSingle();

  if (existing) {
    await supabase.from('forum_favorites').delete().eq('id', existing.id);
    return Response.json({ data: { favorited: false } }, { headers: corsHeaders });
  }

  const { error } = await supabase.from('forum_favorites').insert({
    user_id: user.id,
    post_id,
  });
  if (error) throw error;

  // 通知帖子作者
  if (post.author_id !== user.id) {
    await supabase.from('forum_notifications').insert({
      user_id: post.author_id,
      type: 'favorite',
      title: '有人收藏了你的帖子',
      body: post.title,
      metadata: { post_id: post.id },
    });
  }

  return Response.json({ data: { favorited: true } }, { status: 201, headers: corsHeaders });
}

async function getMyFavorites(user: any, url: URL) {
  const page = parseInt(url.searchParams.get('page') || '1');
  const limit = Math.min(parseInt(url.searchParams.get('limit') || '20'), 50);
  const offset = (page - 1) * limit;

  const { data, error, count } = await supabase
    .from('forum_favorites')
    .select(`
      *,
      post:forum_posts(id, title, content, reply_count, like_count, favorite_count, is_deleted, created_at,
        tag:forum_tags(id, name, color),
        author:user_profiles(id, raw_user_meta_data))
    `, { count: 'exact' })
    .eq('user_id', user.id)
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1);

  if (error) throw error;

  return Response.json({
    data,
    pagination: { page, limit, total: count || 0, totalPages: Math.ceil((count || 0) / limit) }
  }, { headers: corsHeaders });
}
