import { serve } from "https://deno.land/std@0.224.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { corsHeaders } from '../_shared/cors.ts'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE);

// forum-tag-follows — 关注标签
// POST /forum-tag-follows          { tag_id } — 切换标签关注（幂等）
// GET  /forum-tag-follows          — 我关注的标签列表
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

    if (req.method === 'POST') return await toggleTagFollow(req, user);
    if (req.method === 'GET') return await getMyTagFollows(user);

    return Response.json({ error: 'Method not allowed' }, { status: 405, headers: corsHeaders });
  } catch (error) {
    console.error('forum-tag-follows error:', error);
    return Response.json({ error: 'Internal server error' }, { status: 500, headers: corsHeaders });
  }
});

async function toggleTagFollow(req: Request, user: any) {
  const body = await req.json();
  const { tag_id } = body;
  if (!tag_id) {
    return Response.json({ error: 'Missing tag_id' }, { status: 400, headers: corsHeaders });
  }

  const { data: tag, error: tagError } = await supabase
    .from('forum_tags')
    .select('id')
    .eq('id', tag_id)
    .eq('is_active', true)
    .single();
  if (tagError || !tag) {
    return Response.json({ error: 'Tag not found' }, { status: 404, headers: corsHeaders });
  }

  const { data: existing } = await supabase
    .from('forum_user_tag_follows')
    .select('id')
    .eq('user_id', user.id)
    .eq('tag_id', tag_id)
    .maybeSingle();

  if (existing) {
    await supabase.from('forum_user_tag_follows').delete().eq('id', existing.id);
    return Response.json({ data: { followed: false } }, { headers: corsHeaders });
  }

  const { error } = await supabase.from('forum_user_tag_follows').insert({
    user_id: user.id,
    tag_id,
  });
  if (error) throw error;

  return Response.json({ data: { followed: true } }, { status: 201, headers: corsHeaders });
}

async function getMyTagFollows(user: any) {
  const { data, error } = await supabase
    .from('forum_user_tag_follows')
    .select(`
      *,
      tag:forum_tags(id, name, color)
    `)
    .eq('user_id', user.id)
    .order('created_at', { ascending: false });

  if (error) throw error;

  return Response.json({ data }, { headers: corsHeaders });
}
