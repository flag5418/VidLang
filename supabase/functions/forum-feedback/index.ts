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
    const path = url.pathname.replace('/forum-feedback', '').replace(/^\//, '');

    if (req.method === 'POST') {
      return await createFeedback(req, user);
    }
    if (req.method === 'GET' && (path === 'my' || !path)) {
      return await getMyFeedback(user.id, url);
    }

    return Response.json({ error: 'Not found' }, { status: 404, headers: corsHeaders });
  } catch (error) {
    console.error('forum-feedback error:', error);
    return Response.json({ error: 'Internal server error' }, { status: 500, headers: corsHeaders });
  }
});

async function createFeedback(req: Request, user: any) {
  const body = await req.json();
  const { type, title, content, image_urls } = body;

  if (!type || !title || !content) {
    return Response.json({ error: 'Missing required fields: type, title, content' }, { status: 400, headers: corsHeaders });
  }
  if (!['bug', 'feature', 'other'].includes(type)) {
    return Response.json({ error: 'Invalid type' }, { status: 400, headers: corsHeaders });
  }

  const { data, error } = await supabase
    .from('forum_feedback')
    .insert({
      user_id: user.id,
      type,
      title,
      content,
      image_urls: image_urls || [],
    })
    .select()
    .single();

  if (error) throw error;
  return Response.json({ data }, { status: 201, headers: corsHeaders });
}

async function getMyFeedback(userId: string, url: URL) {
  const page = parseInt(url.searchParams.get('page') || '1');
  const limit = Math.min(parseInt(url.searchParams.get('limit') || '20'), 50);
  const offset = (page - 1) * limit;

  const { data, error, count } = await supabase
    .from('forum_feedback')
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
