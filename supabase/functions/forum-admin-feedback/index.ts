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
    const path = url.pathname.replace('/forum-admin-feedback', '').replace(/^\//, '');
    const method = req.method;

    if (method === 'GET') return await handleGet(url);
    if (method === 'PUT') return await handlePut(req, admin, path);

    return Response.json({ error: 'Method not allowed' }, { status: 405, headers: corsHeaders });
  } catch (error) {
    console.error('forum-admin-feedback error:', error);
    return Response.json({ error: 'Internal server error' }, { status: 500, headers: corsHeaders });
  }
});

// GET 反馈列表
async function handleGet(url: URL) {
  const page = parseInt(url.searchParams.get('page') || '1');
  const limit = Math.min(parseInt(url.searchParams.get('limit') || '20'), 50);
  const type = url.searchParams.get('type');
  const status = url.searchParams.get('status');
  const offset = (page - 1) * limit;

  let query = supabase
    .from('forum_feedback')
    .select(`
      *,
      user:user_profiles!forum_feedback_user_id_fkey(id, raw_user_meta_data)
    `, { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1);

  if (type && type !== 'all') query = query.eq('type', type);
  if (status && status !== 'all') query = query.eq('status', status);

  const { data, error, count } = await query;
  if (error) throw error;

  return Response.json({
    data,
    pagination: { page, limit, total: count || 0, totalPages: Math.ceil((count || 0) / limit) }
  }, { headers: corsHeaders });
}

// PUT 处理反馈
async function handlePut(req: Request, admin: any, path: string) {
  const id = parseInt(path);
  if (!id) return Response.json({ error: 'Invalid id' }, { status: 400, headers: corsHeaders });

  const body = await req.json();
  const { status, admin_reply } = body;

  if (!status || !['pending', 'processing', 'resolved', 'declined'].includes(status)) {
    return Response.json({ error: 'Invalid status' }, { status: 400, headers: corsHeaders });
  }

  const updateData: any = { status };
  if (admin_reply) updateData.admin_reply = admin_reply;
  if (status === 'resolved' || status === 'declined') {
    updateData.handled_by = admin.user.id;
    updateData.handled_at = new Date().toISOString();
  }

  const { data, error } = await supabase
    .from('forum_feedback')
    .update(updateData)
    .eq('id', id)
    .select()
    .single();

  if (error) throw error;

  // 通知用户
  await supabase.from('forum_notifications').insert({
    user_id: data.user_id,
    type: 'system',
    title: '你的反馈有更新',
    body: `反馈「${data.title}」状态更新为：${status}${admin_reply ? '，回复：' + admin_reply : ''}`,
    metadata: { feedback_id: data.id },
  });

  return Response.json({ data }, { headers: corsHeaders });
}
