// @ts-nocheck
// deno-lint-ignore-file no-explicit-any
/**
 * resource-status Edge Function
 * 
 * 管理资源（视频/音频/文章）的删除状态，用于：
 * 1. 客户端删除资源时标记状态（作为 subtitle-storage 物理删除的逻辑补充）
 * 2. ai-test-plan 综合测试出题前批量查询，过滤已删除资源
 * 
 * 核心问题：用户在本地删除文件夹中某个资源后，Supabase Storage 中的字幕文件可能因
 *         网络失败等原因未被物理删除，导致综合测试时仍会对已删资源出题。
 * 
 * 解决方案：独立的 status 标记表，与物理删除形成双重保障。
 * 
 * 接口协议：
 *   POST /functions/v1/resource-status
 *   
 *   { "op": "mark_deleted",  "video_codes": ["v001", "v002"] }  → 标记已删除
 *   { "op": "mark_active",   "video_codes": ["v001"] }          → 恢复有效（重新导入）
 *   { "op": "batch_check",   "video_codes": ["v001","v002"] }    → 批量查询状态
 */
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

function json(data: any, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

function getAdminSupabase() {
  return createClient(supabaseUrl, supabaseServiceKey)
}

async function getUserId(req: Request): Promise<string | null> {
  const supabase = createClient(supabaseUrl, supabaseServiceKey, {
    global: { headers: { Authorization: req.headers.get('Authorization')! } },
  })
  const { data, error } = await supabase.auth.getUser()
  if (error || !data.user) return null
  return data.user.id
}

/**
 * 确保 resource_status 表存在（幂等）
 * 
 * 首次调用时自动建表，后续调用直接使用。
 * 表结构：user_id + video_code 联合唯一，status 字段标记 active/deleted。
 */
async function ensureTable(admin: any): Promise<void> {
  const { error } = await admin.rpc('exec_sql', {
    sql: `
      CREATE TABLE IF NOT EXISTS resource_status (
        id BIGSERIAL PRIMARY KEY,
        user_id UUID NOT NULL,
        video_code TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'active',
        updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
        UNIQUE(user_id, video_code)
      );

      CREATE INDEX IF NOT EXISTS idx_resource_status_user_id 
        ON resource_status(user_id);

      CREATE INDEX IF NOT EXISTS idx_resource_status_status 
        ON resource_status(status) WHERE status = 'deleted';
    `,
  })
  // rpc 可能不可用，忽略错误（表应通过 migration 创建）
  if (error) {
    // 静默处理，假设表已通过 migration 存在
  }
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
    const videoCodes = Array.isArray(body.video_codes) ? body.video_codes : []

    if (!op) {
      return json(
        { ok: false, error: 'missing_op', message: '需要 op 参数' },
        400,
      )
    }

    const admin = getAdminSupabase()

    // ════════════════════════════════════
    //  mark_deleted — 批量标记资源为已删除
    // ════════════════════════════════════
    if (op === 'mark_deleted') {
      if (videoCodes.length === 0) {
        return json(
          { ok: false, error: 'missing_video_codes', message: '需要 video_codes 数组' },
          400,
        )
      }

      // 过滤空值并去重
      const codes = [...new Set(videoCodes.map((c: string) => String(c).trim()).filter(Boolean))]
      if (codes.length === 0) {
        return json({ ok: true, updated: 0, message: '无有效的 video_code' })
      }

      // 使用 upsert 批量更新/插入 deleted 状态
      const upsertRows = codes.map((code: string) => ({
        user_id: userId,
        video_code: code,
        status: 'deleted',
        updated_at: new Date().toISOString(),
      }))

      const { error: upsertError } = await admin
        .from('resource_status')
        .upsert(upsertRows, {
          onConflict: 'user_id,video_code',
          ignoreDuplicates: false,
        })

      if (upsertError) {
        console.error('[resource-status] mark_deleted error:', upsertError.message)
        return json(
          { ok: false, error: 'update_failed', message: upsertError.message },
          500,
        )
      }

      console.log(`[resource-status] mark_deleted: user=${userId} codes=${codes.join(',')}`)
      return json({
        ok: true,
        updated: codes.length,
        deleted_codes: codes,
        message: `成功标记 ${codes.length} 个资源为已删除`,
      })
    }

    // ════════════════════════════════════
    //  mark_active — 恢复资源为有效状态
    //  （重新导入同一资源时调用）
    // ════════════════════════════════════
    if (op === 'mark_active') {
      if (videoCodes.length === 0) {
        return json(
          { ok: false, error: 'missing_video_codes', message: '需要 video_codes 数组' },
          400,
        )
      }

      const codes = [...new Set(videoCodes.map((c: string) => String(c).trim()).filter(Boolean))]

      // 将指定 code 的状态恢复为 active
      const { error: updateError } = await admin
        .from('resource_status')
        .update({
          status: 'active',
          updated_at: new Date().toISOString(),
        })
        .eq('user_id', userId)
        .in('video_code', codes)

      // 如果没有匹配行（说明这些 code 从未标记过 deleted），不算错误
      if (updateError) {
        console.error('[resource-status] mark_active error:', updateError.message)
        return json(
          { ok: false, error: 'update_failed', message: updateError.message },
          500,
        )
      }

      console.log(`[resource-status] mark_active: user=${userId} codes=${codes.join(',')}`)
      return json({
        ok: true,
        restored_codes: codes,
        message: `成功恢复 ${codes.length} 个资源为有效状态`,
      })
    }

    // ════════════════════════════════════
    //  batch_check — 批量查询资源状态
    //  （ai-test-plan 综合测试出题前调用）
    // ════════════════════════════════════
    if (op === 'batch_check') {
      if (videoCodes.length === 0) {
        // 无需检查，返回全量 active
        return json({
          ok: true,
          deleted_codes: [],
          active_codes: [],
          total_checked: 0,
        })
      }

      const codes = [...new Set(videoCodes.map((c: string) => String(c).trim()).filter(Boolean))]

      // 查询这些 code 中哪些是 deleted 状态
      const { data: deletedRows, error: queryError } = await admin
        .from('resource_status')
        .select('video_code')
        .eq('user_id', userId)
        .eq('status', 'deleted')
        .in('video_code', codes)

      if (queryError) {
        console.error('[resource-status] batch_check error:', queryError.message)
        // 查询失败时不阻断出题，返回空 deleted 列表（保守策略：宁可多出题也不可阻断）
        return json({
          ok: true,
          deleted_codes: [],
          active_codes: codes,
          total_checked: codes.length,
          warning: '查询失败，默认所有资源均为有效状态',
        })
      }

      const deletedCodes = (deletedRows ?? []).map((r: any) => r.video_code as string)
      const activeCodes = codes.filter((c: string) => !deletedCodes.includes(c))

      if (deletedCodes.length > 0) {
        console.log(`[resource-status] batch_check: user=${userId} filtered=${deletedCodes.length}/${codes.length} deleted=[${deletedCodes.join(',')}]`)
      }

      return json({
        ok: true,
        deleted_codes: deletedCodes,
        active_codes: activeCodes,
        total_checked: codes.length,
      })
    }

    // ════════════════════════════════════
    //  不支持的操作
    // ════════════════════════════════════
    return json(
      {
        ok: false,
        error: 'unsupported_op',
        message: `不支持的 op: ${op}。支持: mark_deleted / mark_active / batch_check`,
      },
      400,
    )
  } catch (e: any) {
    console.error('[resource-status] unhandled error:', e.message || e)
    return json(
      {
        ok: false,
        error: 'internal_error',
        message: e.message || String(e),
      },
      500,
    )
  }
})
