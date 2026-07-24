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
    const path = url.pathname.replace('/forum-posts', '').replace(/^\//, '');
    const method = req.method;

    if (method === 'GET') {
      return await handleGet(req, url);
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

    const banCheck = await checkBan(user.id);
    if (banCheck.is_banned) {
      return Response.json({ error: 'Account banned', reason: banCheck.reason }, { status: 403, headers: corsHeaders });
    }

    if (method === 'POST') return await handlePost(req, user);
    if (method === 'PUT') return await handlePut(req, user, path);
    if (method === 'DELETE') return await handleDelete(user, path);

    return Response.json({ error: 'Method not allowed' }, { status: 405, headers: corsHeaders });
  } catch (error) {
    console.error('forum-posts error:', error);
    return Response.json({ error: 'Internal server error' }, { status: 500, headers: corsHeaders });
  }
});

async function checkBan(userId: string) {
  const { data } = await supabase
    .from('user_bans')
    .select('reason, expires_at')
    .eq('user_id', userId)
    .eq('is_active', true)
    .maybeSingle();
  if (!data) return { is_banned: false };
  if (data.expires_at && new Date(data.expires_at) < new Date()) return { is_banned: false };
  return { is_banned: true, reason: data.reason, expires_at: data.expires_at };
}

// GET 列表 — V2.0: tag_id 筛选 + followed 模式
async function handleGet(req: Request, url: URL) {
  const page = parseInt(url.searchParams.get('page') || '1');
  const limit = Math.min(parseInt(url.searchParams.get('limit') || '20'), 50);
  const tagId = url.searchParams.get('tag_id');
  const followed = url.searchParams.get('followed');
  const sort = url.searchParams.get('sort') || 'latest';
  const offset = (page - 1) * limit;

  // 鉴权（用于 is_liked / is_favorited / author_is_followed）
  let userId: string | null = null;
  const authHeader = req.headers.get('Authorization');
  if (authHeader) {
    const token = authHeader.replace('Bearer ', '');
    const { data: { user } } = await supabase.auth.getUser(token);
    if (user) userId = user.id;
  }

  let query = supabase
    .from('forum_posts')
    .select(`
      *,
      tag:forum_tags(id, name, color),
      author:user_profiles!forum_posts_author_id_fkey(id, raw_user_meta_data)
    `, { count: 'exact' })
    .eq('is_deleted', false);

  if (tagId) {
    query = query.eq('tag_id', parseInt(tagId));
  }

  // followed 模式：仅显示已关注标签的帖子
  if (followed === '1' && userId) {
    const { data: followedTags } = await supabase
      .from('forum_user_tag_follows')
      .select('tag_id')
      .eq('user_id', userId);
    if (followedTags && followedTags.length > 0) {
      const tagIds = followedTags.map((t: any) => t.tag_id);
      query = query.in('tag_id', tagIds);
    } else {
      return Response.json({
        data: [],
        pagination: { page, limit, total: 0, totalPages: 0 }
      }, { headers: corsHeaders });
    }
  }

  if (sort === 'hot') {
    query = query.order('like_count', { ascending: false }).order('reply_count', { ascending: false });
  } else {
    query = query.order('is_pinned', { ascending: false }).order('updated_at', { ascending: false });
  }

  query = query.range(offset, offset + limit - 1);

  const { data, error, count } = await query;
  if (error) throw error;

  // 补充当前用户状态
  const enriched = await enrichPosts(data || [], userId);

  return Response.json({
    data: enriched,
    pagination: { page, limit, total: count || 0, totalPages: Math.ceil((count || 0) / limit) }
  }, { headers: corsHeaders });
}

async function enrichPosts(posts: any[], userId: string | null) {
  if (!userId || posts.length === 0) {
    return posts.map(p => ({ ...p, is_liked_by_current_user: false, is_favorited: false, author_is_followed: false }));
  }

  const postIds = posts.map(p => p.id);
  const authorIds = [...new Set(posts.map(p => p.author_id))];

  const [likes, favorites, follows] = await Promise.all([
    supabase.from('forum_likes').select('target_id').eq('user_id', userId).eq('target_type', 'post').in('target_id', postIds),
    supabase.from('forum_favorites').select('post_id').eq('user_id', userId).in('post_id', postIds),
    supabase.from('forum_follows').select('following_id').eq('follower_id', userId).in('following_id', authorIds),
  ]);

  const likedSet = new Set((likes.data || []).map((l: any) => l.target_id));
  const favSet = new Set((favorites.data || []).map((f: any) => f.post_id));
  const followSet = new Set((follows.data || []).map((f: any) => f.following_id));

  return posts.map(p => ({
    ...p,
    is_liked_by_current_user: likedSet.has(p.id),
    is_favorited: favSet.has(p.id),
    author_is_followed: followSet.has(p.author_id),
  }));
}

