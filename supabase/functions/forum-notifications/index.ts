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
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return Response.json({ error: 'Unauthorized' }, { status: 401, headers: corsHeaders });
    }
    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) {
      return Response.json({ error: 'Invalid token' }, { status: 401, headers: corsHeaders });
    }

    const url = new URL(req.url);
    const path = url.pathname.replace('/forum-notifications', '').replace(/^\//, '');
    const method = req.method;

    if (method === 'GET') {
      if (path === 'unread-count') {
        return await getUnreadCount(user.id);
      }
      return await getList(user.id, url);
    }
    if (method === 'PUT') {
      if (path === 'read-all') {
        return await markAllRead(user.id);
      }
      if (path.endsWith('/read')) {
        const id = path.replace('/read', '');
        return await markRead(user.id, parseInt(id));
      }
    }

    return Response.json({ error: 'Not found' }, { status: 404, headers: corsHeaders });
  } catch (error) {
    console.error('forum-notifications error:', error);
    return Response.json({ error: 'Internal server error' }, { status: 500, headers: corsHeaders });
  }
});

async function getList(userId: string, url: URL) {
  const page = parseInt(url.searchParams.get('page') || '1');
  const limit = Math.min(parseInt(url.searchParams.get('limit') || '20'), 50);
  const offset = (page - 1) * limit;

  const { data, error, count } = await supabase
    .from('forum_notifications')
    .select('*', { count: 'exact' })
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1);

  if (error) throw error;

  return Response.json({
    data,
    pagination: { page, limit, total: count || 0, totalPages: Math.ceil((count || 0) / limit) }
  }, { headers: corsHeaders });
}

async function getUnreadCount(userId: string) {
  const { count, error } = await supabase
    .from('forum_notifications')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', userId)
    .eq('is_read', false);

  if (error) throw error;
  return Response.json({ unread_count: count || 0 }, { headers: corsHeaders });
}

async function markAllRead(userId: string) {
  const { error } = await supabase
    .from('forum_notifications')
    .update({ is_read: true })
    .eq('user_id', userId)
    .eq('is_read', false);

  if (error) throw error;
  return Response.json({ success: true }, { headers: corsHeaders });
}

async function markRead(userId: string, id: number) {
  if (!id) return Response.json({ error: 'Invalid id' }, { status: 400, headers: corsHeaders });

  const { error } = await supabase
    .from('forum_notifications')
    .update({ is_read: true })
    .eq('id', id)
    .eq('user_id', userId);

  if (error) throw error;
  return Response.json({ success: true }, { headers: corsHeaders });
}
