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
    const path = url.pathname.replace('/forum-admin-boards', '').replace(/^\//, '');
    const method = req.method;

    if (method === 'GET') return await handleGet();
    if (method === 'POST') return await handlePost(req, admin);
    if (method === 'PUT') return await handlePut(req, admin, path);
    if (method === 'DELETE') return await handleDelete(admin, path);

    return Response.json({ error: 'Method not allowed' }, { status: 405, headers: corsHeaders });
  } catch (error) {
    console.error('forum-admin-boards error:', error);
    return Response.json({ error: 'Internal server error' }, { status: 500, headers: corsHeaders });
  }
});

// GET 板块列表
async function handleGet() {
  const { data, error } = await supabase
    .from('forum_boards')
    .select('*')
    .order('sort_order');

  if (error) throw error;
  return Response.json({ data }, { headers: corsHeaders });
}

// POST 创建板块
async function handlePost(req: Request, admin: any) {
  if (admin.role !== 'admin') {
    return Response.json({ error: 'Only admin can create boards' }, { status: 403, headers: corsHeaders });
  }

  const body = await req.json();
  const { name, slug, description, sort_order, icon, is_active } = body;

  if (!name || !slug) {
    return Response.json({ error: 'Missing required fields: name, slug' }, { status: 400, headers: corsHeaders });
  }

  const { data, error } = await supabase
    .from('forum_boards')
    .insert({
      name, slug,
      description: description || '',
      sort_order: sort_order || 0,
      icon: icon || '',
      is_active: is_active !== undefined ? is_active : true,
    })
    .select()
    .single();

  if (error) throw error;
  return Response.json({ data }, { status: 201, headers: corsHeaders });
}

// PUT 编辑板块
async function handlePut(req: Request, admin: any, path: string) {
  const id = parseInt(path);
  if (!id) return Response.json({ error: 'Invalid id' }, { status: 400, headers: corsHeaders });

  const body = await req.json();
  const { name, slug, description, sort_order, icon, is_active } = body;

  const updateData: any = {};
  if (name !== undefined) updateData.name = name;
  if (slug !== undefined) updateData.slug = slug;
  if (description !== undefined) updateData.description = description;
  if (sort_order !== undefined) updateData.sort_order = sort_order;
  if (icon !== undefined) updateData.icon = icon;
  if (is_active !== undefined) updateData.is_active = is_active;

  const { data, error } = await supabase
    .from('forum_boards')
    .update(updateData)
    .eq('id', id)
    .select()
    .single();

  if (error) throw error;
  return Response.json({ data }, { headers: corsHeaders });
}

// DELETE 删除板块
async function handleDelete(admin: any, path: string) {
  if (admin.role !== 'admin') {
    return Response.json({ error: 'Only admin can delete boards' }, { status: 403, headers: corsHeaders });
  }

  const id = parseInt(path);
  if (!id) return Response.json({ error: 'Invalid id' }, { status: 400, headers: corsHeaders });

  // 检查板块是否有帖子
  const { count } = await supabase
    .from('forum_posts')
    .select('id', { count: 'exact', head: true })
    .eq('board_id', id);

  if (count && count > 0) {
    return Response.json({ error: `Board has ${count} posts, cannot delete` }, { status: 400, headers: corsHeaders });
  }

  const { error } = await supabase.from('forum_boards').delete().eq('id', id);
  if (error) throw error;

  return Response.json({ success: true }, { headers: corsHeaders });
}
