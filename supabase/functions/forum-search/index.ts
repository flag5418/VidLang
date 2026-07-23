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
    if (req.method !== 'GET') {
      return Response.json({ error: 'Method not allowed' }, { status: 405, headers: corsHeaders });
    }

    const url = new URL(req.url);
    const q = url.searchParams.get('q') || '';
    const tagId = url.searchParams.get('tag_id');
    const page = parseInt(url.searchParams.get('page') || '1');
    const limit = Math.min(parseInt(url.searchParams.get('limit') || '20'), 50);

    if (!q.trim()) {
      return Response.json({ error: 'Missing query parameter q' }, { status: 400, headers: corsHeaders });
    }

    const offset = (page - 1) * limit;

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

    // 全文搜索：标题 + 内容 ILIKE
    const pattern = `%${q}%`;
    query = query.or(`title.ilike.${pattern},content.ilike.${pattern}`)
      .order('is_pinned', { ascending: false })
      .order('updated_at', { ascending: false })
      .range(offset, offset + limit - 1);

    const { data, error, count } = await query;
    if (error) throw error;

    return Response.json({
      data,
      query: q,
      pagination: { page, limit, total: count || 0, totalPages: Math.ceil((count || 0) / limit) }
    }, { headers: corsHeaders });

  } catch (error) {
    console.error('forum-search error:', error);
    return Response.json({ error: 'Internal server error' }, { status: 500, headers: corsHeaders });
  }
});
