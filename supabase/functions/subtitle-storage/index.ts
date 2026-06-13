// @ts-nocheck
// deno-lint-ignore-file no-explicit-any
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const BUCKET = 'subtitles'

function json(data: any, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

function getSupabase(req: Request) {
  return createClient(supabaseUrl, supabaseServiceKey, {
    global: { headers: { Authorization: req.headers.get('Authorization')! } },
  })
}

function getAdminSupabase() {
  return createClient(supabaseUrl, supabaseServiceKey)
}

async function getUserId(req: Request): Promise<string | null> {
  const supabase = getSupabase(req)
  const { data, error } = await supabase.auth.getUser()
  if (error || !data.user) return null
  return data.user.id
}

function pathFor(userId: string, videoCode: string) {
  return `${userId}/${videoCode}.json`
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS')
    return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST')
    return json({ ok: false, error: 'method_not_allowed' }, 405)

  try {
    const userId = await getUserId(req)
    if (!userId) return json({ ok: false, error: 'unauthorized' }, 401)

    const body = (await req.json()) as any
    const op = body.op as string
    const videoCode = (body.video_code as string | undefined)?.trim() ?? ''
    if (!op || !videoCode) {
      return json(
        {
          ok: false,
          error: 'missing_required_fields',
          message: '需要 op 与 video_code',
        },
        400,
      )
    }

    const admin = getAdminSupabase()
    const objectPath = pathFor(userId, videoCode)

    if (op === 'upload') {
      const items = Array.isArray(body.items) ? body.items : null
      const title = (body.title as string | undefined)?.trim()
      if (!items || items.length === 0) {
        return json(
          { ok: false, error: 'empty_items', message: 'items 不能为空' },
          400,
        )
      }
      const payload = JSON.stringify({
        video_code: videoCode,
        title: title && title.length > 0 ? title : '',
        uploaded_at: new Date().toISOString(),
        items,
      })

      const { error } = await admin.storage
        .from(BUCKET)
        .upload(objectPath, new Blob([payload], { type: 'application/json' }), {
          upsert: true,
          contentType: 'application/json',
        })
      if (error) {
        return json(
          { ok: false, error: 'upload_failed', message: error.message },
          500,
        )
      }
      return json({ ok: true, path: objectPath, count: items.length })
    }

    if (op === 'exists') {
      const { data, error } = await admin.storage
        .from(BUCKET)
        .download(objectPath)
      if (error || !data) return json({ ok: true, exists: false })
      return json({ ok: true, exists: true })
    }

    if (op === 'delete') {
      const { error } = await admin.storage.from(BUCKET).remove([objectPath])
      if (error) {
        return json(
          { ok: false, error: 'delete_failed', message: error.message },
          500,
        )
      }
      return json({ ok: true, path: objectPath })
    }

    if (op === 'get') {
      const { data, error } = await admin.storage
        .from(BUCKET)
        .download(objectPath)
      if (error || !data) {
        return json(
          { ok: false, error: 'not_found', message: '字幕文件不存在' },
          404,
        )
      }
      const text = await data.text()
      const parsed = JSON.parse(text)
      return json({ ok: true, path: objectPath, data: parsed })
    }

    return json(
      { ok: false, error: 'unsupported_op', message: `不支持的 op: ${op}` },
      400,
    )
  } catch (e: any) {
    console.error('subtitle-storage error:', e.message || e)
    return json(
      { ok: false, error: 'internal_error', message: e.message || String(e) },
      500,
    )
  }
})
