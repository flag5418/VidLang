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
    const path = url.pathname.replace('/forum-my', '').replace(/^\//, '');

    if (req.method !== 'GET') {
      return Response.json({ error: 'Method not allowed' }, { status: 405, headers: corsHeaders });
    }

    const page = parseInt(url.searchParams.get('page') || '1');
    const limit = Math.min(parseInt(url.searchParams.get('limit') || '20'), 50);
    const offset = (page - 1) * limit;

    if (path === 'posts' || path === '') {
      return await myPosts(user.id, offset, limit, page);
    }
    if (path === 'replies') {
      return await myReplies(user.id, offset, limit, page);
    }
    if (path === 'likes') {
      return await myLikes(user.id, offset, limit, page);
    }

    return Response.json({ error: 'Not found' }, { status: 404, headers: corsHeaders });
  } catch (error) {
    console.error('forum-my error:', error);
    return Response.json({ error: 'Internal server error' }, { status: 500, headers: corsHeaders });
  }
});

async function myPosts(userId: string, offset: number, limit: number, page: number) {
  const { data, error, count } = await supabase
    .from('forum_posts')
    .select(`
      *,
      tag:forum_tags(id, name, color)
    `, { count: 'exact' })
    .eq('author_id', userId)
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1);

  if (error) throw error;
  return Response.json({
    data,
    pagination: { page, limit, total: count || 0, totalPages: Math.ceil((count || 0) / limit) }
  }, { headers: corsHeaders });
}

async function myReplies(userId: string, offset: number, limit: number, page: number) {
  const { data, error, count } = await supabase
    .from('forum_replies')
    .select(`
      *,
      post:forum_posts(id, title, tag_id)
    `, { count: 'exact' })
    .eq('author_id', userId)
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1);

  if (error) throw error;
  return Response.json({
    data,
    pagination: { page, limit, total: count || 0, totalPages: Math.ceil((count || 0) / limit) }
  }, { headers: corsHeaders });
}

async function myLikes(userId: string, offset: number, limit: number, page: number) {
  const { data, error, count } = await supabase
    .from('forum_likes')
    .select(`
      *,
      post:forum_posts!inner(id, title, content, tag_id, author_id, created_at)
    `, { count: 'exact' })
    .eq('user_id', userId)
    .eq('target_type', 'post')
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1);

  if (error) throw error;
  return Response.json({
    data,
    pagination: { page, limit, total: count || 0, totalPages: Math.ceil((count || 0) / limit) }
  }, { headers: corsHeaders });
}
