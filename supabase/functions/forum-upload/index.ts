import { serve } from "https://deno.land/std@0.224.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { corsHeaders } from '../_shared/cors.ts'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE);

const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif'];
const MAX_SIZE = 5 * 1024 * 1024; // 5MB
const BUCKET = 'forum-images';

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

    // 封禁检查
    const { data: ban } = await supabase.from('user_bans').select('id').eq('user_id', user.id).eq('is_active', true).maybeSingle();
    if (ban) {
      return Response.json({ error: 'Account banned' }, { status: 403, headers: corsHeaders });
    }

    if (req.method !== 'POST') {
      return Response.json({ error: 'Method not allowed' }, { status: 405, headers: corsHeaders });
    }

    const formData = await req.formData();
    const file = formData.get('file') as File;

    if (!file) {
      return Response.json({ error: 'No file provided' }, { status: 400, headers: corsHeaders });
    }

    // 校验文件类型
    if (!ALLOWED_TYPES.includes(file.type)) {
      return Response.json({ error: 'Invalid file type, only jpg/png/webp allowed' }, { status: 400, headers: corsHeaders });
    }

    // 校验文件大小
    if (file.size > MAX_SIZE) {
      return Response.json({ error: 'File too large, max 5MB' }, { status: 400, headers: corsHeaders });
    }

    // 生成唯一文件名
    const ext = file.type.split('/')[1];
    const uuid = crypto.randomUUID();
    const filePath = `${user.id}/${uuid}.${ext}`;

    // 上传到 Storage
    const arrayBuffer = await file.arrayBuffer();
    const { error: uploadError } = await supabase.storage
      .from(BUCKET)
      .upload(filePath, arrayBuffer, {
        contentType: file.type,
        upsert: false,
      });

    if (uploadError) throw uploadError;

    // 获取公开 URL
    const { data: { publicUrl } } = supabase.storage.from(BUCKET).getPublicUrl(filePath);

    return Response.json({
      url: publicUrl,
      path: filePath,
      type: file.type,
      size: file.size,
    }, { headers: corsHeaders });

  } catch (error) {
    console.error('forum-upload error:', error);
    return Response.json({ error: 'Internal server error' }, { status: 500, headers: corsHeaders });
  }
});
