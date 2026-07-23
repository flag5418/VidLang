import { serve } from "https://deno.land/std@0.224.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { corsHeaders } from '../_shared/cors.ts'
import { verifyAdmin } from '../_shared/admin-auth.ts'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE);

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return Response.json({ error: 'Unauthorized' }, { status: 401, headers: corsHeaders });
    }
    const admin = await verifyAdmin(authHeader.replace('Bearer ', ''));
    if (!admin) {
      return Response.json({ error: 'No admin permission' }, { status: 403, headers: corsHeaders });
    }

    const url = new URL(req.url);
    const path = url.pathname.replace('/forum-admin-posts', '').replace(/^\//, '');
    const method = req.method;

    if (method === 'GET') return await handleGet(url, path);
    if (method === 'PUT') return await handlePut(req, admin, path);
    if (method === 'DELETE') return await handleDelete(admin, path);

    return Response.json({ error: 'Method not allowed' }, { status: 405, headers: corsHeaders });
  } catch (error) {
    console.error('forum-admin-posts error:', error);
    return Response.json({ error: 'Internal server error' }, { status: 500, headers: corsHeaders });
  }
});

// GET 帖子列表（含已删除）
async function handleGet(url: URL, path: string) {
  const page = parseInt(url.searchParams.get('page') || '1');
  const limit = Math.min(parseInt(url.searchParams.get('limit') || '20'), 50);
  const tagId = url.searchParams.get('tag_id');
  const status = url.searchParams.get('status'); // deleted / reported / all
  const keyword = url.searchParams.get('keyword');
  const offset = (page - 1) * limit;

  let query = supabase
    .from('forum_posts')
    .select(`
      *,
      tag:forum_tags(id, name, color),
      author:user_profiles!forum_posts_author_id_fkey(id, raw_user_meta_data)
    `, { count: 'exact' });

  if (tagId) {
    query = query.eq('tag_id', parseInt(tagId));
  }
  if (status === 'deleted') {
    query = query.eq('is_deleted', true);
  } else if (!status || status === 'all') {
    // 不做过滤
  } else {
    query = query.eq('is_deleted', false);
  }
  if (keyword) {
    query = query.ilike('title', `%${keyword}%`);
  }

  query = query.order('updated_at', { ascending: false }).range(offset, offset + limit - 1);

  const { data, error, count } = await query;
  if (error) throw error;

  return Response.json({
    data,
    pagination: { page, limit, total: count || 0, totalPages: Math.ceil((count || 0) / limit) }
  }, { headers: corsHeaders });
}

// PUT 编辑、设置置顶、设置加精
async function handlePut(req: Request, admin: any, path: string) {
  const segments = path.split('/');
  const id = parseInt(segments[0]);
  const action = segments[1];

  if (!id) return Response.json({ error: 'Invalid id' }, { status: 400, headers: corsHeaders });

  // 置顶操作
  if (action === 'pin') {
    const { data: post } = await supabase.from('forum_posts').select('id, is_pinned').eq('id', id).single();
    if (!post) return Response.json({ error: 'Post not found' }, { status: 404, headers: corsHeaders });

    const { error } = await supabase.from('forum_posts').update({ is_pinned: !post.is_pinned, updated_by: admin.user.id }).eq('id', id);
    if (error) throw error;
    return Response.json({ success: true, is_pinned: !post.is_pinned }, { headers: corsHeaders });
  }

  // 加精操作
  if (action === 'essence') {
    const { data: post } = await supabase.from('forum_posts').select('id, is_essence').eq('id', id).single();
    if (!post) return Response.json({ error: 'Post not found' }, { status: 404, headers: corsHeaders });

    const { error } = await supabase.from('forum_posts').update({ is_essence: !post.is_essence, updated_by: admin.user.id }).eq('id', id);
    if (error) throw error;
    return Response.json({ success: true, is_essence: !post.is_essence }, { headers: corsHeaders });
  }

  // 编辑帖子内容
  const body = await req.json();
  const { title, content, tag_id, image_urls, is_deleted, deleted_reason } = body;

  const updateData: any = { updated_by: admin.user.id, updated_at: new Date().toISOString() };
  if (title !== undefined) updateData.title = title;
  if (content !== undefined) updateData.content = content;
  if (tag_id !== undefined) updateData.tag_id = tag_id;
  if (image_urls !== undefined) updateData.image_urls = image_urls;
  if (is_deleted !== undefined) {
    updateData.is_deleted = is_deleted;
    updateData.deleted_by = admin.user.id;
    updateData.deleted_at = new Date().toISOString();
    updateData.deleted_reason = deleted_reason || 'Admin operation';
  }

  const { data, error } = await supabase.from('forum_posts').update(updateData).eq('id', id).select().single();
  if (error) throw error;

  return Response.json({ data }, { headers: corsHeaders });
}

// DELETE 彻底删除（仅 admin）
async function handleDelete(admin: any, path: string) {
  const id = parseInt(path);
  if (!id) return Response.json({ error: 'Invalid id' }, { status: 400, headers: corsHeaders });

  if (admin.role !== 'admin') {
    return Response.json({ error: 'Only admin can permanently delete' }, { status: 403, headers: corsHeaders });
  }

  // 删除关联数据
  await supabase.from('forum_favorites').delete().eq('post_id', id);
  await supabase.from('forum_replies').delete().eq('post_id', id);
  const { error } = await supabase.from('forum_posts').delete().eq('id', id);

  if (error) throw error;
  return Response.json({ success: true }, { headers: corsHeaders });
}
