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

    if (req.method === 'POST') {
      const body = await req.json();
      return await createReport(body, user);
    }

    return Response.json({ error: 'Method not allowed' }, { status: 405, headers: corsHeaders });
  } catch (error) {
    console.error('forum-reports error:', error);
    return Response.json({ error: 'Internal server error' }, { status: 500, headers: corsHeaders });
  }
});

async function createReport(body: any, user: any) {
  const { target_type, target_id, reason, detail } = body;

  if (!target_type || !target_id || !reason) {
    return Response.json({ error: 'Missing required fields: target_type, target_id, reason' }, { status: 400, headers: corsHeaders });
  }
  if (!['post', 'reply'].includes(target_type)) {
    return Response.json({ error: 'Invalid target_type' }, { status: 400, headers: corsHeaders });
  }
  if (!['spam', 'harassment', 'inappropriate', 'other'].includes(reason)) {
    return Response.json({ error: 'Invalid reason' }, { status: 400, headers: corsHeaders });
  }

  // 检查目标是否存在
  if (target_type === 'post') {
    const { data: post } = await supabase.from('forum_posts').select('id').eq('id', target_id).single();
    if (!post) return Response.json({ error: 'Post not found' }, { status: 404, headers: corsHeaders });
  } else {
    const { data: reply } = await supabase.from('forum_replies').select('id').eq('id', target_id).single();
    if (!reply) return Response.json({ error: 'Reply not found' }, { status: 404, headers: corsHeaders });
  }

  const { data, error } = await supabase
    .from('forum_reports')
    .upsert({
      reporter_id: user.id,
      target_type,
      target_id,
      reason,
      detail: detail || '',
      status: 'pending',
    }, { onConflict: 'reporter_id, target_type, target_id' })
    .select()
    .single();

  if (error) {
    if (error.message?.includes('duplicate')) {
      return Response.json({ error: 'Already reported' }, { status: 409, headers: corsHeaders });
    }
    throw error;
  }

  return Response.json({ data }, { status: 201, headers: corsHeaders });
}
