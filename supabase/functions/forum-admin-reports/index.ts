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
    const path = url.pathname.replace('/forum-admin-reports', '').replace(/^\//, '');
    const method = req.method;

    if (method === 'GET') return await handleGet(url, path);
    if (method === 'PUT') return await handlePut(req, admin, path);

    return Response.json({ error: 'Method not allowed' }, { status: 405, headers: corsHeaders });
  } catch (error) {
    console.error('forum-admin-reports error:', error);
    return Response.json({ error: 'Internal server error' }, { status: 500, headers: corsHeaders });
  }
});

// GET 举报列表
async function handleGet(url: URL, path: string) {
  const page = parseInt(url.searchParams.get('page') || '1');
  const limit = Math.min(parseInt(url.searchParams.get('limit') || '20'), 50);
  const status = url.searchParams.get('status') || 'pending';
  const offset = (page - 1) * limit;

  let query = supabase
    .from('forum_reports')
    .select(`
      *,
      reporter:user_profiles!forum_reports_reporter_id_fkey(id, raw_user_meta_data)
    `, { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1);

  if (status !== 'all') {
    query = query.eq('status', status);
  }

  const { data, error, count } = await query;
  if (error) throw error;

  return Response.json({
    data,
    pagination: { page, limit, total: count || 0, totalPages: Math.ceil((count || 0) / limit) }
  }, { headers: corsHeaders });
}

// PUT 处理举报
async function handlePut(req: Request, admin: any, path: string) {
  const segments = path.split('/');
  const id = parseInt(segments[0]);
  const action = segments[1];

  if (!id) return Response.json({ error: 'Invalid id' }, { status: 400, headers: corsHeaders });

  if (action === 'resolve') {
    const body = await req.json();
    const { resolution, delete_content } = body;

    const { data: report } = await supabase.from('forum_reports').select('*').eq('id', id).single();
    if (!report) return Response.json({ error: 'Report not found' }, { status: 404, headers: corsHeaders });

    // 更新举报状态
    const { error } = await supabase.from('forum_reports').update({
      status: 'resolved',
      handler_id: admin.user.id,
      handled_at: new Date().toISOString(),
      resolution: resolution || 'Handled',
    }).eq('id', id);

    if (error) throw error;

    // 如果需要删除被举报内容
    if (delete_content) {
      if (report.target_type === 'post') {
        await supabase.from('forum_posts').update({
          is_deleted: true,
          deleted_by: admin.user.id,
          deleted_at: new Date().toISOString(),
          deleted_reason: `Reported content - ${resolution || 'Admin decision'}`,
        }).eq('id', report.target_id);
      } else if (report.target_type === 'reply') {
        await supabase.from('forum_replies').update({
          is_deleted: true,
          deleted_by: admin.user.id,
          deleted_at: new Date().toISOString(),
          deleted_reason: `Reported content - ${resolution || 'Admin decision'}`,
        }).eq('id', report.target_id);
      }
    }

    // 通知举报人
    await supabase.from('forum_notifications').insert({
      user_id: report.reporter_id,
      type: 'system',
      title: '你的举报已被处理',
      body: `举报 #${id} 已处理：${resolution || '内容已处理'}`,
      metadata: { report_id: id },
    });

    return Response.json({ success: true }, { headers: corsHeaders });
  }

  if (action === 'dismiss') {
    const { error } = await supabase.from('forum_reports').update({
      status: 'dismissed',
      handler_id: admin.user.id,
      handled_at: new Date().toISOString(),
      resolution: 'Dismissed',
    }).eq('id', id);

    if (error) throw error;
    return Response.json({ success: true }, { headers: corsHeaders });
  }

  return Response.json({ error: 'Invalid action' }, { status: 400, headers: corsHeaders });
}
