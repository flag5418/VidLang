import { serve } from "https://deno.land/std@0.224.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { corsHeaders } from '../_shared/cors.ts'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE);

// forum-follows — 关注用户
// POST /forum-follows            { following_id } — 切换关注（幂等）
// GET  /forum-follows?page=1     — 我的关注列表
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

    if (req.method === 'POST') return await toggleFollow(req, user);
    if (req.method === 'GET') return await getMyFollows(user, new URL(req.url));

    return Response.json({ error: 'Method not allowed' }, { status: 405, headers: corsHeaders });
  } catch (error) {
    console.error('forum-follows error:', error);
    return Response.json({ error: 'Internal server error' }, { status: 500, headers: corsHeaders });
  }
});

async function toggleFollow(req: Request, user: any) {
  const body = await req.json();
  const { following_id } = body;
  if (!following_id) {
    return Response.json({ error: 'Missing following_id' }, { status: 400, headers: corsHeaders });
  }
  if (following_id === user.id) {
    return Response.json({ error: 'Cannot follow yourself' }, { status: 400, headers: corsHeaders });
  }

  const { data: existing } = await supabase
    .from('forum_follows')
    .select('id')
    .eq('follower_id', user.id)
    .eq('following_id', following_id)
    .maybeSingle();

  if (existing) {
    await supabase.from('forum_follows').delete().eq('id', existing.id);
    return Response.json({ data: { followed: false } }, { headers: corsHeaders });
  }

  const { error } = await supabase.from('forum_follows').insert({
    follower_id: user.id,
    following_id,
  });
  if (error) throw error;

  // 通知被关注者
  await supabase.from('forum_notifications').insert({
    user_id: following_id,
    type: 'follow',
    title: '有人关注了你',
    body: '',
    metadata: { follower_id: user.id },
  });

  return Response.json({ data: { followed: true } }, { status: 201, headers: corsHeaders });
}

async function getMyFollows(user: any, url: URL) {
  const page = parseInt(url.searchParams.get('page') || '1');
  const limit = Math.min(parseInt(url.searchParams.get('limit') || '20'), 50);
  const offset = (page - 1) * limit;

  const { data, error, count } = await supabase
    .from('forum_follows')
    .select(`
      *,
      following:user_profiles!forum_follows_following_id_fkey(id, raw_user_meta_data)
    `, { count: 'exact' })
    .eq('follower_id', user.id)
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1);

  if (error) throw error;

  const enriched = (data || []).map((f: any) => {
    const meta = f.following?.raw_user_meta_data || {};
    return {
      ...f,
      nickname: meta.nickname || meta.name || '匿名用户',
      avatar: meta.avatar_url || '',
    };
  });

  return Response.json({
   enriched,
    pagination: { page, limit, total: count || 0, totalPages: Math.ceil((count || 0) / limit) }
  }, { headers: corsHeaders });
}
