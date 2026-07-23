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
    const url = new URL(req.url);
    const path = url.pathname.replace('/forum-replies', '').replace(/^\//, '');
    const method = req.method;

    if (method === 'GET') {
      return await handleGet(url);
    }

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return Response.json({ error: 'Unauthorized' }, { status: 401, headers: corsHeaders });
    }
    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) {
      return Response.json({ error: 'Invalid token' }, { status: 401, headers: corsHeaders });
    }

    const { data: ban } = await supabase.from('user_bans').select('id').eq('user_id', user.id).eq('is_active', true).maybeSingle();
    if (ban) {
      return Response.json({ error: 'Account banned' }, { status: 403, headers: corsHeaders });
    }

    if (method === 'POST') return await handlePost(req, user);
    if (method === 'DELETE') return await handleDelete(user, path);

    return Response.json({ error: 'Method not allowed' }, { status: 405, headers: corsHeaders });
  } catch (error) {
    console.error('forum-replies error:', error);
    return Response.json({ error: 'Internal server error' }, { status: 500, headers: corsHeaders });
  }
});

// GET 回复列表 — V2.0 单层结构
async function handleGet(url: URL) {
  const postId = url.searchParams.get('post_id');
  const page = parseInt(url.searchParams.get('page') || '1');
  const limit = Math.min(parseInt(url.searchParams.get('limit') || '20'), 50);
  const offset = (page - 1) * limit;

  if (!postId) {
    return Response.json({ error: 'Missing post_id' }, { status: 400, headers: corsHeaders });
  }

  const { data, error, count } = await supabase
    .from('forum_replies')
    .select(`
      *,
      author:user_profiles(id, raw_user_meta_data)
    `, { count: 'exact' })
    .eq('post_id', postId)
    .eq('is_deleted', false)
    .order('created_at', { ascending: true })
    .range(offset, offset + limit - 1);

  if (error) throw error;

  return Response.json({
    data,
    pagination: { page, limit, total: count || 0, totalPages: Math.ceil((count || 0) / limit) }
  }, { headers: corsHeaders });
}

// POST 创建回复 — V2.0: 单层结构，无 parent_id
async function handlePost(req: Request, user: any) {
  const body = await req.json();
  const { post_id, content } = body;

  if (!post_id || !content) {
    return Response.json({ error: 'Missing required fields: post_id, content' }, { status: 400, headers: corsHeaders });
  }

  const { data: post } = await supabase
    .from('forum_posts')
    .select('id, author_id, title, is_deleted')
    .eq('id', post_id)
    .eq('is_deleted', false)
    .single();

  if (!post) {
    return Response.json({ error: 'Post not found' }, { status: 404, headers: corsHeaders });
  }

  const { data, error } = await supabase
    .from('forum_replies')
    .insert({
      post_id,
      author_id: user.id,
      content,
    })
    .select()
    .single();

  if (error) throw error;

  // 通知帖子作者
  if (post.author_id !== user.id) {
    await supabase.from('forum_notifications').insert({
      user_id: post.author_id,
      type: 'reply',
      title: '有人回复了你的帖子',
      body: content.substring(0, 200),
      metadata: { post_id: post.id, reply_id: data.id },
    });
  }

  return Response.json({ data }, { status: 201, headers: corsHeaders });
}

// DELETE 软删除
async function handleDelete(user: any, path: string) {
  const id = parseInt(path);
  if (!id) return Response.json({ error: 'Invalid reply id' }, { status: 400, headers: corsHeaders });

  const { data: reply } = await supabase.from('forum_replies').select('id, author_id').eq('id', id).single();
  if (!reply) return Response.json({ error: 'Reply not found' }, { status: 404, headers: corsHeaders });

  const { data: role } = await supabase.from('user_roles').select('role').eq('user_id', user.id).single();
  const isAdmin = role && ['admin', 'moderator'].includes(role.role);
  if (reply.author_id !== user.id && !isAdmin) {
    return Response.json({ error: 'No permission' }, { status: 403, headers: corsHeaders });
  }

  const { error } = await supabase.from('forum_replies').update({
    is_deleted: true, deleted_by: user.id, deleted_at: new Date().toISOString(), deleted_reason: 'User deleted'
  }).eq('id', id);

  if (error) throw error;
  return Response.json({ success: true }, { headers: corsHeaders });
}
