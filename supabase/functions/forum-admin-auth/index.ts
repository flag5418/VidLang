import { serve } from "https://deno.land/std@0.224.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { corsHeaders } from '../_shared/cors.ts'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE);

// 验证管理员权限
export async function verifyAdmin(token: string): Promise<{ user: any; role: string } | null> {
  const { data: { user }, error } = await supabase.auth.getUser(token);
  if (error || !user) return null;

  const { data: roleData } = await supabase
    .from('user_roles')
    .select('role')
    .eq('user_id', user.id)
    .single();

  if (!roleData || !['admin', 'moderator'].includes(roleData.role)) {
    return null;
  }

  return { user, role: roleData.role };
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const url = new URL(req.url);
    const path = url.pathname.replace('/forum-admin-auth', '').replace(/^\//, '');

    if (req.method === 'POST' && path === 'login') {
      return await handleLogin(req);
    }

    if (req.method === 'GET' && path === 'session') {
      return await handleSession(req);
    }

    if (req.method === 'POST' && path === 'logout') {
      return Response.json({ success: true }, { headers: corsHeaders });
    }

    return Response.json({ error: 'Not found' }, { status: 404, headers: corsHeaders });
  } catch (error) {
    console.error('forum-admin-auth error:', error);
    return Response.json({ error: 'Internal server error' }, { status: 500, headers: corsHeaders });
  }
});

// 登录验证
async function handleLogin(req: Request) {
  const body = await req.json();
  const { email, password } = body;

  if (!email || !password) {
    return Response.json({ error: 'Missing email or password' }, { status: 400, headers: corsHeaders });
  }

  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  if (error || !data.user) {
    return Response.json({ error: 'Invalid credentials' }, { status: 401, headers: corsHeaders });
  }

  // 检查管理员权限
  const { data: roleData } = await supabase
    .from('user_roles')
    .select('role')
    .eq('user_id', data.user.id)
    .single();

  if (!roleData || !['admin', 'moderator'].includes(roleData.role)) {
    return Response.json({ error: 'No admin permission' }, { status: 403, headers: corsHeaders });
  }

  return Response.json({
    token: data.session?.access_token,
    user: {
      id: data.user.id,
      email: data.user.email,
      role: roleData.role,
    },
  }, { headers: corsHeaders });
}

// 验证 Session
async function handleSession(req: Request) {
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return Response.json({ error: 'Unauthorized' }, { status: 401, headers: corsHeaders });
  }

  const result = await verifyAdmin(authHeader.replace('Bearer ', ''));
  if (!result) {
    return Response.json({ error: 'Unauthorized' }, { status: 401, headers: corsHeaders });
  }

  return Response.json({
    user: { id: result.user.id, email: result.user.email, role: result.role },
  }, { headers: corsHeaders });
}
