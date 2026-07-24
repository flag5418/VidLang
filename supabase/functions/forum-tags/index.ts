import { serve } from "https://deno.land/std@0.224.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { corsHeaders } from '../_shared/cors.ts'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE);

// V2.0 简化版：全部标签 + is_followed 状态
serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    if (req.method !== 'GET') {
      return Response.json({ error: 'Method not allowed' }, { status: 405, headers: corsHeaders });
    }

    // 可选鉴权（用于 is_followed）
    let userId: string | null = null;
    const authHeader = req.headers.get('Authorization');
    if (authHeader) {
      const token = authHeader.replace('Bearer ', '');
      const { data: { user } } = await supabase.auth.getUser(token);
      if (user) userId = user.id;
    }

    const { data: tags, error } = await supabase
      .from('forum_tags')
      .select('*')
      .eq('is_active', true)
      .order('sort_order')
      .order('id');

    if (error) throw error;

    let followedSet = new Set<number>();
    if (userId) {
      const { data: follows } = await supabase
        .from('forum_user_tag_follows')
        .select('tag_id')
        .eq('user_id', userId);
      followedSet = new Set((follows || []).map((f: any) => f.tag_id));
    }

    const data = (tags || []).map((t: any) => ({
      ...t,
      is_followed: followedSet.has(t.id),
    }));

    return Response.json({ data }, { headers: corsHeaders });
  } catch (error) {
    console.error('forum-tags error:', error);
    return Response.json({ error: 'Internal server error' }, { status: 500, headers: corsHeaders });
  }
});
