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

/**
 * 构建存储路径
 *
 * v2.0: 支持 folder_code 组织存储
 * - 有 folder_code → ${userId}/${folderCode}/${videoCode}.json（按文件夹组织）
 * - 无 folder_code → ${userId}/${videoCode}.json（扁平结构，向后兼容）
 */
function pathFor(userId: string, videoCode: string, folderCode?: string) {
  if (folderCode && folderCode.trim().length > 0) {
    return `${userId}/${folderCode.trim()}/${videoCode}.json`
  }
  return `${userId}/${videoCode}.json`
}

/**
 * 构建文件夹前缀路径（用于 list 操作）
 */
function folderPrefix(userId: string, folderCode: string) {
  return `${userId}/${folderCode.trim()}/`
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
    // v2.0: 支持可选的 folder_code 参数
    const folderCode = (body.folder_code as string | undefined)?.trim()

    if (!op) {
      return json(
        { ok: false, error: 'missing_required_fields', message: '需要 op' },
        400,
      )
    }

    // list 操作不需要 video_code，只需要 folder_code
    if (op !== 'list' && !videoCode) {
      return json(
        { ok: false, error: 'missing_required_fields', message: '需要 op 与 video_code' },
        400,
      )
    }

    const admin = getAdminSupabase()
    const objectPath = pathFor(userId, videoCode, folderCode)

    // ════════════════════════════════════
    //  upload — 上传字幕
    // ════════════════════════════════════
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
        folder_code: folderCode ?? '',
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

    // ════════════════════════════════════
    //  list — 列出文件夹下所有字幕（v2.0 新增）
    //
    // 用于综合测试：获取某文件夹下所有资源的字幕文件列表，
    // 以便 ai-test-plan 批量拉取并合并出题
    // ════════════════════════════════════
    if (op === 'list') {
      if (!folderCode || folderCode.length === 0) {
        return json(
          { ok: false, error: 'missing_folder_code', message: 'list 操作需要 folder_code' },
          400,
        )
      }

      const prefix = folderPrefix(userId, folderCode)
      const { data: files, error: listError } = await admin.storage
        .from(BUCKET)
        .list(prefix.split('/').pop() ?? '', {
          limit: 200,
          sortBy: { column: 'name', order: 'asc' },
        })

      if (listError) {
        // 文件夹不存在或为空不算错误，返回空列表
        if (listError.message?.includes('Not Found') || listError.message?.includes('The resource was not found')) {
          return json({ ok: true, files: [], prefix, count: 0 })
        }
        return json(
          { ok: false, error: 'list_failed', message: listError.message },
          500,
        )
      }

      // 过滤只返回 .json 字幕文件，提取 video_code
      const subtitleFiles = (files ?? [])
        .filter((f: any) => f.name.endsWith('.json'))
        .map((f: any) => ({
          name: f.name,
          // 从 "xxx.json" 提取 video_code
          video_code: f.name.replace(/\.json$/, ''),
          size: f.size ?? 0,
          created_at: f.created_at ?? f.last_modified_at ?? '',
        }))

      return json({
        ok: true,
        files: subtitleFiles,
        prefix,
        count: subtitleFiles.length,
      })
    }

    // ════════════════════════════════════
    //  exists — 检查字幕是否存在
    // ════════════════════════════════════
    if (op === 'exists') {
      const { data, error } = await admin.storage
        .from(BUCKET)
        .download(objectPath)
      if (error || !data) return json({ ok: true, exists: false })
      return json({ ok: true, exists: true })
    }

    // ════════════════════════════════════
    //  get — 获取字幕内容
    // ════════════════════════════════════
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

    // ════════════════════════════════════
    //  delete — 删除字幕
    // ════════════════════════════════════
    if (op === 'delete') {
      // 如果有 folder_code 且没有指定具体 video_code，则删除整个文件夹下的所有字幕
      if (folderCode && folderCode.length > 0) {
        const prefix = folderPrefix(userId, folderCode)
        const folderName = prefix.split('/').pop() ?? ''
        const { data: files, error: listErr } = await admin.storage
          .from(BUCKET)
          .list(folderName, { limit: 500 })

        if (!listErr && files && files.length > 0) {
          const paths = files.map((f: any) => `${prefix}${f.name}`)
          await admin.storage.from(BUCKET).remove(paths)
        }
        return json({ ok: true, path: prefix, deleted: files?.length ?? 0 })
      }

      // 单个文件删除
      const { error } = await admin.storage.from(BUCKET).remove([objectPath])
      if (error) {
        return json(
          { ok: false, error: 'delete_failed', message: error.message },
          500,
        )
      }
      return json({ ok: true, path: objectPath })
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
