import { serve } from "https://deno.land/std@0.224.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { corsHeaders } from '../_shared/cors.ts'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE);

const BUCKET = 'forum-static';
const MIME_TYPES: Record<string, string> = {
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon',
  '.woff2': 'font/woff2',
  '.woff': 'font/woff',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const url = new URL(req.url);
    // 路径格式: /forum-static/<filepath>
    const filePath = url.pathname.replace('/forum-static', '').replace(/^\//, '');

    if (!filePath) {
      return new Response('Missing file path', { status: 400, headers: corsHeaders });
    }

    // 获取文件
    const { data, error } = await supabase.storage
      .from(BUCKET)
      .download(filePath);

    if (error || !data) {
      return new Response('File not found', { status: 404, headers: corsHeaders });
    }

    // 确定 MIME 类型
    const ext = '.' + (filePath.split('.').pop() || '');
    const contentType = MIME_TYPES[ext] || 'application/octet-stream';

    // 设置缓存头
    const headers = {
      ...corsHeaders,
      'Content-Type': contentType,
      'Cache-Control': 'public, max-age=86400',
    };

    return new Response(data, { headers });
  } catch (error) {
    console.error('forum-static error:', error);
    return new Response('Internal server error', { status: 500, headers: corsHeaders });
  }
});
