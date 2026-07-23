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
    if (req.method === 'GET') {
      const url = new URL(req.url);
      return await handleGet(url);
    }

    // POST: 点赞（幂等，已点赞则取消）
    if (req.method === 'POST') {
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

      return await handleLike(req, user);
    }

    return Response.json({ error: 'Method not allowed' }, { status: 405, headers: corsHeaders });
  } catch (error) {
    console.error('forum-likes error:', error);
    return Response.json({ error: 'Internal server error' }, { status: 500, headers: corsHeaders });
  }
});

// GET 查询点赞状态/列表
async function handleGet(url: URL) {
  const targetType = url.searchParams.get('target_type');
  const targetId = url.searchParams.get('target_id');
  if (targetType && targetId) {
    const { data, error } = await supabase
      .from('forum_likes')
      .select('id, user_id, created_at')
      .eq('target_type', targetType)
      .eq('target_id', targetId);

    if (error) throw error;
    return Response.json({ data, count: data.length }, { headers: corsHeaders });
  }
  return Response.json({ error: 'Missing target_type/target_id' }, { status: 400, headers: corsHeaders });
}

// POST 点赞/取消（幂等）
async function handleLike(req: Request, user: any) {
  const body = await req.json();
  const { target_type, target_id } = body;

  if (!target_type || !target_id) {
    return Response.json({ error: 'Missing target_type, target_id' }, { status: 400, headers: corsHeaders });
  }
  if (!['post', 'reply'].includes(target_type)) {
    return Response.json({ error: 'Invalid target_type, must be post or reply' }, { status: 400, headers: corsHeaders });
  }

  // 检查目标是否存在
  if (target_type === 'post') {
    const { data: post } = await supabase.from('forum_posts').select('id, author_id, is_deleted').eq('id', target_id).single();
    if (!post || post.is_deleted) {
      return Response.json({ error: 'Post not found' }, { status: 404, headers: corsHeaders });
    }
  } else {
    const { data: reply } = await supabase.from('forum_replies').select('id, author_id, is_deleted').eq('id', target_id).single();
    if (!reply || reply.is_deleted) {
      return Response.json({ error: 'Reply not found' }, { status: 404, headers: corsHeaders });
    }
  }

  // 检查是否已点赞
  const { data: existing } = await supabase
    .from('forum_likes')
    .select('id')
    .eq('user_id', user.id)
    .eq('target_type', target_type)
    .eq('target_id', target_id)
    .maybeSingle();

  if (existing) {
    // 已点赞 → 取消点赞
    const { error } = await supabase
      .from('forum_likes')
      .delete()
      .eq('id', existing.id);

    if (error) throw error;
    return Response.json({ action: 'unliked', success: true }, { headers: corsHeaders });
  }

  // 未点赞 → 点赞
  const { error } = await supabase
    .from('forum_likes')
    .insert({ user_id: user.id, target_type, target_id });

  if (error) throw error;

  // 通知目标作者
  let targetAuthorId: string;
  if (target_type === 'post') {
    const { data: post } = await supabase.from('forum_posts').select('author_id, title').eq('id', target_id).single();
    targetAuthorId = post.author_id;
    if (targetAuthorId !== user.id) {
      await supabase.from('forum_notifications').insert({
        user_id: targetAuthorId,
        type: 'like',
        title: '你的帖子收到了新的点赞',
        body: `有人点赞了你的帖子「${post.title?.substring(0, 50)}」`,
        metadata: { post_id: target_id },
      });
    }
  } else {
    const { data: reply } = await supabase.from('forum_replies').select('author_id, post_id').eq('id', target_id).single();
    targetAuthorId = reply.author_id;
    if (targetAuthorId !== user.id) {
      await supabase.from('forum_notifications').insert({
        user_id: targetAuthorId,
        type: 'like',
        title: '你的回复收到了新的点赞',
        body: '有人点赞了你的回复',
        metadata: { post_id: reply.post_id, reply_id: target_id },
      });
    }
  }

  return Response.json({ action: 'liked', success: true }, { headers: corsHeaders });
}
