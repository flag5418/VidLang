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

    if (req.method !== 'GET') {
      return Response.json({ error: 'Method not allowed' }, { status: 405, headers: corsHeaders });
    }

    // 查询活跃封禁
    const { data, error } = await supabase
      .from('user_bans')
      .select('reason, banned_at, expires_at')
      .eq('user_id', user.id)
      .eq('is_active', true)
      .order('banned_at', { ascending: false })
      .limit(1);

    if (error) throw error;

    const ban = data?.[0];
    if (!ban) {
      return Response.json({ is_banned: false }, { headers: corsHeaders });
    }

    // 检查是否过期
    if (ban.expires_at && new Date(ban.expires_at) < new Date()) {
      // 过期封禁，标记为非活跃
      await supabase.from('user_bans').update({ is_active: false }).eq('user_id', user.id).eq('expires_at', ban.expires_at);
      return Response.json({ is_banned: false }, { headers: corsHeaders });
    }

    return Response.json({
      is_banned: true,
      reason: ban.reason,
      banned_at: ban.banned_at,
      expires_at: ban.expires_at,
      is_permanent: !ban.expires_at,
    }, { headers: corsHeaders });

  } catch (error) {
    console.error('forum-ban-check error:', error);
    return Response.json({ error: 'Internal server error' }, { status: 500, headers: corsHeaders });
  }
});
