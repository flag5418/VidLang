// @ts-nocheck
// deno-lint-ignore-file no-explicit-any
/**
 * Evaluation Storage Edge Function
 * 统一处理评测结果的存储、查询、淘汰和摘要更新
 *
 * 接口：
 * - POST /save    保存评测结果（自动淘汰旧记录，更新摘要）
 * - POST /history 获取历史记录
 * - POST /summary 获取用户评测摘要
 */

import { corsHeaders } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const MAX_RECORDS_PER_TYPE = 50

// ─── 鉴权 ───────────────────────────────────────────

async function getUserId(req: Request): Promise<string | null> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return null
  const token = authHeader.replace('Bearer ', '')
  try {
    const supabase = createClient(supabaseUrl, supabaseServiceKey)
    const { data, error } = await supabase.auth.getUser(token)
    if (error || !data.user) return null
    return data.user.id
  } catch {
    return null
  }
}

// ─── 主服务 ───────────────────────────────────────────

Deno.serve(async (req: Request) => {
  // CORS 预检
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return json({ ok: false, error: 'method_not_allowed' }, 405)
  }

  try {
    const body = (await req.json()) as any
    const { action } = body

    // 鉴权
    const userId = await getUserId(req)
    if (!userId) {
      return json({ ok: false, error: 'unauthorized' }, 401)
    }

    switch (action) {
      case 'save':
        return await handleSave(userId, body)
      case 'history':
        return await handleHistory(userId, body)
      case 'summary':
        return await handleSummary(userId, body)
      default:
        return json({ ok: false, error: 'unknown_action', message: `未知 action: ${action}` }, 400)
    }
  } catch (e: any) {
    console.error('evaluation-storage error:', e.message || e)
    return json({ ok: false, error: 'internal_error', message: e.message || String(e) }, 500)
  }
})

// ─── Action: save ─────────────────────────────────────

async function handleSave(userId: string, body: any): Promise<Response> {
  const {
    evaluation_type: evaluationType,
    resource_type: resourceType,
    resource_code: resourceCode,
    resource_title: resourceTitle,
    ref_text: refText,
    overall_score: overallScore,
    fluency_score: fluencyScore,
    integrity_score: integrityScore,
    accuracy_score: accuracyScore,
    pronunciation_score: pronunciationScore,
    raw_result: rawResult,
    word_summary: wordSummary,
    weak_dimensions: weakDimensions,
    duration_ms: durationMs,
    language,
  } = body

  // 参数校验
  if (!evaluationType || !['word', 'sentence', 'paragraph'].includes(evaluationType)) {
    return json({ ok: false, error: 'invalid_evaluation_type' }, 400)
  }

  const supabase = createClient(supabaseUrl, supabaseServiceKey)

  // 1. 插入新记录
  const { data: record, error: insertError } = await supabase
    .from('evaluation_records')
    .insert({
      user_id: userId,
      evaluation_type: evaluationType,
      resource_type: resourceType,
      resource_code: resourceCode,
      resource_title: resourceTitle,
      ref_text: refText,
      overall_score: overallScore,
      fluency_score: fluencyScore,
      integrity_score: integrityScore,
      accuracy_score: accuracyScore,
      pronunciation_score: pronunciationScore,
      raw_result: rawResult || {},
      word_summary: wordSummary || [],
      weak_dimensions: weakDimensions || [],
      duration_ms: durationMs,
      language: language || 'en',
    })
    .select()
    .single()

  if (insertError) {
    console.error('Insert error:', insertError)
    return json({ ok: false, error: 'insert_failed', message: insertError.message }, 500)
  }

  // 2. 淘汰旧记录（保留最近 50 条）
  await pruneOldRecords(supabase, userId, evaluationType)

  // 3. 更新摘要
  const summary = await updateSummary(supabase, userId, evaluationType)

  return json({
    ok: true,
    record_id: record.id,
    summary: {
      total_count: summary.total_count,
      avg_overall: summary.avg_overall,
      recent_trend: summary.recent_trend,
    },
  })
}

// ─── Action: history ──────────────────────────────────

async function handleHistory(userId: string, body: any): Promise<Response> {
  const {
    evaluation_type: evaluationType,
    limit = 10,
    offset = 0,
  } = body

  const supabase = createClient(supabaseUrl, supabaseServiceKey)

  let query = supabase
    .from('evaluation_records')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
    .limit(limit)
    .range(offset, offset + limit - 1)

  if (evaluationType) {
    query = query.eq('evaluation_type', evaluationType)
  }

  const { data: records, error } = await query

  if (error) {
    return json({ ok: false, error: 'query_failed', message: error.message }, 500)
  }

  // 同时返回各类型摘要
  const { data: summaries } = await supabase
    .from('evaluation_summaries')
    .select('*')
    .eq('user_id', userId)

  return json({
    ok: true,
    records: records || [],
    summaries: summaries || [],
  })
}

// ─── Action: summary ──────────────────────────────────