// POST 创建帖子 — V2.0: tag_id 替代 board_id
async function handlePost(req: Request, user: any) {
  const body = await req.json();
  const { tag_id, title, content, image_urls } = body;

  if (!tag_id || !title || !content) {
    return Response.json({ error: 'Missing required fields: tag_id, title, content' }, { status: 400, headers: corsHeaders });
  }
  if (title.length < 2 || title.length > 80) {
    return Response.json({ error: 'Title must be 2-80 characters' }, { status: 400, headers: corsHeaders });
  }

  // 检查标签存在
  const { data: tag } = await supabase.from('forum_tags').select('id').eq('id', tag_id).eq('is_active', true).single();
  if (!tag) {
    return Response.json({ error: 'Invalid tag_id' }, { status: 400, headers: corsHeaders });
  }

  const { data, error } = await supabase
    .from('forum_posts')
    .insert({
      tag_id,
      author_id: user.id,
      title,
      content,
      image_urls: image_urls || [],
    })
    .select(`
      *,
      tag:forum_tags(id, name, color),
      author:user_profiles!forum_posts_author_id_fkey(id, raw_user_meta_data)
    `)
    .single();

  if (error) throw error;

  return Response.json({ data: { ...data, is_liked_by_current_user: false, is_favorited: false, author_is_followed: false } }, { status: 201, headers: corsHeaders });
}

// PUT 编辑帖子
async function handlePut(req: Request, user: any, path: string) {
  const id = parseInt(path);
  if (!id) return Response.json({ error: 'Invalid post id' }, { status: 400, headers: corsHeaders });

  const body = await req.json();
  const { title, content, image_urls } = body;

  const { data: post } = await supabase.from('forum_posts').select('id, author_id').eq('id', id).single();
  if (!post) return Response.json({ error: 'Post not found' }, { status: 404, headers: corsHeaders });

  const { data: role } = await supabase.from('user_roles').select('role').eq('user_id', user.id).single();
  const isAdmin = role && ['admin', 'moderator'].includes(role.role);
  if (post.author_id !== user.id && !isAdmin) {
    return Response.json({ error: 'No permission' }, { status: 403, headers: corsHeaders });
  }

  const updateData: any = { updated_at: new Date().toISOString() };
  if (title !== undefined) updateData.title = title;
  if (content !== undefined) updateData.content = content;
  if (image_urls !== undefined) updateData.image_urls = image_urls;

  const { data, error } = await supabase.from('forum_posts').update(updateData).eq('id', id).select().single();
  if (error) throw error;

  return Response.json({ data }, { headers: corsHeaders });
}

// DELETE 软删除
async function handleDelete(user: any, path: string) {
  const id = parseInt(path);
  if (!id) return Response.json({ error: 'Invalid post id' }, { status: 400, headers: corsHeaders });

  const { data: post } = await supabase.from('forum_posts').select('id, author_id').eq('id', id).single();
  if (!post) return Response.json({ error: 'Post not found' }, { status: 404, headers: corsHeaders });

  const { data: role } = await supabase.from('user_roles').select('role').eq('user_id', user.id).single();
  const isAdmin = role && ['admin', 'moderator'].includes(role.role);
  if (post.author_id !== user.id && !isAdmin) {
    return Response.json({ error: 'No permission' }, { status: 403, headers: corsHeaders });
  }

  const { error } = await supabase.from('forum_posts').update({
    is_deleted: true,
    deleted_by: user.id,
    deleted_at: new Date().toISOString(),
    deleted_reason: 'User deleted'
  }).eq('id', id);

  if (error) throw error;
  return Response.json({ success: true }, { headers: corsHeaders });
}
