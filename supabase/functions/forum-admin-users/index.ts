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
    const path = url.pathname.replace('/forum-admin-users', '').replace(/^\//, '');
    const method = req.method;

    if (method === 'GET') return await handleGet(url);
    if (method === 'PUT') return await handlePut(req, admin, path);
    if (method === 'POST') return await handlePost(admin, path);

    return Response.json({ error: 'Method not allowed' }, { status: 405, headers: corsHeaders });
  } catch (error) {
    console.error('forum-admin-users error:', error);
    return Response.json({ error: 'Internal server error' }, { status: 500, headers: corsHeaders });
  }
});

// GET 用户列表
async function handleGet(url: URL) {
  const page = parseInt(url.searchParams.get('page') || '1');
  const limit = Math.min(parseInt(url.searchParams.get('limit') || '20'), 50);
  const keyword = url.searchParams.get('keyword');
  const offset = (page - 1) * limit;

  // 通过 admin API 查询用户
  const { data: { users }, error } = await supabase.auth.admin.listUsers({
    page,
    perPage: limit,
  });

  if (error) throw error;

  // 获取每个用户的角色信息
  const userIds = users.map((u: any) => u.id);
  const { data: roles } = await supabase
    .from('user_roles')
    .select('user_id, role')
    .in('user_id', userIds);

  const roleMap: Record<string, string> = {};
  if (roles) {
    for (const r of roles) {
      roleMap[r.user_id] = r.role;
    }
  }

  // 获取每个用户的封禁状态
  const { data: bans } = await supabase
    .from('user_bans')
    .select('user_id, reason, banned_at, expires_at')
    .in('user_id', userIds)
    .eq('is_active', true);

  const banMap: Record<string, any> = {};
  if (bans) {
    for (const b of bans) {
      banMap[b.user_id] = b;
    }
  }

  const enriched = users.map((u: any) => ({
    id: u.id,
    email: u.email,
    created_at: u.created_at,
    role: roleMap[u.id] || 'user',
    ban: banMap[u.id] || null,
  }));

  return Response.json({ data: enriched }, { headers: corsHeaders });
}

// POST 添加管理员
async function handlePost(admin: any, path: string) {
  if (path === 'add-admin') {
    const body = await (await new Response(null)).json().catch(() => null);
    // 从 req body 读取
    return Response.json({ error: 'Not implemented' }, { status: 501, headers: corsHeaders });
  }
  return Response.json({ error: 'Not found' }, { status: 404, headers: corsHeaders });
}

// PUT 封禁/解封/角色变更
async function handlePut(req: Request, admin: any, path: string) {
  const segments = path.split('/');
  const userId = segments[0];
  const action = segments[1];

  if (!userId) return Response.json({ error: 'Invalid user id' }, { status: 400, headers: corsHeaders });

  // 封禁用户
  if (action === 'ban') {
    if (admin.role !== 'admin') {
      return Response.json({ error: 'Only admin can ban users' }, { status: 403, headers: corsHeaders });
    }

    // 不允许封禁自己
    if (userId === admin.user.id) {
      return Response.json({ error: 'Cannot ban yourself' }, { status: 400, headers: corsHeaders });
    }

    const body = await req.json();
    const { reason, duration_days } = body; // duration_days: 0 = 永久

    const expiresAt = duration_days > 0
      ? new Date(Date.now() + duration_days * 86400000).toISOString()
      : null;

    // 先将旧的活跃封禁标记为非活跃
    await supabase.from('user_bans').update({ is_active: false }).eq('user_id', userId).eq('is_active', true);

    const { data, error } = await supabase.from('user_bans').insert({
      user_id: userId,
      reason: reason || 'Violation of community rules',
      banned_by: admin.user.id,
      expires_at: expiresAt,
    }).select().single();

    if (error) throw error;

    // 通知用户
    await supabase.from('forum_notifications').insert({
      user_id: userId,
      type: 'system',
      title: '你的账号已被封禁',
      body: `原因：${reason || '违反社区规定'}，${expiresAt ? `将于 ${expiresAt} 解封` : '永久封禁'}`,
      metadata: { ban_id: data.id },
    });

    return Response.json({ data }, { status: 201, headers: corsHeaders });
  }

  // 解封用户
  if (action === 'unban') {
    const { error } = await supabase
      .from('user_bans')
      .update({ is_active: false })
      .eq('user_id', userId)
      .eq('is_active', true);

    if (error) throw error;

    await supabase.from('forum_notifications').insert({
      user_id: userId,
      type: 'system',
      title: '你的账号已解封',
      body: '你的账号已被管理员解封，可以正常使用论坛功能',
      metadata: {},
    });

    return Response.json({ success: true }, { headers: corsHeaders });
  }

  // 角色变更
  if (action === 'role') {
    if (admin.role !== 'admin') {
      return Response.json({ error: 'Only admin can change roles' }, { status: 403, headers: corsHeaders });
    }

    const body = await req.json();
    const { role } = body;

    if (!['user', 'moderator', 'admin'].includes(role)) {
      return Response.json({ error: 'Invalid role' }, { status: 400, headers: corsHeaders });
    }

    const { data: existing } = await supabase
      .from('user_roles')
      .select('id')
      .eq('user_id', userId)
      .maybeSingle();

    if (existing) {
      const { error } = await supabase
        .from('user_roles')
        .update({ role })
        .eq('user_id', userId);

      if (error) throw error;
    } else {
      const { error } = await supabase
        .from('user_roles')
        .insert({ user_id: userId, role });

      if (error) throw error;
    }

    return Response.json({ success: true, role }, { headers: corsHeaders });
  }

  return Response.json({ error: 'Invalid action' }, { status: 400, headers: corsHeaders });
}