async function handleSummary(userId: string, body: any): Promise<Response> {
  const { evaluation_type: evaluationType } = body

  const supabase = createClient(supabaseUrl, supabaseServiceKey)

  let query = supabase
    .from('evaluation_summaries')
    .select('*')
    .eq('user_id', userId)

  if (evaluationType) {
    query = query.eq('evaluation_type', evaluationType)
  }

  const { data: summaries, error } = await query

  if (error) {
    return json({ ok: false, error: 'query_failed', message: error.message }, 500)
  }

  return json({
    ok: true,
    summaries: summaries || [],
  })
}

// ─── 辅助函数 ───────────────────────────────────────────

async function pruneOldRecords(
  supabase: any,
  userId: string,
  evalType: string,
): Promise<void> {
  // 获取该用户该类型的所有记录 ID（按时间倒序）
  const { data: records } = await supabase
    .from('evaluation_records')
    .select('id')
    .eq('user_id', userId)
    .eq('evaluation_type', evalType)
    .order('created_at', { ascending: false })

  if (!records || records.length <= MAX_RECORDS_PER_TYPE) return

  // 删除超出限制的旧记录
  const idsToDelete = records
    .slice(MAX_RECORDS_PER_TYPE)
    .map((r: any) => r.id)

  const { error } = await supabase
    .from('evaluation_records')
    .delete()
    .in('id', idsToDelete)

  if (error) {
    console.error('Prune error:', error)
  }
}

async function updateSummary(
  supabase: any,
  userId: string,
  evalType: string,
): Promise<{ total_count: number; avg_overall: number; recent_trend: string }> {
  // 重新计算该类型的统计数据
  const { data: records } = await supabase
    .from('evaluation_records')
    .select('overall_score, fluency_score, integrity_score, accuracy_score, pronunciation_score, weak_dimensions, word_summary')
    .eq('user_id', userId)
    .eq('evaluation_type', evalType)
    .order('created_at', { ascending: false })
    .limit(50)

  if (!records || records.length === 0) {
    return { total_count: 0, avg_overall: 0, recent_trend: 'stable' }
  }

  const total = records.length

  // 计算平均分
  const avgOverall = safeAvg(records.map((r: any) => r.overall_score))
  const avgFluency = safeAvg(records.map((r: any) => r.fluency_score))
  const avgAccuracy = safeAvg(records.map((r: any) => r.accuracy_score))
  const avgIntegrity = safeAvg(records.map((r: any) => r.integrity_score))
  const avgPronunciation = safeAvg(records.map((r: any) => r.pronunciation_score))

  // 最近 10 次评分
  const recentScores = records
    .slice(0, 10)
    .map((r: any) => r.overall_score)
    .filter((s: any) => s != null)

  // 趋势判断
  let trend = 'stable'
  if (recentScores.length >= 2) {
    trend = (recentScores[0] > recentScores[1]) ? 'up' : 'down'
  }

  // 统计薄弱维度
  const dimScores: Record<string, number[]> = {}
  for (const r of records) {
    const dims = r.weak_dimensions || []
    for (const d of dims) {
      if (!dimScores[d.name]) dimScores[d.name] = []
      dimScores[d.name].push(d.score)
    }
  }
  const weakDimensions = Object.entries(dimScores)
    .map(([name, scores]) => ({
      name,
      avg_score: scores.reduce((a, b) => a + b, 0) / scores.length,
      count: scores.length,
    }))
    .sort((a, b) => a.avg_score - b.avg_score)
    .slice(0, 3)

  // 统计常错单词
  const wordErrors: Record<string, { count: number; scores: number[] }> = {}
  for (const r of records) {
    const words = r.word_summary || []
    for (const w of words) {
      if (w.score != null && w.score < 70) {
        if (!wordErrors[w.word]) wordErrors[w.word] = { count: 0, scores: [] }
        wordErrors[w.word].count++
        wordErrors[w.word].scores.push(w.score)
      }
    }
  }
  const frequentErrors = Object.entries(wordErrors)
    .map(([word, data]) => ({
      word,
      error_count: data.count,
      avg_score: data.scores.reduce((a, b) => a + b, 0) / data.scores.length,
    }))
    .sort((a, b) => b.error_count - a.error_count)
    .slice(0, 10)

  // 更新 summaries 表
  await supabase
    .from('evaluation_summaries')
    .upsert({
      user_id: userId,
      evaluation_type: evalType,
      total_count: total,
      avg_overall: avgOverall,
      avg_fluency: avgFluency,
      avg_accuracy: avgAccuracy,
      avg_integrity: avgIntegrity,
      avg_pronunciation: avgPronunciation,
      recent_scores: recentScores,
      weak_dimensions: weakDimensions,
      frequent_errors: frequentErrors,
      updated_at: new Date().toISOString(),
    }, { onConflict: 'user_id,evaluation_type' })

  return { total_count: total, avg_overall: avgOverall, recent_trend: trend }
}

function safeAvg(values: (number | null)[]): number {
  const valid = values.filter((v): v is number => v != null)
  if (valid.length === 0) return 0
  return parseFloat((valid.reduce((a, b) => a + b, 0) / valid.length).toFixed(2))
}

// ─── 工具函数 ───────────────────────────────────────────

function json(data: any, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}
